-- Ejecutar en Supabase SQL Editor.
-- Crea el perfil aunque el proyecto exija confirmar el correo electrónico.

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

drop policy if exists "Users can view own profile" on public.profiles;
create policy "Users can view own profile"
on public.profiles for select
to authenticated
using (auth.uid() = id);

drop policy if exists "Users can update own profile" on public.profiles;
create policy "Users can update own profile"
on public.profiles for update
to authenticated
using (auth.uid() = id)
with check (auth.uid() = id);
