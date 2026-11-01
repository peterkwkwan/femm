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
| `20261101140000_phase2_lab_documents.sql` | `lab_documents`, `lab_biomarker_rows` + RLS |
| `20261101160000_phase3_spend_and_survey.sql` | `path_a_sessions`, spend selections, survey answers + RLS |
| `20261101180000_phase4_match_hold_upsell.sql` | Match/hold/bookings + hold/confirm/upsell RPCs |
| `20261101200000_phase5_path_c_summary_packs.sql` | Path C `summary_packs`, practitioner `clinic_id`, pack gen + booking RLS |
| `20261102100000_path_a_symptoms_chips.sql` | Symptoms-chip storage comments + Path C `goals.symptoms[]` snapshot |

## Edge Functions (Phase 2)

| Function | Role |
| --- | --- |
| `extract-lab-pdf` | Callable: `{ document_id }` → extract biomarker table from Storage PDF |

Deploy + smoke: [`docs/phase2-lab-extract.md`](../docs/phase2-lab-extract.md).  
Offline fixture: `npm run test:extract-fixture`.

## Reset Phase 1 demo supply

Idempotent wipe/reload of fictional clinics (4), slots (12), upsell partners (6):

- Dashboard: paste `seed/phase1_demo_supply.sql` → Run  
- Or: `DATABASE_URL=... npm run seed:phase1` (see [`docs/phase1-demo-seed.md`](../docs/phase1-demo-seed.md))

Does **not** touch Auth users, `profiles`, or Storage objects.

## Secrets

Never commit the **service_role** key or `DATABASE_URL`. Clients use Project URL + **anon** key only (`VITE_SUPABASE_*` / `--dart-define=SUPABASE_*`).
