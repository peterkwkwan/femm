-- Phase 5: Path C summary packs + practitioner clinic link + booking-scoped RLS.
-- Apply after Phase 4 (clinical_bookings / upsell_bookings / confirm RPCs).
-- Packs are generated inside confirm_clinical_booking / book_upsell_partner.

-- ---------------------------------------------------------------------------
-- profiles.clinic_id — link practitioner Google identity to fictional clinic
-- ---------------------------------------------------------------------------
alter table public.profiles
  add column if not exists clinic_id uuid references public.clinics (id) on delete set null;

create index if not exists profiles_clinic_id_idx
  on public.profiles (clinic_id)
  where clinic_id is not null;

comment on column public.profiles.clinic_id is
  'Phase 5: practitioner → fictional clinic seed. Null for users. Set via claim_demo_clinic.';

-- ---------------------------------------------------------------------------
-- summary_packs: scannable Path C pack snapshot at booking time
-- ---------------------------------------------------------------------------
do $$ begin
  create type public.summary_pack_kind as enum ('clinical', 'upsell');
exception
  when duplicate_object then null;
end $$;

create table if not exists public.summary_packs (
  id uuid primary key default gen_random_uuid(),
  kind public.summary_pack_kind not null,
  session_id uuid not null references public.path_a_sessions (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  clinical_booking_id uuid unique references public.clinical_bookings (id) on delete cascade,
  upsell_booking_id uuid unique references public.upsell_bookings (id) on delete cascade,
  clinic_id uuid references public.clinics (id) on delete set null,
  partner_id uuid references public.upsell_partners (id) on delete set null,
  path_tag text not null default 'Path A',
  disclaimer text not null
    default 'Care-navigation only — not a diagnosis or medical advice.',
  goals jsonb not null default '{}'::jsonb,
  spend_buckets jsonb not null default '[]'::jsonb,
  match_reason text,
  flagged_labs jsonb not null default '[]'::jsonb,
  labs jsonb not null default '[]'::jsonb,
  lab_document_id uuid references public.lab_documents (id) on delete set null,
  storage_path text,
  original_filename text,
  patient_email text,
  patient_display_name text,
  slot_starts_at timestamptz,
  specialty public.clinical_specialty,
  created_at timestamptz not null default now(),
  constraint summary_packs_booking_xor check (
    (kind = 'clinical' and clinical_booking_id is not null and upsell_booking_id is null)
    or (kind = 'upsell' and upsell_booking_id is not null and clinical_booking_id is null)
  ),
  constraint summary_packs_path_tag_nonempty check (char_length(path_tag) > 0),
  constraint summary_packs_disclaimer_nonempty check (char_length(disclaimer) > 0)
);

create index if not exists summary_packs_clinic_id_idx
  on public.summary_packs (clinic_id, created_at desc)
  where clinic_id is not null;

create index if not exists summary_packs_session_id_idx
  on public.summary_packs (session_id);

alter table public.summary_packs enable row level security;

-- Patients can read their own packs.
drop policy if exists "summary_packs_select_own" on public.summary_packs;
create policy "summary_packs_select_own"
  on public.summary_packs for select
  to authenticated
  using (auth.uid() = user_id);

-- Booked clinic practitioner can read clinical packs for their clinic.
drop policy if exists "summary_packs_select_booked_practitioner" on public.summary_packs;
create policy "summary_packs_select_booked_practitioner"
  on public.summary_packs for select
  to authenticated
  using (
    kind = 'clinical'
    and clinic_id is not null
    and exists (
      select 1
      from public.profiles p
      where p.id = auth.uid()
        and p.role = 'practitioner'
        and p.clinic_id is not null
        and p.clinic_id = summary_packs.clinic_id
    )
  );

comment on table public.summary_packs is
  'Phase 5 Path C summary pack snapshot at booking. Clinical packs are portal-visible to booked clinic practitioners only.';

-- Clinical bookings: booked practitioner (same clinic) may select.
drop policy if exists "clinical_bookings_select_booked_practitioner" on public.clinical_bookings;
create policy "clinical_bookings_select_booked_practitioner"
  on public.clinical_bookings for select
  to authenticated
  using (
    exists (
      select 1
      from public.profiles p
      where p.id = auth.uid()
        and p.role = 'practitioner'
        and p.clinic_id is not null
        and p.clinic_id = clinical_bookings.clinic_id
    )
  );

-- Appointment slots: practitioners need starts_at for upcoming list (booked at their clinic).
drop policy if exists "appointment_slots_select_booked_practitioner" on public.appointment_slots;
create policy "appointment_slots_select_booked_practitioner"
  on public.appointment_slots for select
  to authenticated
  using (
    exists (
      select 1
      from public.profiles p
      join public.clinical_bookings b on b.clinic_id = p.clinic_id and b.slot_id = appointment_slots.id
      where p.id = auth.uid()
        and p.role = 'practitioner'
        and p.clinic_id is not null
    )
  );

-- ---------------------------------------------------------------------------
-- Storage: booked practitioner may read the original lab PDF for their booking
-- ---------------------------------------------------------------------------
drop policy if exists "lab_pdfs_select_booked_practitioner" on storage.objects;
create policy "lab_pdfs_select_booked_practitioner"
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'lab-pdfs'
    and exists (
      select 1
      from public.profiles p
      join public.clinical_bookings b on b.clinic_id = p.clinic_id
      join public.path_a_sessions s on s.id = b.session_id
      join public.lab_documents d on d.id = s.lab_document_id
      where p.id = auth.uid()
        and p.role = 'practitioner'
        and p.clinic_id is not null
        and d.storage_path = name
    )
  );

