-- Phase 2: lab PDF documents + editable biomarker rows (Path A confirm).
-- Apply after Phase 0.5 + Phase 1 migrations. See docs/phase2-lab-extract.md.

-- ---------------------------------------------------------------------------
-- lab_documents: one uploaded PDF per Path A lab session step
-- ---------------------------------------------------------------------------
do $$ begin
  create type public.lab_document_status as enum (
    'uploaded',
    'extracting',
    'extracted',
    'confirmed',
    'failed'
  );
exception
  when duplicate_object then null;
end $$;

create table if not exists public.lab_documents (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  storage_path text not null,
  original_filename text,
  status public.lab_document_status not null default 'uploaded',
  extract_error text,
  extracted_at timestamptz,
  confirmed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint lab_documents_storage_path_nonempty check (char_length(storage_path) > 0)
);

create index if not exists lab_documents_user_id_idx
  on public.lab_documents (user_id, created_at desc);

alter table public.lab_documents enable row level security;

drop policy if exists "lab_documents_select_own" on public.lab_documents;
create policy "lab_documents_select_own"
  on public.lab_documents for select
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists "lab_documents_insert_own" on public.lab_documents;
create policy "lab_documents_insert_own"
  on public.lab_documents for insert
  to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "lab_documents_update_own" on public.lab_documents;
create policy "lab_documents_update_own"
  on public.lab_documents for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "lab_documents_delete_own" on public.lab_documents;
create policy "lab_documents_delete_own"
  on public.lab_documents for delete
  to authenticated
  using (auth.uid() = user_id);

comment on table public.lab_documents is
  'Phase 2 uploaded lab PDF metadata; storage under lab-pdfs/{uid}/...; RLS own row only.';

-- ---------------------------------------------------------------------------
-- lab_biomarker_rows: extract + user confirm/edit
-- Flags H/L only when present on the PDF / left by the user — never invent meaning.
-- ---------------------------------------------------------------------------
create table if not exists public.lab_biomarker_rows (
  id uuid primary key default gen_random_uuid(),
  lab_document_id uuid not null references public.lab_documents (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  sort_order integer not null default 0,
  name text not null,
  value numeric,
  unit text,
  ref_range text,
  flag text check (flag is null or flag in ('H', 'L')),
  is_deleted boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists lab_biomarker_rows_document_idx
  on public.lab_biomarker_rows (lab_document_id, sort_order);

alter table public.lab_biomarker_rows enable row level security;

drop policy if exists "lab_biomarker_rows_select_own" on public.lab_biomarker_rows;
create policy "lab_biomarker_rows_select_own"
  on public.lab_biomarker_rows for select
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists "lab_biomarker_rows_insert_own" on public.lab_biomarker_rows;
create policy "lab_biomarker_rows_insert_own"
  on public.lab_biomarker_rows for insert
  to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "lab_biomarker_rows_update_own" on public.lab_biomarker_rows;
create policy "lab_biomarker_rows_update_own"
  on public.lab_biomarker_rows for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "lab_biomarker_rows_delete_own" on public.lab_biomarker_rows;
create policy "lab_biomarker_rows_delete_own"
  on public.lab_biomarker_rows for delete
  to authenticated
  using (auth.uid() = user_id);

comment on table public.lab_biomarker_rows is
  'Phase 2 biomarker rows from PDF extract; user may edit/delete before confirm. flag is H/L or null only.';

comment on column public.lab_biomarker_rows.flag is
  'H or L only when present on extract/PDF; UI must not invent clinical meaning.';
