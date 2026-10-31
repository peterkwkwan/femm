# Supabase (Phase 0.5+)

SQL migrations for the femm prototype. Auth is **Supabase Auth (Google)**; DB is Postgres; lab PDFs go in the private `lab-pdfs` Storage bucket.

## Apply migrations

After you create a Free project (see click-path setup linked from the root README):

1. **Dashboard:** SQL → New query → paste `migrations/20261031140000_profiles_and_lab_pdfs.sql` → Run  
2. **Or CLI:** `supabase link` then `supabase db push` (optional; not required for Phase 0.5 exit)

## What this creates

| Object | Purpose |
| --- | --- |
| `public.profiles` | Own-row profile (`id` = `auth.users.id`); roles `user` / `practitioner` |
| Storage bucket `lab-pdfs` | Private; objects under `{uid}/...` only for that auth user |

RLS notes are in the migration file. Practitioner read-by-booking is Phase 5.

## Secrets

Never commit the **service_role** key. Clients use Project URL + **anon** key only (`VITE_SUPABASE_*` / `--dart-define=SUPABASE_*`).
