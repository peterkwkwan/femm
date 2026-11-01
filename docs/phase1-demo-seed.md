# Phase 1 — Synthetic PDF + demo supply seed

Demo data so extract → match → Path C can be deterministic without real clinics.  
**Prerequisite:** Phase 0.5 migration applied (`profiles` + `lab-pdfs`).

## What lands in the repo

| Package | Path |
| --- | --- |
| Synthetic HK women’s panel PDF | [`fixtures/labs/synthetic-hk-womens-panel.pdf`](../fixtures/labs/synthetic-hk-womens-panel.pdf) |
| Golden extract JSON | [`fixtures/labs/synthetic-hk-womens-panel.extract.json`](../fixtures/labs/synthetic-hk-womens-panel.extract.json) |
| PDF regenerator | [`scripts/generate_synthetic_lab_pdf.py`](../scripts/generate_synthetic_lab_pdf.py) |
| Schema (clinics / slots / upsell) | [`supabase/migrations/20261101120000_phase1_clinical_and_upsell_supply.sql`](../supabase/migrations/20261101120000_phase1_clinical_and_upsell_supply.sql) |
| Idempotent seed reset | [`supabase/seed/phase1_demo_supply.sql`](../supabase/seed/phase1_demo_supply.sql) |

No Path A Flutter UI in this phase beyond whatever already exists for Auth.

## One-time: apply Phase 1 schema

After Phase 0.5 SQL is already on your Free project:

1. Supabase Dashboard → **SQL → New query**
2. Paste contents of `supabase/migrations/20261101120000_phase1_clinical_and_upsell_supply.sql`
3. **Run**

Or, if you use the CLI: `supabase db push` (after `supabase link`).

Creates:

- Enums: `clinical_specialty`, `spend_bucket`, `slot_status`
- Tables: `clinics`, `appointment_slots`, `upsell_partners` (RLS: authenticated **select** only)

## Reset demo supply (repeatable)

Wipes and reloads fictional clinics, slots, and upsell partners. Also clears Phase 4/5 bookings/packs and nulls `profiles.clinic_id` so clinic FKs can reset. Leaves Auth users, Storage, and lab intake alone. Slots are scheduled relative to **today (Asia/Hong_Kong)** so a reset always yields future bookable times.

### Option A — Dashboard (simplest)

1. Supabase → **SQL → New query**
2. Paste **all** of `supabase/seed/phase1_demo_supply.sql`
3. **Run**

### Option B — Script (needs DB password / connection string)

```bash
# From repo root. Set DATABASE_URL to the Postgres URI from
# Project Settings → Database (use the session / URI that includes the DB password).
# Never commit DATABASE_URL or the service_role key.

export DATABASE_URL='postgresql://postgres.:YOUR_DB_PASSWORD@db.YOUR_PROJECT_REF.supabase.co:5432/postgres'
npm run seed:phase1
# equivalent: ./scripts/seed-phase1.sh
```

Expect exit 0 and printed counts: **4 clinics**, **12 slots**, **6 upsell partners**.

## Seed contents (stable IDs)

### Clinical specialties → clinics

| Specialty key | Clinic (fictional) | Clinic UUID |
| --- | --- | --- |
| `menopause_aware_gp` | Pearl Midlife Family Clinic | `11111111-1111-4111-8111-111111111101` |
| `gynae_endocrine` | Victoria Harbour Gynae & Endocrine | `11111111-1111-4111-8111-111111111102` |
| `sleep_mood` | Calm Peak Sleep & Mood Studio | `11111111-1111-4111-8111-111111111103` |
| `bone_heart_risk` | RidgeLine Bone & Heart Risk Consult | `11111111-1111-4111-8111-111111111104` |

Each clinic gets **3 × 30-minute** `available` slots over the next few HK calendar days.

### Upsell partners (one per spend bucket)

| Spend bucket | Partner (fictional) | Partner UUID |
| --- | --- | --- |
| `skincare_aesthetics` | Lumen Skin Lab HK | `33333333-3333-4333-8333-333333333301` |
| `gym_physio` | Kowloon Motion Physio & Gym | `33333333-3333-4333-8333-333333333302` |
| `supplements` | Green Harbour Supplements Co. | `33333333-3333-4333-8333-333333333303` |
| `wellness_spa` | Mist & Tide Wellness Spa | `33333333-3333-4333-8333-333333333304` |
| `mental_health` | Open Window Counselling HK | `33333333-3333-4333-8333-333333333305` |
| `private_gp` | Island Private GP Desk | `33333333-3333-4333-8333-333333333306` |

## Synthetic PDF + golden fixture

Regenerate PDF only if you intentionally change biomarker rows (then update the golden JSON in the same change):

```bash
pip install reportlab   # once
python3 scripts/generate_synthetic_lab_pdf.py
```

Phase 2 Edge Function tests should target `fixtures/labs/synthetic-hk-womens-panel.extract.json`.  
Flags (`H`/`L`) appear **only** where the PDF prints them — extractors must not invent clinical meaning. Ignore imaging content if ever present.

## Verify in Table Editor

- `clinics` → 4 rows  
- `appointment_slots` → 12 rows, `status = available`  
- `upsell_partners` → 6 rows  

## Related

- Product locks: store `docs/prototype-lock.md`  
- Build plan Phase 1: store `docs/build-plan.md`  
- Auth/project setup: [`supabase-setup.md`](./supabase-setup.md)
