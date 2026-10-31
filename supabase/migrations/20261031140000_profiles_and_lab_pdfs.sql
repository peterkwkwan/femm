-- Phase 0.5 baseline: profiles + private lab-pdfs Storage bucket + RLS.
-- Apply via Supabase SQL Editor or `supabase db push` after linking a project.
-- See docs/supabase-setup.md (store) / README for Peter click-path setup.

-- ---------------------------------------------------------------------------
-- profiles (minimal; clinics/seed arrive in Phase 1)
-- ---------------------------------------------------------------------------
create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  email text,
  display_name text,
  role text not null default 'user' check (role in ('user', 'practitioner')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

drop policy if exists "profiles_select_own" on public.profiles;
create policy "profiles_select_own"
  on public.profiles for select
  using (auth.uid() = id);

drop policy if exists "profiles_insert_own" on public.profiles;
create policy "profiles_insert_own"
  on public.profiles for insert
  with check (auth.uid() = id);

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own"
  on public.profiles for update
  using (auth.uid() = id)
  with check (auth.uid() = id);

comment on table public.profiles is
  'Phase 0.5 user/practitioner profile; RLS: own row only. Tighten practitioner reads in Phase 5.';

-- ---------------------------------------------------------------------------
-- Storage: private lab-pdfs bucket
-- Paths: {auth.uid()}/... — practitioners read-by-booking lands in Phase 5.
-- ---------------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'lab-pdfs',
  'lab-pdfs',
  false,
  10485760, -- 10 MiB prototype PDFs
  array['application/pdf']::text[]
)
on conflict (id) do update
set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "lab_pdfs_insert_own" on storage.objects;
create policy "lab_pdfs_insert_own"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'lab-pdfs'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "lab_pdfs_select_own" on storage.objects;
create policy "lab_pdfs_select_own"
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'lab-pdfs'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "lab_pdfs_update_own" on storage.objects;
create policy "lab_pdfs_update_own"
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'lab-pdfs'
    and (storage.foldername(name))[1] = auth.uid()::text
  )
  with check (
    bucket_id = 'lab-pdfs'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "lab_pdfs_delete_own" on storage.objects;
create policy "lab_pdfs_delete_own"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'lab-pdfs'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- RLS notes (Phase 0.5 → Phase 5):
-- * Do not mark lab-pdfs public; Path C downloads use signed URLs or auth'd download.
-- * Do not turn profiles RLS off for convenience.
-- * Practitioner read of another user's PDF/pack is Phase 5 (booking-scoped), not here.
-- * service_role bypasses RLS — only for Edge Functions / trusted server (Phase 2+).
