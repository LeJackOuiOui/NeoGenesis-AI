-- La única tabla propia de este flujo es public.candidatos.
create or replace function public.can_manage_candidates()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid()
      and role in ('Administrador', 'Responsable RRHH', 'Reclutador')
  );
$$;

grant execute on function public.can_manage_candidates() to authenticated;

create table if not exists public.candidatos (
  id uuid primary key default gen_random_uuid(),
  full_name text not null,
  email text,
  phone text,
  created_by uuid references auth.users(id) on delete set null default auth.uid(),
  resume_data jsonb not null default '{"summary":"","skills":[],"experience":[],"education":[]}'::jsonb,
  resume_bucket_id text,
  resume_object_path text,
  resume_original_filename text,
  resume_content_type text,
  resume_file_size_bytes bigint,
  resume_status text not null default 'none'
    check (resume_status in ('none', 'queued', 'processing', 'completed', 'failed')),
  resume_error_message text,
  resume_uploaded_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Completa columnas si candidatos ya existía por una ejecución anterior.
alter table public.candidatos
  add column if not exists created_by uuid references auth.users(id) on delete set null default auth.uid(),
  add column if not exists resume_bucket_id text,
  add column if not exists resume_object_path text,
  add column if not exists resume_original_filename text,
  add column if not exists resume_content_type text,
  add column if not exists resume_file_size_bytes bigint,
  add column if not exists resume_status text not null default 'none',
  add column if not exists resume_error_message text,
  add column if not exists resume_uploaded_at timestamptz;

-- Migra los candidatos ya creados, conservando IDs para que los perfiles sigan enlazados.
do $$
begin
  if to_regclass('public.candidates') is not null then
    insert into public.candidatos (
      id, full_name, email, phone, created_by, resume_data, created_at, updated_at
    )
    select id, full_name, email, phone, created_by, resume_data, created_at, updated_at
    from public.candidates
    on conflict (id) do nothing;
  end if;

  if to_regclass('public.candidate_resumes') is not null then
    execute $migration$
      update public.candidatos as c
      set resume_bucket_id = r.bucket_id,
          resume_object_path = r.object_path,
          resume_original_filename = r.original_filename,
          resume_content_type = r.content_type,
          resume_file_size_bytes = r.file_size_bytes,
          resume_status = r.status,
          resume_error_message = r.error_message,
          resume_uploaded_at = r.created_at
      from (
        select distinct on (candidate_id)
          candidate_id, bucket_id, object_path, original_filename,
          content_type, file_size_bytes, status, error_message, created_at
        from public.candidate_resumes
        order by candidate_id, created_at desc
      ) as r
      where c.id = r.candidate_id
    $migration$;
  end if;
end;
$$;

-- Elimina las tablas anteriores de candidatos/CV; sus datos quedan consolidados arriba.
drop table if exists public.candidate_resumes;
drop table if exists public.candidates;

alter table public.candidatos enable row level security;
drop policy if exists "Recruiters manage candidates" on public.candidatos;
create policy "Recruiters manage candidates"
  on public.candidatos for all to authenticated
  using (public.can_manage_candidates())
  with check (public.can_manage_candidates());

-- Los PDF van a Storage; sus metadatos y el JSON extraído quedan en candidatos.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('candidatos-cv', 'candidatos-cv', false, 15728640, array['application/pdf'])
on conflict (id) do update set
  public = false,
  file_size_limit = 15728640,
  allowed_mime_types = array['application/pdf'];

drop policy if exists "Recruiters upload candidatos CV" on storage.objects;
create policy "Recruiters upload candidatos CV"
  on storage.objects for insert to authenticated
  with check (bucket_id = 'candidatos-cv' and public.can_manage_candidates());

drop policy if exists "Recruiters read candidatos CV" on storage.objects;
create policy "Recruiters read candidatos CV"
  on storage.objects for select to authenticated
  using (bucket_id = 'candidatos-cv' and public.can_manage_candidates());

drop policy if exists "Recruiters delete candidatos CV" on storage.objects;
create policy "Recruiters delete candidatos CV"
  on storage.objects for delete to authenticated
  using (bucket_id = 'candidatos-cv' and public.can_manage_candidates());
