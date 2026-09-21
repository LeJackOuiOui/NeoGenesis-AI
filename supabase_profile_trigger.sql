-- Ejecutar en Supabase SQL Editor.
-- Crea el perfil aunque el proyecto exija confirmar el correo electrónico.

-- Alinea el esquema existente con los datos capturados por Crear Cuenta.
alter table public.profiles
  add column if not exists cargo text;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (
    id,
    nombre,
    email,
    telefono,
    cargo,
    role,
    estado
  )
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name', ''),
    lower(new.email),
    coalesce(new.raw_user_meta_data ->> 'phone', ''),
    coalesce(new.raw_user_meta_data ->> 'position', 'Empleado'),
    coalesce(new.raw_user_meta_data ->> 'role', 'Empleado'),
    'Activo'
  )
  on conflict (id) do update set
    nombre = excluded.nombre,
    email = excluded.email,
    telefono = excluded.telefono,
    cargo = excluded.cargo,
    role = excluded.role,
    estado = excluded.estado;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute procedure public.handle_new_user();

-- Recupera usuarios que ya existían antes de instalar el trigger.
insert into public.profiles (
  id,
  nombre,
  email,
  telefono,
  cargo,
  role,
  estado
)
select
  u.id,
  coalesce(u.raw_user_meta_data ->> 'full_name', ''),
  lower(u.email),
  coalesce(u.raw_user_meta_data ->> 'phone', ''),
  coalesce(u.raw_user_meta_data ->> 'position', 'Empleado'),
  coalesce(u.raw_user_meta_data ->> 'role', 'Empleado'),
  'Activo'
from auth.users u
where not exists (
  select 1 from public.profiles p where p.id = u.id
);

-- Permite al usuario autenticado consultar y actualizar únicamente su perfil.
alter table public.profiles enable row level security;

create or replace function public.is_user_manager()
returns boolean
language sql
stable
security definer set search_path = public
as $$
  select exists (
    select 1
    from public.profiles
    where id = auth.uid()
      and role in ('Administrador', 'Responsable RRHH')
  );
$$;

drop policy if exists "Users can view own profile" on public.profiles;
create policy "Users can view own profile"
on public.profiles for select
to authenticated
using (auth.uid() = id);

drop policy if exists "Users can insert own profile" on public.profiles;
create policy "Users can insert own profile"
on public.profiles for insert
to authenticated
with check (auth.uid() = id);

drop policy if exists "Admins can view all profiles" on public.profiles;
create policy "Admins can view all profiles"
on public.profiles for select
to authenticated
using (public.is_user_manager());

drop policy if exists "Users can update own profile" on public.profiles;
create policy "Users can update own profile"
on public.profiles for update
to authenticated
using (auth.uid() = id)
with check (auth.uid() = id);

-- Permite a administradores y responsables de RRHH gestionar usuarios y deja
-- constancia de cada edición o baja lógica en el log de auditoría.
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
      estado = p_estado
  where id = p_user_id
  returning * into updated_profile;

  if updated_profile.id is null then
    raise exception 'Usuario no encontrado';
  end if;

  insert into public.system_logs (event, description, metadata)
  values (
    case when p_estado = 'Inactivo' then 'user_deactivated' else 'user_updated' end,
    format('Usuario %s actualizado con rol %s y estado %s', updated_profile.email, updated_profile.role, updated_profile.estado),
    jsonb_build_object('user_id', updated_profile.id, 'role', updated_profile.role, 'status', updated_profile.estado)
  );

  return updated_profile;
end;
$$;

grant execute on function public.admin_update_user(uuid, text, text, text, text)
to authenticated;