-- ---------------------------------------------------------------------------
-- Helpers: gather session snapshot for packs
-- ---------------------------------------------------------------------------
create or replace function public._path_c_session_snapshot(p_session_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_session public.path_a_sessions%rowtype;
  v_doc public.lab_documents%rowtype;
  v_goals jsonb := '{}'::jsonb;
  v_answers jsonb := '{}'::jsonb;
  v_spend jsonb := '[]'::jsonb;
  v_flagged jsonb := '[]'::jsonb;
  v_labs jsonb := '[]'::jsonb;
  v_match_reason text;
  v_patient_email text;
  v_patient_display_name text;
  r record;
begin
  select * into v_session
  from public.path_a_sessions
  where id = p_session_id;

  if not found then
    raise exception 'session not found';
  end if;

  select * into v_doc
  from public.lab_documents
  where id = v_session.lab_document_id;

  select p.email, p.display_name
  into v_patient_email, v_patient_display_name
  from public.profiles p
  where p.id = v_session.user_id;

  for r in
    select question_key, answer
    from public.path_a_survey_answers
    where session_id = p_session_id
    order by question_key
  loop
    v_answers := v_answers || jsonb_build_object(r.question_key, r.answer);
  end loop;

  v_goals := jsonb_build_object(
    'primary_goal', coalesce(v_answers->>'primary_goal', ''),
    'answers', v_answers
  );

  select coalesce(jsonb_agg(s.spend_bucket::text order by s.spend_bucket::text), '[]'::jsonb)
  into v_spend
  from public.path_a_spend_selections s
  where s.session_id = p_session_id;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'name', b.name,
        'value', b.value,
        'unit', b.unit,
        'ref_range', b.ref_range,
        'flag', b.flag,
        'sort_order', b.sort_order
      )
      order by b.sort_order, b.name
    ),
    '[]'::jsonb
  )
  into v_labs
  from public.lab_biomarker_rows b
  where b.lab_document_id = v_session.lab_document_id
    and b.is_deleted = false;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'name', b.name,
        'value', b.value,
        'unit', b.unit,
        'ref_range', b.ref_range,
        'flag', b.flag,
        'sort_order', b.sort_order
      )
      order by b.sort_order, b.name
    ),
    '[]'::jsonb
  )
  into v_flagged
  from public.lab_biomarker_rows b
  where b.lab_document_id = v_session.lab_document_id
    and b.is_deleted = false
    and b.flag in ('H', 'L');

  select m.why_copy into v_match_reason
  from public.path_a_matches m
  where m.session_id = p_session_id;

  return jsonb_build_object(
    'session_id', v_session.id,
    'user_id', v_session.user_id,
    'lab_document_id', v_session.lab_document_id,
    'storage_path', v_doc.storage_path,
    'original_filename', v_doc.original_filename,
    'patient_email', v_patient_email,
    'patient_display_name', v_patient_display_name,
    'goals', v_goals,
    'spend_buckets', v_spend,
    'match_reason', v_match_reason,
    'flagged_labs', v_flagged,
    'labs', v_labs
  );
