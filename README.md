# femm

Hong Kong menopause **care-navigation** prototype (not a diagnosis).  
Stack lock: **Flutter Android** user client · **thin web** practitioner portal · **Supabase** (Auth + Postgres + Storage) · **Google Auth** for users and practitioners.

Phase 0.5 cut Firebase over to Supabase free tier. **Phase 1** seeded supply + synthetic PDF. **Phase 2** PDF upload → extract → confirm. **Phase 3** spend multi-select + ≤8-question survey + match gate. **Phase 4** rule-based match + 15-min hold + same-bucket upsell. **Phase 5** Path C summary packs + practitioner portal. **Phase 6** demo script, hold edge-case hardening, disclaimer audit, Android smoke notes, deferral checklist.

## Repo layout

| Path | Role |
| --- | --- |
| `apps/mobile` | Flutter Android user app (`supabase_flutter`) |
| `apps/portal` | Vite + TypeScript practitioner portal (`@supabase/supabase-js`) |
| `supabase/migrations` | Postgres schema + RLS (`profiles`, clinics/slots/upsell, lab docs, match/bookings, Path C `summary_packs`, `lab-pdfs`) |
| `supabase/functions` | Edge Functions (`extract-lab-pdf`) |
| `supabase/seed` | Idempotent Phase 1 demo supply reset SQL |
| `fixtures/labs` | Synthetic HK women’s panel PDF + golden extract JSON |

## Prerequisites

- Flutter 3.35+ (stable), Android SDK / emulator or device
- Node 22+ for the portal
- A **Supabase Free** project with **Google** Auth enabled (see setup below)
- Google Cloud OAuth **Web** client (pasted into Supabase) + Android OAuth client (`com.femm.femm_app` + debug SHA-1)

## One-time Supabase setup (Peter)

Live credentials are **not** in this repo. Placeholders compile; Auth against production needs your Free project.

Full click-path (Google OAuth, redirects, SHA-1, SQL, bucket): **[`docs/supabase-setup.md`](./docs/supabase-setup.md)**. Summary:

1. Create a Supabase project on **Free** (region near HK if offered, e.g. Singapore).
2. **Project Settings → API:** copy **Project URL** + **anon** `public` key. Never put **service_role** in the apps or git.
3. Google Cloud: OAuth consent (Testing + test users) → **Web** OAuth client with redirect  
   `https://YOUR_PROJECT_REF.supabase.co/auth/v1/callback` and origin `http://localhost:5173`.
4. Supabase → **Authentication → Providers → Google:** paste Web Client ID + Secret.  
   **URL Configuration:** Site URL `http://localhost:5173`; allow that redirect.
5. Google Cloud → **Android** OAuth client: package `com.femm.femm_app` + debug SHA-1.
6. Run SQL in `supabase/migrations/20261031140000_profiles_and_lab_pdfs.sql` (profiles RLS + private `lab-pdfs` bucket).
7. **Phase 1 schema + seed** (after 0.5 SQL): run `20261101120000_phase1_clinical_and_upsell_supply.sql`, then reset demo supply — see **[`docs/phase1-demo-seed.md`](./docs/phase1-demo-seed.md)**.
8. **Phase 2:** run `20261101140000_phase2_lab_documents.sql`, then deploy `extract-lab-pdf` — see **[`docs/phase2-lab-extract.md`](./docs/phase2-lab-extract.md)**.
9. **Phase 3:** run `20261101160000_phase3_spend_and_survey.sql` — see **[`docs/phase3-spend-survey.md`](./docs/phase3-spend-survey.md)**.
10. **Phase 4:** run `20261101180000_phase4_match_hold_upsell.sql` — see **[`docs/phase4-match-hold-upsell.md`](./docs/phase4-match-hold-upsell.md)**.
11. **Phase 5:** run `20261101200000_phase5_path_c_summary_packs.sql` — see **[`docs/phase5-path-c-portal.md`](./docs/phase5-path-c-portal.md)**.
12. Portal: copy `apps/portal/.env.example` → `apps/portal/.env.local` and fill `VITE_SUPABASE_*`.
13. Mobile: pass dart-defines (or copy `apps/mobile/dart_defines.example.json` → `dart_defines.json`, gitignored):

   ```bash
   cd apps/mobile
   flutter run \
     --dart-define=SUPABASE_URL=https://YOUR_PROJECT_REF.supabase.co \
     --dart-define=SUPABASE_ANON_KEY=eyJ... \
     --dart-define=GOOGLE_SERVER_CLIENT_ID=YOUR_WEB_CLIENT_ID.apps.googleusercontent.com
   ```

