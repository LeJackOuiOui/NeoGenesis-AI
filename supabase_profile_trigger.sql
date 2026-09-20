-- Ejecutar en Supabase SQL Editor.
-- Crea el perfil aunque el proyecto exija confirmar el correo electrónico.

-- La aplicación usa estos nombres de forma consistente en profiles.
-- IF NOT EXISTS permite ejecutar este bloque aunque algunas columnas ya existan.
alter table public.profiles
  add column if not exists nombre text,
  add column if not exists email text,
  add column if not exists telefono text,
  add column if not exists cargo text,
  add column if not exists role text,
  add column if not exists estado text,
  add column if not exists avatar_url text,
  add column if not exists created_at timestamptz default now();

-- Migra los datos del esquema anterior y elimina columnas duplicadas.
do $migration$
begin
  if exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'profiles' and column_name = 'full_name') then
    execute $sql$update public.profiles set nombre = coalesce(nullif(nombre, ''), full_name) where full_name is not null$sql$;
  end if;
  if exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'profiles' and column_name = 'phone') then
    execute $sql$update public.profiles set telefono = coalesce(nullif(telefono, ''), phone) where phone is not null$sql$;
  end if;
  if exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'profiles' and column_name = 'position') then
    execute $sql$update public.profiles set cargo = coalesce(nullif(cargo, ''), position) where position is not null$sql$;
  end if;
  if exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'profiles' and column_name = 'status') then
    execute $sql$update public.profiles set estado = coalesce(nullif(estado, ''), status) where status is not null$sql$;
  end if;
end;
$migration$;

alter table public.profiles
  drop column if exists full_name,
  drop column if exists phone,
  drop column if exists position,
  drop column if exists status;

update public.profiles
set role = 'Empleado'
where role is null or trim(role) = '';

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
    select 1 from public.profiles
    where id = auth.uid()
      and role in ('Administrador', 'Responsable RRHH')
  );
$$;

drop policy if exists "Users can view own profile" on public.profiles;
create policy "Users can view own profile"
on public.profiles for select
to authenticated
using (auth.uid() = id);

drop policy if exists "Managers can view employee profiles" on public.profiles;
create policy "Managers can view employee profiles"
on public.profiles for select
to authenticated
using (public.is_user_manager());

drop policy if exists "Users can update own profile" on public.profiles;
create policy "Users can update own profile"
on public.profiles for update
to authenticated
using (auth.uid() = id)
with check (auth.uid() = id);
