# femm

Hong Kong menopause **care-navigation** prototype (not a diagnosis).  
Stack lock: **Flutter Android** user client · **thin web** practitioner portal · **Supabase** (Auth + Postgres + Storage) · **Google Auth** for users and practitioners.

Phase 0.5 cuts the Phase 0 Firebase bootstrap over to Supabase free tier. Later phases add Path A → Path C.

## Repo layout

| Path | Role |
| --- | --- |
| `apps/mobile` | Flutter Android user app (`supabase_flutter`) |
| `apps/portal` | Vite + TypeScript practitioner portal (`@supabase/supabase-js`) |
| `supabase/migrations` | Postgres `profiles` + private `lab-pdfs` Storage + RLS |

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
7. Portal: copy `apps/portal/.env.example` → `apps/portal/.env.local` and fill `VITE_SUPABASE_*`.
8. Mobile: pass dart-defines (or copy `apps/mobile/dart_defines.example.json` → `dart_defines.json`, gitignored):

   ```bash
   cd apps/mobile
   flutter run \
     --dart-define=SUPABASE_URL=https://YOUR_PROJECT_REF.supabase.co \
     --dart-define=SUPABASE_ANON_KEY=eyJ... \
     --dart-define=GOOGLE_SERVER_CLIENT_ID=YOUR_WEB_CLIENT_ID.apps.googleusercontent.com
   ```

**Do not commit** `.env.local`, `dart_defines.json`, or the service_role key.

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
Google button uses Supabase `signInWithOAuth({ provider: 'google' })`.

## Phase 0.5 acceptance

- [x] 0.5.3 Postgres `profiles` + RLS (migration checked in)
- [x] 0.5.4 Private `lab-pdfs` bucket stub + own-uid policies (migration)
- [x] 0.5.5 Flutter: Firebase/FlutterFire removed; `supabase_flutter` + Google ID token
- [x] 0.5.6 Portal: Firebase JS removed; `@supabase/supabase-js` + `VITE_SUPABASE_*`
- [x] 0.5.7 README / env examples; Firebase emulators no longer the primary path
- [ ] 0.5.1–0.5.2 Peter: create Free project + enable Google OAuth (outside git)

## Explicitly not in this build (yet)

Path B, wearables, iOS day-one, real partner inventory, imaging OCR/AI, diagnosis/HRT claims, bilingual UI, PDF Edge Function (Phase 2), clinic seed (Phase 1).

Firebase / Blaze is abandoned for this prototype — do not re-enable Storage on Blaze.

## License

UNLICENSED / private prototype.