**Do not commit** `.env.local`, `dart_defines.json`, or the service_role key.

## Phase 1 — load / reset demo seed

Full steps: **[`docs/phase1-demo-seed.md`](./docs/phase1-demo-seed.md)**. Short path:

1. Apply `supabase/migrations/20261101120000_phase1_clinical_and_upsell_supply.sql` once (SQL Editor).
2. Reset supply anytime by pasting `supabase/seed/phase1_demo_supply.sql` into the SQL Editor **or**:

   ```bash
   export DATABASE_URL='postgresql://postgres.:YOUR_DB_PASSWORD@db.YOUR_PROJECT_REF.supabase.co:5432/postgres'
   npm run seed:phase1
   ```

Expect **4 clinics**, **12 slots**, **6 upsell partners**. Synthetic upload PDF: `fixtures/labs/synthetic-hk-womens-panel.pdf` (golden extract beside it).

## Run — Flutter Android (`apps/mobile`)

```bash
cd apps/mobile
flutter pub get
flutter run --dart-define-from-file=dart_defines.json
# or the three --dart-define flags above
```

Scaffold boots with placeholder URL/anon key (sign-in fails until you wire a real project).  
Sign-in upserts `public.profiles` for that auth uid (`role: user`).

## Run — practitioner portal (`apps/portal`)

```bash
cd apps/portal
npm install
cp .env.example .env.local   # then edit VITE_SUPABASE_URL + VITE_SUPABASE_ANON_KEY
npm run dev
```

Or from root: `npm run portal:dev`. Open `http://localhost:5173`.  
Google Auth → claim a demo clinic → upcoming appointments → Path C summary / labs / PDF.  
Smoke: **[`docs/phase5-path-c-portal.md`](./docs/phase5-path-c-portal.md)**.

## Phase 0.5 acceptance

- [x] 0.5.3 Postgres `profiles` + RLS (migration checked in)
- [x] 0.5.4 Private `lab-pdfs` bucket stub + own-uid policies (migration)
- [x] 0.5.5 Flutter: Firebase/FlutterFire removed; `supabase_flutter` + Google ID token
- [x] 0.5.6 Portal: Firebase JS removed; `@supabase/supabase-js` + `VITE_SUPABASE_*`
- [x] 0.5.7 README / env examples; Firebase emulators no longer the primary path
- [ ] 0.5.1–0.5.2 Peter: create Free project + enable Google OAuth (outside git)

## Phase 1 acceptance

- [x] 1.1 Synthetic HK women’s panel PDF (`fixtures/labs/synthetic-hk-womens-panel.pdf`)
- [x] 1.2 Golden extract JSON fixture (same folder)
- [x] 1.3 Fictional clinical supply: 4 specialties + bookable slots (schema + seed)
- [x] 1.4 Fictional upsell partners: one per six spend buckets
- [x] 1.5 Seed reset script + docs (`npm run seed:phase1` / SQL Editor)

## Phase 2 — PDF upload / extract / confirm

Signed-in users upload a lab PDF to private `lab-pdfs`, call Edge Function `extract-lab-pdf`, edit/confirm biomarker rows.

