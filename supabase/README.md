# Supabase (Phase 0.5+)

SQL migrations + seed for the femm prototype. Auth is **Supabase Auth (Google)**; DB is Postgres; lab PDFs go in the private `lab-pdfs` Storage bucket.

## Apply migrations

After you create a Free project (see click-path setup linked from the root README):

1. **Dashboard:** SQL → New query → paste each file under `migrations/` in timestamp order → Run  
2. **Or CLI:** `supabase link` then `supabase db push`

| Migration | Purpose |
| --- | --- |
| `20261031140000_profiles_and_lab_pdfs.sql` | `profiles` + private `lab-pdfs` + RLS |
| `20261101120000_phase1_clinical_and_upsell_supply.sql` | `clinics`, `appointment_slots`, `upsell_partners` + enums + select RLS |

## Reset Phase 1 demo supply

Idempotent wipe/reload of fictional clinics (4), slots (12), upsell partners (6):

- Dashboard: paste `seed/phase1_demo_supply.sql` → Run  
- Or: `DATABASE_URL=... npm run seed:phase1` (see [`docs/phase1-demo-seed.md`](../docs/phase1-demo-seed.md))

Does **not** touch Auth users, `profiles`, or Storage objects.

## Secrets

Never commit the **service_role** key or `DATABASE_URL`. Clients use Project URL + **anon** key only (`VITE_SUPABASE_*` / `--dart-define=SUPABASE_*`).
