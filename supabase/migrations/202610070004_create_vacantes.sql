-- Vacantes y sus resultados se almacenan aquí; public.candidatos conserva su esquema.
-- evaluations guarda el estado por candidate_id sin alterar la tabla de candidatos.
create table if not exists public.vacantes (
  id text primary key,
  title text not null,
  min_experience_years numeric not null default 0
    check (min_experience_years >= 0),
  required_skills text[] not null default '{}',
  min_education_level text not null default 'none'
    check (min_education_level in ('none', 'secondary', 'technical', 'bachelor', 'postgraduate', 'doctorate')),
  evaluations jsonb not null default '{}'::jsonb,
  removed_candidate_ids text[] not null default '{}',
  created_by uuid references auth.users(id) on delete set null default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.vacantes
  add column if not exists evaluations jsonb not null default '{}'::jsonb,
  add column if not exists removed_candidate_ids text[] not null default '{}',
  alter column min_experience_years type numeric;

alter table public.vacantes enable row level security;
drop policy if exists "Recruiters manage vacantes" on public.vacantes;
create policy "Recruiters manage vacantes"
  on public.vacantes for all to authenticated
  using (public.can_manage_candidates())
  with check (public.can_manage_candidates());

-- Migra criterios y evaluaciones de la versión temporal anterior, si existe,
-- y finalmente quita screening_data para restaurar el esquema de candidatos.
do $$
declare
  candidate_row record;
  vacancy_entry record;
  vacancy_data jsonb;
  evaluation_data jsonb;
  candidate_evaluations jsonb;
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'candidatos'
      and column_name = 'screening_data'
  ) then
    for candidate_row in
      select id, screening_data
      from public.candidatos
      where screening_data is not null
    loop
      if jsonb_typeof(candidate_row.screening_data -> 'vacancies') is distinct from 'object' then
        continue;
      end if;

      for vacancy_entry in
        select key, value
        from jsonb_each(candidate_row.screening_data -> 'vacancies')
      loop
        vacancy_data := vacancy_entry.value;
        evaluation_data := vacancy_data -> 'evaluation';
        candidate_evaluations := '{}'::jsonb;
        if jsonb_typeof(evaluation_data) = 'object' then
          candidate_evaluations := jsonb_build_object(
            candidate_row.id::text,
            jsonb_build_object(
              'meets_criteria', coalesce((evaluation_data ->> 'meets_criteria')::boolean, false),
              'exclusion_reasons', coalesce(evaluation_data -> 'exclusion_reasons', '[]'::jsonb),
              'evaluated_at', evaluation_data -> 'evaluated_at'
            )
          );
        end if;

        insert into public.vacantes (
          id, title, min_experience_years, required_skills,
          min_education_level, evaluations, created_by
        ) values (
          vacancy_entry.key,
          coalesce(vacancy_data ->> 'title', 'Vacante'),
          coalesce((vacancy_data ->> 'min_experience_years')::numeric, 0),
          coalesce(array(select jsonb_array_elements_text(vacancy_data -> 'required_skills')), '{}'),
          coalesce(vacancy_data ->> 'min_education_level', 'none'),
          candidate_evaluations,
          null
        )
        on conflict (id) do update
          set evaluations = public.vacantes.evaluations || excluded.evaluations,
              updated_at = now();
      end loop;
    end loop;

    alter table public.candidatos drop column screening_data;
  end if;
end;
$$;