- Offline golden test: `npm run test:extract-fixture` (needs [Deno](https://deno.land))
- Peter deploy + smoke steps: **[`docs/phase2-lab-extract.md`](./docs/phase2-lab-extract.md)**

Acceptance:

- [x] 2.1 Auth’d Storage upload + `lab_documents` row
- [x] 2.2 Edge Function extract → biomarker rows
- [x] 2.3 Flutter confirm/edit UI + persist
- [x] 2.4 H/L only when present (no invented meaning)
- [x] 2.5 Fixture test vs golden JSON
- [ ] Peter: apply Phase 2 SQL + `supabase functions deploy extract-lab-pdf` (outside git)

## Phase 3 — Spend + survey + match gate

After labs confirm: multi-select six spend buckets (≥1), answer 8 clinical + skin/hair questions, persist both. Match screen stays locked until spend + survey complete.

Peter apply + smoke: **[`docs/phase3-spend-survey.md`](./docs/phase3-spend-survey.md)**

Acceptance:

- [x] 3.1 Spend multi-select (six locked buckets, ≥1, saved on Path A session)
- [x] 3.2 Survey ≤8 Qs (clinical + skin/hair) persisted
- [x] 3.3 Match unreachable until labs confirmed path has spend + survey complete
- [ ] Peter: apply Phase 3 SQL (outside git)

## Phase 4 — Match / hold / upsell

Rule-based clinical specialty + canned why-copy, 15-minute auto-hold on a Phase 1 seed slot, same-bucket upsell on one screen. Clinical and upsell book independently. Sticky not-a-diagnosis disclaimer.

Peter apply + smoke: **[`docs/phase4-match-hold-upsell.md`](./docs/phase4-match-hold-upsell.md)**

Acceptance:

- [x] 4.1 Rule-based match engine + canned why-copy (no LLM)
- [x] 4.2 Match screen: clinical primary, upsell secondary, sticky disclaimer
- [x] 4.3 15-minute auto-hold with countdown; expired hold releases slot
- [x] 4.4 Explicit confirm → clinical booking (independent of upsell)
- [x] 4.5 Same-bucket upsell cards (Phase 1 partners); book / skip independently
- [x] 4.6 Clinical only / upsell only / both / neither all leave session valid
- [ ] Peter: apply Phase 4 SQL (+ re-seed slots if needed) (outside git)

## Phase 5 — Path C summary + practitioner portal

On clinical (and lighter upsell) booking, a `summary_packs` snapshot is written. Booked clinic practitioners Google-auth into the portal, claim their fictional clinic, open upcoming appointments, expand labs, download the original PDF. RLS + Storage policies block unbooked / other clinics.

Peter apply + smoke: **[`docs/phase5-path-c-portal.md`](./docs/phase5-path-c-portal.md)**

Acceptance:

- [x] 5.1 Summary pack on booking (goals, spend, match reason, flagged labs, path tag, disclaimer)
- [x] 5.2 Practitioner Google Auth + clinic link (`claim_demo_clinic`)
- [x] 5.3 Upcoming appointments for auth’d clinic only
- [x] 5.4 Scannable summary → expand full labs
- [x] 5.5 Original PDF download
- [x] 5.6 Booking-scoped RLS + Storage select for booked practitioners
- [ ] Peter: apply Phase 5 SQL (outside git)

## Phase 6 — Demo hardening + handoff

Full Path A → Path C demo without engineer improvisation. Hold expire/release, double-confirm, and leave-and-return are defined in the client; disclaimers audited; deferred scope listed.

**Run the final demo:** [`docs/phase6-demo-handoff.md`](./docs/phase6-demo-handoff.md) (§6.1 script, <10 min).

Acceptance:

- [x] 6.1 End-to-end demo script (seed → user Path A → practitioner Path C)
- [x] 6.2 Hold edge cases (expire/release, double-confirm, leave-and-return)
- [x] 6.3 Disclaimer audit (sticky match + Path C; one-line on every pack)
- [x] 6.4 Android smoke notes (Peter device/emulator)
- [x] 6.5 Deferral checklist (below + phase6 doc)
- [ ] Peter: run the §6.1 demo once on Android + portal (outside git)

## Explicitly not in this build

Do **not** demo or treat as shipped:

| Deferred | Notes |
| --- | --- |
| Path B | Post–health-check / GP-nudge entry |
| Wearables | Sync or snapshot |
| iOS day-one | After Android demo works |
| Real partners / inventory | Fictional seed only |
| Imaging OCR / AI / diagnostic image storage | Never |
| Cancer/CT advice, HRT dosing, diagnosis claims | Never in prototype |
| Bilingual UI, EHR write-back, own skincare line | Out |
| Inventing new spend categories | Upsell only within selected buckets |
| Firebase / Blaze billing | Abandoned — do not re-enable Storage on Blaze |

## License

UNLICENSED / private prototype.
