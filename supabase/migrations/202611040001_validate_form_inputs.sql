create or replace function public.is_valid_form_email(input_value text)
returns boolean
language plpgsql
immutable
as $$
declare
  local_part text;
  domain_part text;
  domain_label text;
begin
  if input_value is null
    or input_value <> btrim(input_value)
    or length(input_value) > 254
    or length(input_value) - length(replace(input_value, '@', '')) <> 1 then
    return false;
  end if;

  local_part := split_part(input_value, '@', 1);
  domain_part := split_part(input_value, '@', 2);
  if length(local_part) = 0
    or length(local_part) > 64
    or local_part ~ '(^\.|\.$|\.\.)'
    or local_part !~ '^[A-Za-z0-9.!#$%&''*+/=?^_`{|}~-]+$'
    or length(domain_part) > 253
    or position('.' in domain_part) = 0 then
    return false;
  end if;

  foreach domain_label in array string_to_array(domain_part, '.') loop
    if length(domain_label) = 0
      or domain_label !~ '^[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?$' then
      return false;
    end if;
  end loop;

  return true;
end;
$$;

create or replace function public.is_valid_form_phone(input_value text)
returns boolean
language plpgsql
immutable
as $$
declare
  digits text;
begin
  if input_value is null or input_value <> btrim(input_value) or input_value !~ '^[0-9+() -]+$' then
    return false;
  end if;
  if position('+' in input_value) > 1
    or length(input_value) - length(replace(input_value, '+', '')) > 1 then
    return false;
  end if;

  digits := regexp_replace(input_value, '[^0-9]', '', 'g');
  return length(digits) between 7 and 15;
end;
$$;

create or replace function public.is_valid_person_name(input_value text)
returns boolean
language sql
immutable
as $$
  select input_value is not null
    and input_value = btrim(input_value)
    and length(input_value) between 2 and 100
    and input_value ~ '^[A-Za-zÀ-ÖØ-öø-ÿ][A-Za-zÀ-ÖØ-öø-ÿ .''-]*$';
$$;

create or replace function public.validate_auth_signup_form()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  metadata jsonb := coalesce(new.raw_user_meta_data, '{}'::jsonb);
  company_registration boolean;
  field_value text;
begin
  if not public.is_valid_form_email(new.email) then
    raise exception using
      errcode = '22023',
      message = 'email: Ingresa un correo electrónico válido.';
  end if;

  company_registration :=
    lower(coalesce(metadata ->> 'isRRHH', 'false')) = 'true'
    or lower(coalesce(metadata ->> 'role', '')) = 'responsable rrhh';
  field_value := coalesce(metadata ->> 'full_name', '');
  if company_registration then
    if length(btrim(field_value)) not between 2 and 100 then
      raise exception using
        errcode = '22023',
        message = 'full_name: El nombre de la empresa debe tener entre 2 y 100 caracteres.';
    end if;
  elsif not public.is_valid_person_name(field_value) then
    raise exception using
      errcode = '22023',
      message = 'full_name: Ingresa un nombre válido de entre 2 y 100 caracteres.';
  end if;

  field_value := coalesce(metadata ->> 'phone', '');
  if not public.is_valid_form_phone(field_value) then
    raise exception using
      errcode = '22023',
      message = 'phone: Ingresa un teléfono válido de 7 a 15 dígitos.';
  end if;

  if company_registration then
    field_value := coalesce(metadata ->> 'company_nit', '');
    if field_value !~ '^[0-9]{9,10}$' then
      raise exception using
        errcode = '22023',
        message = 'company_nit: El NIT debe tener entre 9 y 10 dígitos.';
    end if;
    field_value := coalesce(metadata ->> 'company_rut', '');
    if length(btrim(field_value)) not between 3 and 30 then
      raise exception using
        errcode = '22023',
        message = 'company_rut: El número de registro del RUT debe tener entre 3 y 30 caracteres.';
    end if;
    field_value := coalesce(metadata ->> 'company_address', '');
    if length(btrim(field_value)) not between 5 and 200 then
      raise exception using
        errcode = '22023',
        message = 'company_address: La dirección debe tener entre 5 y 200 caracteres.';
    end if;
  end if;

  return new;
