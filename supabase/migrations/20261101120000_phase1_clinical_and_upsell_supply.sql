-- Phase 1: fictional clinical supply (4 specialties + bookable slots)
-- and fictional upsell partners (one per spend bucket).
-- Apply after 20261031140000_profiles_and_lab_pdfs.sql.
-- Seed data: supabase/seed/phase1_demo_supply.sql (idempotent reset).

-- ---------------------------------------------------------------------------
-- Enums (locked specialty + spend keys from prototype-lock)
-- ---------------------------------------------------------------------------
do $$ begin
  create type public.clinical_specialty as enum (
    'menopause_aware_gp',
    'gynae_endocrine',
    'sleep_mood',
    'bone_heart_risk'
  );
exception
  when duplicate_object then null;
end $$;

do $$ begin
  create type public.spend_bucket as enum (
    'skincare_aesthetics',
    'gym_physio',
    'supplements',
    'wellness_spa',
    'mental_health',
    'private_gp'
  );
exception
  when duplicate_object then null;
end $$;

do $$ begin
  create type public.slot_status as enum (
    'available',
    'held',
    'booked'
  );
exception
  when duplicate_object then null;
end $$;

-- ---------------------------------------------------------------------------
-- clinics — one fictional clinic per clinical specialty for the demo
-- ---------------------------------------------------------------------------
create table if not exists public.clinics (
  id uuid primary key,
  specialty public.clinical_specialty not null unique,
  name text not null,
  district text not null,
  address_line text not null,
  why_match_blurb text not null,
  created_at timestamptz not null default now()
);

comment on table public.clinics is
  'Phase 1 fictional clinical supply — four specialties. Not real partners.';

alter table public.clinics enable row level security;

drop policy if exists "clinics_select_authenticated" on public.clinics;
create policy "clinics_select_authenticated"
  on public.clinics for select
  to authenticated
  using (true);

-- ---------------------------------------------------------------------------
-- appointment_slots — bookable demo slots (holds land in Phase 4)
-- ---------------------------------------------------------------------------
create table if not exists public.appointment_slots (
  id uuid primary key,
  clinic_id uuid not null references public.clinics (id) on delete cascade,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  status public.slot_status not null default 'available',
  held_until timestamptz,
  held_by uuid references auth.users (id) on delete set null,
  booked_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  constraint appointment_slots_time_ok check (ends_at > starts_at),
  constraint appointment_slots_hold_shape check (
    (status <> 'held')
    or (held_until is not null)
  )
);

create index if not exists appointment_slots_clinic_starts_idx
  on public.appointment_slots (clinic_id, starts_at);

create index if not exists appointment_slots_status_idx
  on public.appointment_slots (status);

comment on table public.appointment_slots is
  'Phase 1 bookable fictional slots. 15-min auto-hold semantics arrive in Phase 4.';

alter table public.appointment_slots enable row level security;

drop policy if exists "appointment_slots_select_authenticated" on public.appointment_slots;
create policy "appointment_slots_select_authenticated"
  on public.appointment_slots for select
  to authenticated
  using (true);

-- Writes (hold/book) stay service_role / later RPC — no anon/authenticated write yet.

-- ---------------------------------------------------------------------------
-- upsell_partners — exactly one fictional partner per spend bucket
-- ---------------------------------------------------------------------------
create table if not exists public.upsell_partners (
  id uuid primary key,
  spend_bucket public.spend_bucket not null unique,
  name text not null,
  tagline text not null,
  district text not null,
  created_at timestamptz not null default now()
);

comment on table public.upsell_partners is
  'Phase 1 fictional upsell — one partner per locked spend bucket. Not real partners.';

alter table public.upsell_partners enable row level security;

drop policy if exists "upsell_partners_select_authenticated" on public.upsell_partners;
create policy "upsell_partners_select_authenticated"
  on public.upsell_partners for select
  to authenticated
  using (true);