end;
$$;

revoke all on function public._path_c_session_snapshot(uuid) from public;

comment on function public._path_c_session_snapshot(uuid) is
  'Phase 5 internal: gather goals/spend/labs snapshot for Path C pack generation.';

-- ---------------------------------------------------------------------------
-- claim_demo_clinic: practitioner links Google identity to a seed clinic
-- ---------------------------------------------------------------------------
create or replace function public.claim_demo_clinic(p_clinic_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_clinic public.clinics%rowtype;
  v_profile public.profiles%rowtype;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  select * into v_clinic
  from public.clinics
  where id = p_clinic_id;

  if not found then
    raise exception 'clinic not found';
  end if;

  select * into v_profile
  from public.profiles
  where id = v_uid;

  if not found then
    raise exception 'profile not found — sign in via portal first';
  end if;

  if v_profile.role is distinct from 'practitioner' then
    raise exception 'only practitioners can claim a demo clinic';
  end if;

  update public.profiles
  set
    clinic_id = p_clinic_id,
    updated_at = now()
  where id = v_uid;

  return jsonb_build_object(
    'clinic_id', v_clinic.id,
    'clinic_name', v_clinic.name,
    'specialty', v_clinic.specialty,
    'district', v_clinic.district
  );
end;
$$;

revoke all on function public.claim_demo_clinic(uuid) from public;
grant execute on function public.claim_demo_clinic(uuid) to authenticated;

comment on function public.claim_demo_clinic(uuid) is
  'Phase 5 prototype: link practitioner profile to a fictional clinic seed.';

-- ---------------------------------------------------------------------------
-- Replace confirm_clinical_booking — generate clinical Path C pack on confirm
-- ---------------------------------------------------------------------------
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
  v_snap jsonb;
  v_pack public.summary_packs%rowtype;
  v_disclaimer text := 'Care-navigation only — not a diagnosis or medical advice.';
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
    select * into v_pack
    from public.summary_packs
    where clinical_booking_id = v_booking.id;

    return jsonb_build_object(
      'id', v_booking.id,
      'session_id', v_booking.session_id,
      'slot_id', v_booking.slot_id,
      'clinic_id', v_booking.clinic_id,
      'specialty', v_booking.specialty,
      'why_copy', v_booking.why_copy,
      'booked_at', v_booking.booked_at,
      'already_booked', true,
      'summary_pack_id', v_pack.id
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

  -- Path C clinical summary pack (goals, spend, match reason, flagged labs, path tag, disclaimer).
  v_snap := public._path_c_session_snapshot(p_session_id);

  insert into public.summary_packs (
    kind,
    session_id,
    user_id,
    clinical_booking_id,
    clinic_id,
    path_tag,
    disclaimer,
    goals,
    spend_buckets,
    match_reason,
    flagged_labs,
    labs,
    lab_document_id,
    storage_path,
    original_filename,
    patient_email,
    patient_display_name,
    slot_starts_at,
    specialty
  ) values (
    'clinical',
    p_session_id,
    v_uid,
    v_booking.id,
    v_booking.clinic_id,
    'Path A',
    v_disclaimer,
    coalesce(v_snap->'goals', '{}'::jsonb),
    coalesce(v_snap->'spend_buckets', '[]'::jsonb),
    coalesce(v_booking.why_copy, v_snap->>'match_reason'),
    coalesce(v_snap->'flagged_labs', '[]'::jsonb),
    coalesce(v_snap->'labs', '[]'::jsonb),
    (v_snap->>'lab_document_id')::uuid,
    v_snap->>'storage_path',
    v_snap->>'original_filename',
    v_snap->>'patient_email',
    v_snap->>'patient_display_name',
    v_slot.starts_at,
    v_booking.specialty
  )
  returning * into v_pack;

  return jsonb_build_object(
    'id', v_booking.id,
    'session_id', v_booking.session_id,
    'slot_id', v_booking.slot_id,
    'clinic_id', v_booking.clinic_id,
    'specialty', v_booking.specialty,
    'why_copy', v_booking.why_copy,
    'booked_at', v_booking.booked_at,
    'already_booked', false,
    'summary_pack_id', v_pack.id
  );
end;
$$;

revoke all on function public.confirm_clinical_booking(uuid) from public;
grant execute on function public.confirm_clinical_booking(uuid) to authenticated;

comment on function public.confirm_clinical_booking(uuid) is
  'Phase 4/5: convert hold → clinical_bookings + generate Path C clinical summary pack.';

-- ---------------------------------------------------------------------------
-- Replace book_upsell_partner — lighter Path C pack on upsell book
-- ---------------------------------------------------------------------------
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
  v_snap jsonb;
  v_pack public.summary_packs%rowtype;
  v_disclaimer text := 'Care-navigation only — not a diagnosis or medical advice.';
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
    select * into v_pack
    from public.summary_packs
    where upsell_booking_id = v_booking.id;

    return jsonb_build_object(
      'id', v_booking.id,
      'session_id', v_booking.session_id,
      'partner_id', v_booking.partner_id,
      'spend_bucket', v_booking.spend_bucket,
      'booked_at', v_booking.booked_at,
      'already_booked', true,
      'summary_pack_id', v_pack.id
    );
  end if;

  insert into public.upsell_bookings (
    session_id, user_id, partner_id, spend_bucket
  ) values (
    p_session_id, v_uid, p_partner_id, v_partner.spend_bucket
  )
  returning * into v_booking;

  -- Lighter Path C pack: goals, spend, optional match reason, flagged labs, path tag, disclaimer.
  v_snap := public._path_c_session_snapshot(p_session_id);

  insert into public.summary_packs (
    kind,
    session_id,
    user_id,
    upsell_booking_id,
    partner_id,
    path_tag,
    disclaimer,
    goals,
    spend_buckets,
    match_reason,
    flagged_labs,
    labs,
    lab_document_id,
    storage_path,
    original_filename,
    patient_email,
    patient_display_name
  ) values (
    'upsell',
    p_session_id,
    v_uid,
    v_booking.id,
    v_partner.id,
    'Path A',
    v_disclaimer,
    coalesce(v_snap->'goals', '{}'::jsonb),
    coalesce(v_snap->'spend_buckets', '[]'::jsonb),
    v_snap->>'match_reason',
    coalesce(v_snap->'flagged_labs', '[]'::jsonb),
    '[]'::jsonb, -- lighter: no full labs expand table
    (v_snap->>'lab_document_id')::uuid,
    v_snap->>'storage_path',
    v_snap->>'original_filename',
    v_snap->>'patient_email',
    v_snap->>'patient_display_name'
  )
  returning * into v_pack;

  return jsonb_build_object(
    'id', v_booking.id,
    'session_id', v_booking.session_id,
    'partner_id', v_booking.partner_id,
    'spend_bucket', v_booking.spend_bucket,
    'booked_at', v_booking.booked_at,
    'already_booked', false,
    'summary_pack_id', v_pack.id
  );
end;
$$;

revoke all on function public.book_upsell_partner(uuid, uuid) from public;
grant execute on function public.book_upsell_partner(uuid, uuid) to authenticated;

comment on function public.book_upsell_partner(uuid, uuid) is
  'Phase 4/5: book upsell partner + generate lighter Path C summary pack.';
