-- Align existing candidate tables with the private CV storage flow.
alter table public.candidatos
  add column if not exists resume_bucket_id text,
  add column if not exists resume_object_path text,
  add column if not exists resume_original_filename text,
  add column if not exists resume_content_type text,
  add column if not exists resume_file_size_bytes bigint,
  add column if not exists resume_status text not null default 'none',
  add column if not exists resume_error_message text,
  add column if not exists resume_uploaded_at timestamptz;

insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values (
  'candidatos-cv',
  'candidatos-cv',
  false,
  15728640,
  array['application/pdf']
)
on conflict (id) do update set
  public = false,
  file_size_limit = 15728640,
  allowed_mime_types = array['application/pdf'];

drop policy if exists "Recruiters upload candidatos CV" on storage.objects;
create policy "Recruiters upload candidatos CV"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'candidatos-cv'
    and public.can_manage_candidates()
  );

drop policy if exists "Recruiters read candidatos CV" on storage.objects;
create policy "Recruiters read candidatos CV"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'candidatos-cv'
    and public.can_manage_candidates()
  );

drop policy if exists "Recruiters delete candidatos CV" on storage.objects;
create policy "Recruiters delete candidatos CV"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'candidatos-cv'
    and public.can_manage_candidates()
  );

notify pgrst, 'reload schema';
