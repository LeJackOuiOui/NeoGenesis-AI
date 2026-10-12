alter table public.profiles
  add column if not exists company_nit text,
  add column if not exists company_rut text,
  add column if not exists company_address text,
  add column if not exists company_verification_status text;

update public.profiles as profile
set company_nit = coalesce(
      profile.company_nit,
      auth_user.raw_user_meta_data ->> 'company_nit'
    ),
    company_rut = coalesce(
      profile.company_rut,
      auth_user.raw_user_meta_data ->> 'company_rut'
    ),
    company_address = coalesce(
      profile.company_address,
      auth_user.raw_user_meta_data ->> 'company_address'
    ),
    company_verification_status = coalesce(
      profile.company_verification_status,
      'pending'
    )
from auth.users as auth_user
where auth_user.id = profile.id
  and lower(coalesce(auth_user.raw_user_meta_data ->> 'isRRHH', 'false')) = 'true';

update public.profiles as profile
set role = 'Empleado',
    company_verification_status = 'pending'
from auth.users as auth_user
where auth_user.id = profile.id
  and profile.company_verification_status = 'pending'
  and lower(coalesce(auth_user.raw_user_meta_data ->> 'isRRHH', 'false')) = 'true';

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  is_company boolean;
begin
  is_company :=
    lower(coalesce(new.raw_user_meta_data ->> 'isRRHH', 'false')) = 'true'
    or lower(coalesce(new.raw_user_meta_data ->> 'role', '')) = 'responsable rrhh';

  insert into public.profiles (
    id,
    nombre,
    email,
    telefono,
    cargo,
    role,
    estado,
    salario_base,
    tipo_contrato,
    fecha_ingreso,
    baja_logica,
    company_nit,
    company_rut,
    company_address,
    company_verification_status
  )
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name', ''),
    lower(new.email),
    coalesce(new.raw_user_meta_data ->> 'phone', ''),
    coalesce(new.raw_user_meta_data ->> 'position', 'Empleado'),
    'Empleado',
    'Activo',
    0,
    'Tiempo Completo',
    current_date,
    false,
    new.raw_user_meta_data ->> 'company_nit',
    new.raw_user_meta_data ->> 'company_rut',
    new.raw_user_meta_data ->> 'company_address',
    case when is_company then 'pending' else null end
  )
  on conflict (id) do update set
    nombre = excluded.nombre,
    email = excluded.email,
    telefono = excluded.telefono,
    cargo = excluded.cargo,
    role = excluded.role,
    estado = excluded.estado,
    salario_base = excluded.salario_base,
    tipo_contrato = excluded.tipo_contrato,
    fecha_ingreso = excluded.fecha_ingreso,
    baja_logica = excluded.baja_logica,
    company_nit = excluded.company_nit,
    company_rut = excluded.company_rut,
    company_address = excluded.company_address,
    company_verification_status = excluded.company_verification_status;

  return new;
end;
$$;

create or replace function public.prevent_unverified_company_role_changes()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  if auth.uid() = old.id and not public.is_user_manager() then
    if new.role is distinct from old.role then
      raise exception 'Solo un administrador puede cambiar el rol de una cuenta.';
    end if;

    if new.company_nit is distinct from old.company_nit
      or new.company_rut is distinct from old.company_rut
      or new.company_address is distinct from old.company_address
      or new.company_verification_status is distinct from old.company_verification_status
    then
      raise exception 'Solo un administrador puede cambiar los datos de verificación.';
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists prevent_unverified_company_role_changes on public.profiles;
create trigger prevent_unverified_company_role_changes
before update on public.profiles
for each row execute function public.prevent_unverified_company_role_changes();

create or replace function public.admin_update_user(
  p_user_id uuid,
  p_nombre text,
  p_cargo text,
  p_role text,
  p_estado text
)
returns public.profiles
language plpgsql
security definer set search_path = public
as $$
declare
  caller_role text;
  updated_profile public.profiles;
begin
  select role into caller_role
  from public.profiles
  where id = auth.uid();

  if caller_role not in ('Administrador', 'Responsable RRHH') then
    raise exception 'No tienes permisos para gestionar usuarios';
  end if;

  if p_estado not in ('Activo', 'En Vacaciones', 'Inactivo') then
    raise exception 'Estado de usuario no válido';
  end if;

  update public.profiles
  set nombre = trim(p_nombre),
      cargo = trim(p_cargo),
      role = p_role,
      estado = p_estado,
      company_verification_status = case
        when p_role = 'Responsable RRHH'
          and nullif(btrim(company_nit), '') is not null
          and nullif(btrim(company_rut), '') is not null
          and nullif(btrim(company_address), '') is not null then 'approved'
        when nullif(btrim(company_nit), '') is not null then 'pending'
        else null
      end
  where id = p_user_id
  returning * into updated_profile;

  if updated_profile.id is null then
    raise exception 'Usuario no encontrado';
  end if;

  insert into public.system_logs (event, description, metadata)
  values (
    case when p_estado = 'Inactivo' then 'user_deactivated' else 'user_updated' end,
    format('Usuario %s actualizado con rol %s y estado %s', updated_profile.email, updated_profile.role, updated_profile.estado),
    jsonb_build_object(
      'user_id', updated_profile.id,
      'role', updated_profile.role,
      'status', updated_profile.estado,
      'company_verification_status', updated_profile.company_verification_status
    )
  );

  return updated_profile;
end;
$$;

grant execute on function public.admin_update_user(uuid, text, text, text, text)
to authenticated;
