-- Phase 1 demo supply reset (idempotent).
-- Clears and reloads fictional clinics, slots, and upsell partners.
-- Stable UUIDs so docs / later phases can reference fixed IDs.
--
-- Does NOT touch auth.users, Storage, or lab uploads.
-- Clears Phase 4/5 booking/pack rows and nulls profiles.clinic_id so clinic FK reset works.
--
-- Apply after schema migration 20261101120000_phase1_clinical_and_upsell_supply.sql
-- See docs/phase1-demo-seed.md for how Peter loads this.

begin;

-- Wipe demo supply + dependent Phase 4/5 booking rows (FK order).
-- Does NOT touch auth.users, Storage objects, lab docs, or Path A intake answers.
delete from public.summary_packs where true;
delete from public.upsell_bookings where true;
delete from public.clinical_bookings where true;
delete from public.path_a_matches where true;
update public.profiles set clinic_id = null where clinic_id is not null;
delete from public.appointment_slots;
delete from public.clinics;
delete from public.upsell_partners;

-- ---------------------------------------------------------------------------
-- Clinics (4 specialties) — stable UUIDs
-- ---------------------------------------------------------------------------
insert into public.clinics (
  id, specialty, name, district, address_line, why_match_blurb
) values
(
  '11111111-1111-4111-8111-111111111101',
  'menopause_aware_gp',
  'Pearl Midlife Family Clinic',
  'Central',
  '12/F, Fiction House, 88 Des Voeux Road Central',
  'Matched as a menopause-aware GP for general midlife symptom navigation and first-line care coordination.'
),
(
  '11111111-1111-4111-8111-111111111102',
  'gynae_endocrine',
  'Victoria Harbour Gynae & Endocrine',
  'Admiralty',
  'Suite 1503, Demo Tower, 1 Queensway',
  'Matched for gynae/endocrine review when hormonal and reproductive history needs specialist input.'
),
(
  '11111111-1111-4111-8111-111111111103',
  'sleep_mood',
  'Calm Peak Sleep & Mood Studio',
  'Causeway Bay',
  '5/F, Mock Mall, 500 Hennessy Road',
  'Matched for sleep and mood-focused consult when survey goals emphasise insomnia, anxiety, or low mood.'
),
(
  '11111111-1111-4111-8111-111111111104',
  'bone_heart_risk',
  'RidgeLine Bone & Heart Risk Consult',
  'Tsim Sha Tsui',
  '8/F, Sample Centre, 18 Salisbury Road',
  'Matched for bone and cardiovascular risk consult when labs/goals point at lipids, bone, or cardiometabolic concern.'
);

-- ---------------------------------------------------------------------------
-- Bookable slots — relative to Hong Kong "today" so a reset always yields
-- future availability. Three 30-min slots per clinic over the next few days.
-- ---------------------------------------------------------------------------
with slot_plan (slot_id, clinic_id, day_offset, hour, minute) as (
  values
    -- Pearl Midlife Family Clinic (menopause_aware_gp)
    ('22222222-2222-4222-8222-222222222101'::uuid, '11111111-1111-4111-8111-111111111101'::uuid, 1, 10, 0),
    ('22222222-2222-4222-8222-222222222102'::uuid, '11111111-1111-4111-8111-111111111101'::uuid, 1, 14, 30),
    ('22222222-2222-4222-8222-222222222103'::uuid, '11111111-1111-4111-8111-111111111101'::uuid, 2, 11, 0),
    -- Victoria Harbour Gynae & Endocrine
    ('22222222-2222-4222-8222-222222222201'::uuid, '11111111-1111-4111-8111-111111111102'::uuid, 1, 9, 30),
    ('22222222-2222-4222-8222-222222222202'::uuid, '11111111-1111-4111-8111-111111111102'::uuid, 2, 15, 0),
    ('22222222-2222-4222-8222-222222222203'::uuid, '11111111-1111-4111-8111-111111111102'::uuid, 3, 10, 30),
    -- Calm Peak Sleep & Mood Studio
    ('22222222-2222-4222-8222-222222222301'::uuid, '11111111-1111-4111-8111-111111111103'::uuid, 1, 16, 0),
    ('22222222-2222-4222-8222-222222222302'::uuid, '11111111-1111-4111-8111-111111111103'::uuid, 2, 10, 0),
    ('22222222-2222-4222-8222-222222222303'::uuid, '11111111-1111-4111-8111-111111111103'::uuid, 3, 14, 0),
    -- RidgeLine Bone & Heart Risk Consult
    ('22222222-2222-4222-8222-222222222401'::uuid, '11111111-1111-4111-8111-111111111104'::uuid, 1, 11, 30),
    ('22222222-2222-4222-8222-222222222402'::uuid, '11111111-1111-4111-8111-111111111104'::uuid, 2, 13, 0),
    ('22222222-2222-4222-8222-222222222403'::uuid, '11111111-1111-4111-8111-111111111104'::uuid, 3, 9, 0)
)
insert into public.appointment_slots (
  id, clinic_id, starts_at, ends_at, status, held_until, held_by, booked_by
)
select
  sp.slot_id,
  sp.clinic_id,
  (
    (date_trunc('day', timezone('Asia/Hong_Kong', now()))
      + make_interval(days => sp.day_offset, hours => sp.hour, mins => sp.minute)
    ) at time zone 'Asia/Hong_Kong'
  ),
  (
    (date_trunc('day', timezone('Asia/Hong_Kong', now()))
      + make_interval(days => sp.day_offset, hours => sp.hour, mins => sp.minute)
      + interval '30 minutes'
    ) at time zone 'Asia/Hong_Kong'
  ),
  'available'::public.slot_status,
  null,
  null,
  null
from slot_plan sp;

-- ---------------------------------------------------------------------------
-- Upsell partners — one per locked spend bucket
-- ---------------------------------------------------------------------------
insert into public.upsell_partners (
  id, spend_bucket, name, tagline, district
) values
(
  '33333333-3333-4333-8333-333333333301',
  'skincare_aesthetics',
  'Lumen Skin Lab HK',
  'Fictional aesthetics studio for midlife skin/hair spend alignment.',
  'Central'
),
(
  '33333333-3333-4333-8333-333333333302',
  'gym_physio',
  'Kowloon Motion Physio & Gym',
  'Fictional physio/gym partner for strength and joint spend.',
  'Jordan'
),
(
  '33333333-3333-4333-8333-333333333303',
  'supplements',
  'Green Harbour Supplements Co.',
  'Fictional retail partner for vitamin/supplement spend.',
  'Mong Kok'
),
(
  '33333333-3333-4333-8333-333333333304',
  'wellness_spa',
  'Mist & Tide Wellness Spa',
  'Fictional spa/wellness partner for recovery spend.',
  'Repulse Bay'
),
(
  '33333333-3333-4333-8333-333333333305',
  'mental_health',
  'Open Window Counselling HK',
  'Fictional counselling partner for mental-health spend.',
  'Wan Chai'
),
(
  '33333333-3333-4333-8333-333333333306',
  'private_gp',
  'Island Private GP Desk',
  'Fictional private GP partner for existing GP spend.',
  'Quarry Bay'
);

commit;

-- Quick verify (optional; safe to leave)
-- select specialty, name from public.clinics order by specialty;
-- select count(*) as slots from public.appointment_slots;
-- select spend_bucket, name from public.upsell_partners order by spend_bucket;
