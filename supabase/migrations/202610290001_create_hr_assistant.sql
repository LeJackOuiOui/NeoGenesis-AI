create table if not exists public.hr_knowledge_documents (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  area text not null default 'General',
  content text not null,
  is_active boolean not null default true,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint hr_knowledge_documents_title_not_blank check (btrim(title) <> ''),
  constraint hr_knowledge_documents_content_not_blank check (btrim(content) <> '')
);

alter table public.hr_knowledge_documents enable row level security;

drop policy if exists "Employees read active HR knowledge" on public.hr_knowledge_documents;
create policy "Employees read active HR knowledge"
  on public.hr_knowledge_documents for select to authenticated
  using (
    is_active
    and exists (
      select 1 from public.profiles
      where id = auth.uid()
        and role in ('Empleado', 'Administrador', 'Responsable RRHH')
    )
  );

drop policy if exists "HR manages HR knowledge" on public.hr_knowledge_documents;
create policy "HR manages HR knowledge"
  on public.hr_knowledge_documents for all to authenticated
  using (
    exists (
      select 1 from public.profiles
      where id = auth.uid()
        and role in ('Administrador', 'Responsable RRHH')
    )
  )
  with check (
    exists (
      select 1 from public.profiles
      where id = auth.uid()
        and role in ('Administrador', 'Responsable RRHH')
    )
  );

create table if not exists public.hr_assistant_interactions (
  id uuid primary key default gen_random_uuid(),
  employee_id uuid not null references auth.users(id) on delete cascade,
  employee_name text not null,
  employee_email text not null,
  question text not null,
  answer text,
  status text not null default 'processing'
    check (status in ('processing', 'answered', 'waiting_for_hr')),
  sources jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now(),
  answered_by uuid references auth.users(id) on delete set null,
  answered_at timestamptz,
  constraint hr_assistant_question_not_blank check (btrim(question) <> '')
);

create index if not exists hr_assistant_interactions_employee_created_idx
  on public.hr_assistant_interactions (employee_id, created_at desc);
create index if not exists hr_assistant_interactions_waiting_idx
  on public.hr_assistant_interactions (created_at)
  where status = 'waiting_for_hr';

alter table public.hr_assistant_interactions enable row level security;

drop policy if exists "Employees read own HR assistant interactions"
  on public.hr_assistant_interactions;
create policy "Employees read own HR assistant interactions"
  on public.hr_assistant_interactions for select to authenticated
  using (employee_id = auth.uid());

drop policy if exists "HR reads all HR assistant interactions"
  on public.hr_assistant_interactions;
create policy "HR reads all HR assistant interactions"
  on public.hr_assistant_interactions for select to authenticated
  using (
    exists (
      select 1 from public.profiles
      where id = auth.uid()
        and role in ('Administrador', 'Responsable RRHH')
    )
  );

drop policy if exists "HR answers escalated HR assistant interactions"
  on public.hr_assistant_interactions;
create policy "HR answers escalated HR assistant interactions"
  on public.hr_assistant_interactions for update to authenticated
  using (
    status = 'waiting_for_hr'
    and exists (
      select 1 from public.profiles
      where id = auth.uid()
        and role in ('Administrador', 'Responsable RRHH')
    )
  )
  with check (
    status = 'answered'
    and answered_by = auth.uid()
    and exists (
      select 1 from public.profiles
      where id = auth.uid()
        and role in ('Administrador', 'Responsable RRHH')
    )
  );

revoke insert, update, delete on public.hr_assistant_interactions from authenticated;
grant select on public.hr_assistant_interactions to authenticated;
grant update (answer, status, answered_by, answered_at)
  on public.hr_assistant_interactions to authenticated;
grant select on public.hr_knowledge_documents to authenticated;
grant insert, update, delete on public.hr_knowledge_documents to authenticated;

notify pgrst, 'reload schema';
