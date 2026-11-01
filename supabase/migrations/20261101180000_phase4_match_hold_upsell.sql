-- Phase 4: rule-based match persistence, 15-min slot holds, clinical + upsell bookings.
-- Apply after Phase 3 (path_a_sessions) + Phase 1 supply (clinics / slots / partners).
-- Hold/book writes go through SECURITY DEFINER RPCs (slots had no authenticated write in Phase 1).

-- ---------------------------------------------------------------------------
-- path_a_matches: one clinical recommendation (+ optional active hold) per session
-- ---------------------------------------------------------------------------
create table if not exists public.path_a_matches (
  session_id uuid primary key references public.path_a_sessions (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  specialty public.clinical_specialty not null,
  why_copy text not null,
  clinic_id uuid not null references public.clinics (id),
  slot_id uuid references public.appointment_slots (id) on delete set null,
  hold_expires_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint path_a_matches_why_copy_nonempty check (char_length(why_copy) > 0)
);

create index if not exists path_a_matches_user_id_idx
  on public.path_a_matches (user_id);

alter table public.path_a_matches enable row level security;

drop policy if exists "path_a_matches_select_own" on public.path_a_matches;
create policy "path_a_matches_select_own"
  on public.path_a_matches for select
  to authenticated
  using (auth.uid() = user_id);

-- Inserts/updates happen via RPCs (security definer); users do not write directly.

comment on table public.path_a_matches is
  'Phase 4 rule-based clinical match + optional 15-min slot hold for Path A session.';

-- ---------------------------------------------------------------------------
-- clinical_bookings: confirmed clinical appointment (independent of upsell)
-- ---------------------------------------------------------------------------
create table if not exists public.clinical_bookings (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.path_a_sessions (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  clinic_id uuid not null references public.clinics (id),
  slot_id uuid not null references public.appointment_slots (id),
  specialty public.clinical_specialty not null,
  why_copy text not null,
  booked_at timestamptz not null default now(),
  constraint clinical_bookings_session_unique unique (session_id),
  constraint clinical_bookings_slot_unique unique (slot_id),
  constraint clinical_bookings_why_copy_nonempty check (char_length(why_copy) > 0)
);

create index if not exists clinical_bookings_user_id_idx
  on public.clinical_bookings (user_id, booked_at desc);

alter table public.clinical_bookings enable row level security;

drop policy if exists "clinical_bookings_select_own" on public.clinical_bookings;
create policy "clinical_bookings_select_own"
  on public.clinical_bookings for select
  to authenticated
  using (auth.uid() = user_id);

comment on table public.clinical_bookings is
  'Phase 4 confirmed clinical booking from a held slot. Independent of upsell bookings.';

-- ---------------------------------------------------------------------------
-- upsell_bookings: optional partner bookings (same-bucket only; independent)
-- ---------------------------------------------------------------------------
create table if not exists public.upsell_bookings (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.path_a_sessions (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  partner_id uuid not null references public.upsell_partners (id),
  spend_bucket public.spend_bucket not null,
  booked_at timestamptz not null default now(),
  constraint upsell_bookings_session_partner_unique unique (session_id, partner_id),
  constraint upsell_bookings_session_bucket_unique unique (session_id, spend_bucket)
);

create index if not exists upsell_bookings_user_id_idx
  on public.upsell_bookings (user_id, booked_at desc);

alter table public.upsell_bookings enable row level security;

drop policy if exists "upsell_bookings_select_own" on public.upsell_bookings;
create policy "upsell_bookings_select_own"
  on public.upsell_bookings for select
  to authenticated
  using (auth.uid() = user_id);

comment on table public.upsell_bookings is
  'Phase 4 optional upsell bookings for spend buckets the user already selected. Independent of clinical.';

-- ---------------------------------------------------------------------------
-- Helpers / RPCs
-- ---------------------------------------------------------------------------

create or replace function public.release_expired_slot_holds()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  n integer;
begin
  update public.appointment_slots
  set
    status = 'available',
    held_until = null,
    held_by = null
  where status = 'held'
    and held_until is not null
    and held_until < now();

  get diagnostics n = row_count;

  -- Clear match hold pointers that pointed at expired slots.
  update public.path_a_matches m
  set
    slot_id = null,
    hold_expires_at = null,
    updated_at = now()
  where m.hold_expires_at is not null
    and m.hold_expires_at < now()
    and not exists (
      select 1 from public.clinical_bookings b where b.session_id = m.session_id
    );

  return n;
end;
$$;

revoke all on function public.release_expired_slot_holds() from public;
grant execute on function public.release_expired_slot_holds() to authenticated;

comment on function public.release_expired_slot_holds() is
  'Phase 4: release held slots past held_until; clear stale match hold pointers.';

-- Hold (or refresh) a recommended slot for a Path A session. 15-minute TTL.
create or replace function public.hold_slot_for_match(
  p_session_id uuid,
  p_slot_id uuid,
  p_specialty public.clinical_specialty,
  p_why_copy text,
  p_clinic_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_session public.path_a_sessions%rowtype;
  v_slot public.appointment_slots%rowtype;
  v_clinic public.clinics%rowtype;
  v_expires timestamptz;
  v_existing_booking uuid;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  if p_why_copy is null or char_length(trim(p_why_copy)) = 0 then
    raise exception 'why_copy required';
  end if;

  select * into v_session
  from public.path_a_sessions
  where id = p_session_id and user_id = v_uid;

  if not found then
    raise exception 'session not found';
  end if;

  if v_session.spend_completed_at is null or v_session.survey_completed_at is null then
    raise exception 'session not ready for match';
  end if;

  select id into v_existing_booking
  from public.clinical_bookings
  where session_id = p_session_id;

  if found then
    raise exception 'clinical already booked for session';
  end if;

  perform public.release_expired_slot_holds();

  select * into v_clinic
  from public.clinics
  where id = p_clinic_id and specialty = p_specialty;

  if not found then
    raise exception 'clinic/specialty mismatch';
  end if;

  select * into v_slot
  from public.appointment_slots
  where id = p_slot_id
  for update;

  if not found then
    raise exception 'slot not found';
  end if;

  if v_slot.clinic_id <> p_clinic_id then
    raise exception 'slot does not belong to clinic';
  end if;

  -- Allow: available, or already held by this user (refresh TTL).
  if v_slot.status = 'booked' then
    raise exception 'slot already booked';
  end if;

  if v_slot.status = 'held' and v_slot.held_by is distinct from v_uid then
    raise exception 'slot held by another user';
  end if;

  if v_slot.status not in ('available', 'held') then
    raise exception 'slot not holdable';
  end if;

  -- Release any other active hold this user has on a different slot for this session.
  update public.appointment_slots s
  set
    status = 'available',
    held_until = null,
    held_by = null
  where s.held_by = v_uid
    and s.status = 'held'
    and s.id <> p_slot_id;

  v_expires := now() + interval '15 minutes';

  update public.appointment_slots
  set
    status = 'held',
    held_until = v_expires,
    held_by = v_uid
  where id = p_slot_id;

  insert into public.path_a_matches (
    session_id, user_id, specialty, why_copy, clinic_id, slot_id, hold_expires_at, updated_at
  ) values (
    p_session_id, v_uid, p_specialty, trim(p_why_copy), p_clinic_id, p_slot_id, v_expires, now()
  )
  on conflict (session_id) do update set
    specialty = excluded.specialty,
    why_copy = excluded.why_copy,
    clinic_id = excluded.clinic_id,
    slot_id = excluded.slot_id,
    hold_expires_at = excluded.hold_expires_at,
    updated_at = now();

  return jsonb_build_object(
    'session_id', p_session_id,
    'slot_id', p_slot_id,
    'clinic_id', p_clinic_id,
    'specialty', p_specialty,
    'why_copy', trim(p_why_copy),
    'hold_expires_at', v_expires
  );
end;
$$;

revoke all on function public.hold_slot_for_match(uuid, uuid, public.clinical_specialty, text, uuid) from public;
grant execute on function public.hold_slot_for_match(uuid, uuid, public.clinical_specialty, text, uuid) to authenticated;

comment on function public.hold_slot_for_match(uuid, uuid, public.clinical_specialty, text, uuid) is
  'Phase 4: 15-min auto-hold on recommended slot + upsert path_a_matches.';

-- Convert active hold → clinical booking (explicit confirm).
create or replace function public.confirm_clinical_booking(p_session_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_match public.path_a_matches%rowtype;
  v_slot public.appointment_slots%rowtype;
  v_booking public.clinical_bookings%rowtype;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  perform public.release_expired_slot_holds();

  select * into v_match
  from public.path_a_matches
  where session_id = p_session_id and user_id = v_uid;

  if not found then
    raise exception 'match not found';
  end if;

  select * into v_booking
  from public.clinical_bookings
  where session_id = p_session_id;

  if found then
    return jsonb_build_object(
      'id', v_booking.id,
      'session_id', v_booking.session_id,
      'slot_id', v_booking.slot_id,
      'clinic_id', v_booking.clinic_id,
      'specialty', v_booking.specialty,
      'why_copy', v_booking.why_copy,
      'booked_at', v_booking.booked_at,
      'already_booked', true
    );
  end if;

  if v_match.slot_id is null or v_match.hold_expires_at is null then
    raise exception 'no active hold';
  end if;

  if v_match.hold_expires_at < now() then
    raise exception 'hold expired';
  end if;

  select * into v_slot
  from public.appointment_slots
  where id = v_match.slot_id
  for update;

  if not found then
    raise exception 'slot not found';
  end if;

  if v_slot.status <> 'held'
     or v_slot.held_by is distinct from v_uid
     or v_slot.held_until is null
     or v_slot.held_until < now() then
    raise exception 'hold no longer valid';
  end if;

  update public.appointment_slots
  set
    status = 'booked',
    booked_by = v_uid,
    held_until = null,
    held_by = null
  where id = v_slot.id;

  insert into public.clinical_bookings (
    session_id, user_id, clinic_id, slot_id, specialty, why_copy
  ) values (
    p_session_id, v_uid, v_match.clinic_id, v_slot.id, v_match.specialty, v_match.why_copy
  )
  returning * into v_booking;

  update public.path_a_matches
  set
    hold_expires_at = null,
    updated_at = now()
  where session_id = p_session_id;

  return jsonb_build_object(
    'id', v_booking.id,
    'session_id', v_booking.session_id,
    'slot_id', v_booking.slot_id,
    'clinic_id', v_booking.clinic_id,
    'specialty', v_booking.specialty,
    'why_copy', v_booking.why_copy,
    'booked_at', v_booking.booked_at,
    'already_booked', false
  );
end;
$$;

revoke all on function public.confirm_clinical_booking(uuid) from public;
grant execute on function public.confirm_clinical_booking(uuid) to authenticated;

comment on function public.confirm_clinical_booking(uuid) is
  'Phase 4: convert active 15-min hold into clinical_bookings row; independent of upsell.';

-- Book an upsell partner for a selected spend bucket (no slot inventory).
create or replace function public.book_upsell_partner(
  p_session_id uuid,
  p_partner_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_session public.path_a_sessions%rowtype;
  v_partner public.upsell_partners%rowtype;
  v_booking public.upsell_bookings%rowtype;
  v_has_bucket boolean;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  select * into v_session
  from public.path_a_sessions
  where id = p_session_id and user_id = v_uid;

  if not found then
    raise exception 'session not found';
  end if;

  select * into v_partner
  from public.upsell_partners
  where id = p_partner_id;

  if not found then
    raise exception 'partner not found';
  end if;

  select exists (
    select 1
    from public.path_a_spend_selections s
    where s.session_id = p_session_id
      and s.user_id = v_uid
      and s.spend_bucket = v_partner.spend_bucket
  ) into v_has_bucket;

  if not v_has_bucket then
    raise exception 'partner bucket not in user spend selections';
  end if;

  select * into v_booking
  from public.upsell_bookings
  where session_id = p_session_id and partner_id = p_partner_id;

  if found then
    return jsonb_build_object(
      'id', v_booking.id,
      'session_id', v_booking.session_id,
      'partner_id', v_booking.partner_id,
      'spend_bucket', v_booking.spend_bucket,
      'booked_at', v_booking.booked_at,
      'already_booked', true
    );
  end if;

  insert into public.upsell_bookings (
    session_id, user_id, partner_id, spend_bucket
  ) values (
    p_session_id, v_uid, p_partner_id, v_partner.spend_bucket
  )
  returning * into v_booking;

  return jsonb_build_object(
    'id', v_booking.id,
    'session_id', v_booking.session_id,
    'partner_id', v_booking.partner_id,
    'spend_bucket', v_booking.spend_bucket,
    'booked_at', v_booking.booked_at,
    'already_booked', false
  );
end;
$$;

revoke all on function public.book_upsell_partner(uuid, uuid) from public;
grant execute on function public.book_upsell_partner(uuid, uuid) to authenticated;

comment on function public.book_upsell_partner(uuid, uuid) is
  'Phase 4: book fictional upsell partner for a user-selected spend bucket; independent of clinical.';