end;
$$;

create or replace function public.validate_form_row()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  new_values jsonb := to_jsonb(new);
  old_values jsonb;
  field_value text;
  skills_value jsonb;
begin
  if tg_op = 'UPDATE' then
    old_values := to_jsonb(old);
  end if;

  if tg_table_name = 'profiles' then
    if tg_op = 'INSERT' or new_values ->> 'nombre' is distinct from old_values ->> 'nombre' then
      field_value := coalesce(new_values ->> 'nombre', '');
      if coalesce(nullif(btrim(new_values ->> 'company_nit'), ''), '') = '' then
        if not public.is_valid_person_name(field_value) then
          raise exception using
            errcode = '22023',
            message = 'nombre: Ingresa un nombre válido de entre 2 y 100 caracteres.';
        end if;
      elsif length(btrim(field_value)) not between 2 and 100 then
        raise exception using
          errcode = '22023',
          message = 'nombre: El nombre de la empresa debe tener entre 2 y 100 caracteres.';
      end if;
    end if;

    if tg_op = 'INSERT' or new_values ->> 'email' is distinct from old_values ->> 'email' then
      if not public.is_valid_form_email(new_values ->> 'email') then
        raise exception using
          errcode = '22023',
          message = 'email: Ingresa un correo electrónico válido.';
      end if;
    end if;

    if new_values ? 'cargo'
      and (
        tg_op = 'INSERT'
        or new_values ->> 'cargo' is distinct from old_values ->> 'cargo'
      ) then
      field_value := coalesce(new_values ->> 'cargo', '');
      if length(btrim(field_value)) not between 1 and 100 then
        raise exception using
          errcode = '22023',
          message = 'cargo: El cargo es obligatorio y no puede superar 100 caracteres.';
      end if;
    end if;

    if tg_op = 'INSERT' or new_values ->> 'telefono' is distinct from old_values ->> 'telefono' then
      field_value := coalesce(new_values ->> 'telefono', '');
      if field_value <> '' and not public.is_valid_form_phone(field_value) then
        raise exception using
          errcode = '22023',
          message = 'telefono: Ingresa un teléfono válido de 7 a 15 dígitos.';
      end if;
    end if;

    if coalesce(nullif(btrim(new_values ->> 'company_nit'), ''), '') <> ''
      and new_values ->> 'company_nit' !~ '^[0-9]{9,10}$' then
      raise exception using
        errcode = '22023',
        message = 'company_nit: El NIT debe tener entre 9 y 10 dígitos.';
    end if;

    if coalesce(nullif(btrim(new_values ->> 'company_dv'), ''), '') <> ''
      and new_values ->> 'company_dv' !~ '^[0-9]$' then
      raise exception using
        errcode = '22023',
        message = 'company_dv: El dígito de verificación debe ser un número entre 0 y 9.';
    end if;

    if new_values ? 'company_rut'
      and coalesce(nullif(btrim(new_values ->> 'company_nit'), ''), '') <> ''
      and (
        tg_op = 'INSERT'
        or new_values ->> 'company_rut' is distinct from old_values ->> 'company_rut'
        or new_values ->> 'company_nit' is distinct from old_values ->> 'company_nit'
      )
      and length(btrim(coalesce(new_values ->> 'company_rut', ''))) not between 3 and 30 then
      raise exception using
        errcode = '22023',
        message = 'company_rut: El número de registro del RUT debe tener entre 3 y 30 caracteres.';
    end if;

    field_value := new_values ->> 'salario_base';
    if field_value is not null and
      (tg_op = 'INSERT' or field_value is distinct from old_values ->> 'salario_base') then
      if field_value !~ '^[0-9]+([.][0-9]+)?$' then
        raise exception using
          errcode = '22023',
          message = 'salario_base: El salario base debe ser un número no negativo.';
      end if;
      if field_value::numeric < 0 then
        raise exception using
          errcode = '22023',
          message = 'salario_base: El salario base debe ser un número no negativo.';
      end if;
    end if;

    field_value := coalesce(new_values ->> 'company_address', '');
    if coalesce(nullif(btrim(new_values ->> 'company_nit'), ''), '') <> ''
      and (
        tg_op = 'INSERT'
        or new_values ->> 'company_address' is distinct from old_values ->> 'company_address'
        or new_values ->> 'company_nit' is distinct from old_values ->> 'company_nit'
      )
      and length(btrim(field_value)) not between 5 and 200 then
      raise exception using
        errcode = '22023',
        message = 'company_address: La dirección debe tener entre 5 y 200 caracteres.';
    end if;

  elsif tg_table_name = 'candidatos' then
    if tg_op = 'INSERT' or new_values ->> 'full_name' is distinct from old_values ->> 'full_name' then
      if not public.is_valid_person_name(new_values ->> 'full_name') then
        raise exception using
          errcode = '22023',
          message = 'full_name: Ingresa un nombre válido de entre 2 y 100 caracteres.';
      end if;
    end if;

    if tg_op = 'INSERT' or new_values ->> 'email' is distinct from old_values ->> 'email' then
      field_value := coalesce(new_values ->> 'email', '');
      if field_value <> '' and not public.is_valid_form_email(field_value) then
        raise exception using
          errcode = '22023',
          message = 'email: Ingresa un correo electrónico válido.';
      end if;
    end if;

    if tg_op = 'INSERT' or new_values ->> 'phone' is distinct from old_values ->> 'phone' then
      field_value := coalesce(new_values ->> 'phone', '');
      if field_value <> '' and not public.is_valid_form_phone(field_value) then
        raise exception using
          errcode = '22023',
          message = 'phone: Ingresa un teléfono válido de 7 a 15 dígitos.';
      end if;
    end if;

    if new_values -> 'resume_data' is distinct from old_values -> 'resume_data'
      and new_values -> 'resume_data' is not null then
      skills_value := new_values -> 'resume_data' -> 'skills';
      if new_values -> 'resume_data' ? 'experience_years' then
        field_value := new_values -> 'resume_data' ->> 'experience_years';
        if field_value is null or field_value !~ '^[0-9]+([.][0-9]{1,2})?$' then
          raise exception using
            errcode = '22023',
            message = 'experience_years: La experiencia debe ser un número entre 0 y 100.';
        end if;
        if field_value::numeric > 100 then
          raise exception using
            errcode = '22023',
            message = 'experience_years: La experiencia debe ser un número entre 0 y 100.';
        end if;
      end if;
      if new_values -> 'resume_data' ? 'education_level' then
        field_value := new_values -> 'resume_data' ->> 'education_level';
        if field_value is null
          or field_value not in ('none', 'secondary', 'technical', 'bachelor', 'postgraduate', 'doctorate') then
          raise exception using
            errcode = '22023',
            message = 'education_level: Selecciona un nivel de educación válido.';
        end if;
      end if;
      if (
        new_values -> 'resume_data' ? 'experience_years'
        or new_values -> 'resume_data' ? 'education_level'
      ) and (skills_value is null or jsonb_typeof(skills_value) <> 'array') then
        raise exception using
          errcode = '22023',
          message = 'skills: Las habilidades deben enviarse como una lista.';
      end if;
      if jsonb_typeof(skills_value) = 'array' then
        if exists (
          select 1
          from jsonb_array_elements(skills_value) as skill(value)
          where jsonb_typeof(skill.value) <> 'string'
            or length(btrim(skill.value #>> '{}')) not between 1 and 100
        ) then
          raise exception using
            errcode = '22023',
            message = 'skills: Cada habilidad debe tener entre 1 y 100 caracteres.';
        end if;
      end if;
      if jsonb_typeof(skills_value) = 'array'
        and (
          new_values -> 'resume_data' ? 'experience_years'
          or new_values -> 'resume_data' ? 'education_level'
        )
        and jsonb_array_length(skills_value) = 0 then
        raise exception using
          errcode = '22023',
          message = 'skills: Ingresa al menos una habilidad válida.';
      end if;
      field_value := new_values -> 'resume_data' ->> 'additional_info';
      if length(field_value) > 2000 then
        raise exception using
          errcode = '22023',
          message = 'additional_info: La información adicional no puede superar 2000 caracteres.';
      end if;
    end if;

  elsif tg_table_name = 'vacantes' then
    field_value := coalesce(new_values ->> 'title', '');
    if length(btrim(field_value)) not between 1 and 100 then
      raise exception using
        errcode = '22023',
        message = 'title: El nombre de la vacante debe tener entre 1 y 100 caracteres.';
    end if;

    field_value := coalesce(new_values ->> 'min_experience_years', '');
    if field_value !~ '^[0-9]+([.][0-9]{1,2})?$' then
      raise exception using
        errcode = '22023',
        message = 'min_experience_years: La experiencia mínima debe ser un número entre 0 y 100.';
    end if;
    if field_value::numeric > 100 then
      raise exception using
        errcode = '22023',
        message = 'min_experience_years: La experiencia mínima debe ser un número entre 0 y 100.';
    end if;

    field_value := new_values ->> 'min_education_level';
    if field_value is null
      or field_value not in ('none', 'secondary', 'technical', 'bachelor', 'postgraduate', 'doctorate') then
      raise exception using
        errcode = '22023',
        message = 'min_education_level: Selecciona un nivel mínimo de formación válido.';
    end if;

    skills_value := new_values -> 'required_skills';
    if jsonb_typeof(skills_value) <> 'array' then
      raise exception using
        errcode = '22023',
        message = 'required_skills: Las habilidades deben enviarse como una lista.';
    end if;
    if exists (
      select 1
      from jsonb_array_elements_text(skills_value) as skill(value)
      where length(btrim(skill.value)) not between 1 and 100
    ) then
      raise exception using
        errcode = '22023',
        message = 'required_skills: Cada habilidad debe tener entre 1 y 100 caracteres.';
    end if;
    if length(coalesce((
        select string_agg(skill.value, ', ')
        from jsonb_array_elements_text(skills_value) as skill(value)
      ), '')) > 1000 then
      raise exception using
        errcode = '22023',
        message = 'required_skills: Las habilidades no pueden superar 1000 caracteres.';
    end if;

  elsif tg_table_name = 'recruiter_availability' then
    field_value := new_values ->> 'date';
    if field_value is null or field_value::date < current_date then
      raise exception using
        errcode = '22023',
        message = 'date: La fecha debe ser hoy o posterior.';
    end if;
    if field_value::date > current_date + 60 then
      raise exception using
        errcode = '22023',
        message = 'date: La fecha no puede superar los próximos 60 días.';
    end if;
    field_value := new_values ->> 'start_time';
    if field_value is null
      or field_value !~ '^([01][0-9]|2[0-3]):[0-5][0-9](:[0-5][0-9])?$' then
      raise exception using
        errcode = '22023',
        message = 'start_time: La hora de inicio no tiene un formato válido.';
    end if;
    field_value := new_values ->> 'end_time';
    if field_value is null
      or field_value !~ '^([01][0-9]|2[0-3]):[0-5][0-9](:[0-5][0-9])?$' then
      raise exception using
        errcode = '22023',
        message = 'end_time: La hora de fin no tiene un formato válido.';
    end if;
    if (new_values ->> 'start_time')::time >= (new_values ->> 'end_time')::time then
      raise exception using
        errcode = '22023',
        message = 'end_time: La hora de fin debe ser posterior a la de inicio.';
    end if;
  end if;

  return new;
end;
$$;

do $$
begin
  if to_regclass('auth.users') is not null then
    execute 'drop trigger if exists validate_auth_signup_form on auth.users';
    execute 'create trigger validate_auth_signup_form before insert on auth.users for each row execute function public.validate_auth_signup_form()';
  end if;
end;
$$;

do $$
declare
  table_name text;
begin
  foreach table_name in array array[
    'profiles',
    'candidatos',
    'vacantes',
    'recruiter_availability'
  ] loop
    if to_regclass(format('public.%I', table_name)) is not null then
      execute format(
        'drop trigger if exists validate_form_row on public.%I',
        table_name
      );
      execute format(
        'create trigger validate_form_row before insert or update on public.%I for each row execute function public.validate_form_row()',
        table_name
      );
    end if;
  end loop;
end;
$$;
