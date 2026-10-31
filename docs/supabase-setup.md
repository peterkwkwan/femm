# Supabase + Google Auth setup (Phase 0.5)

Click-by-click setup for the **Supabase free tier** after Phase 0 landed on Firebase and before Phase 1 seed/PDF work. Do the steps in order; later steps need IDs from earlier ones.

**Why Supabase (not Firebase):** Firebase Storage requires the Blaze (paid) plan. Peter does not want to pay for this prototype. Stay on Supabase **Free** — Auth (Google), Postgres, Storage, and later Edge Functions for PDF extract. Do not enable paid add-ons unless Peter explicitly asks.

**Constants from the scaffold (do not invent different ones):**

| Thing | Value |
| --- | --- |
| Android applicationId / package | `com.femm.femm_app` |
| Mobile app path | `apps/mobile` |
| Portal path | `apps/portal` |
| Portal local URL (Vite default) | `http://localhost:5173` |
| Suggested Storage bucket | `lab-pdfs` |

**What you will end up with:** a Supabase Free project; Google OAuth working; a private Storage bucket; Flutter + portal env vars filled; Google Sign-In on phone and portal against Supabase (no Firebase client).

**Shipping:** After cutover works, push straight to `main` (no PRs unless Peter asks). See Phase 0.5 in build-plan (project docs).

---

## Step 1 — Create the Supabase project (Free)

### 1a. Create the project

1. Open [Supabase Dashboard](https://supabase.com/dashboard) and sign in (GitHub/Google is fine).
2. **New project**.
3. **Organization:** your personal org (or create one).
4. **Name:** e.g. `femm`.
5. **Database password:** generate a strong password and store it in a password manager. You need it for direct Postgres access / some CLI flows; the Flutter and portal apps use the **anon** key, not this password.
6. **Region:** pick something close to Hong Kong users if offered (e.g. `Southeast Asia (Singapore)` / `ap-southeast-1`). Region is hard to change later.
7. Confirm plan is **Free**. Create project and wait until the dashboard shows the project as ready (often ~1–2 minutes).

### 1b. Copy project URL and anon key

1. Left sidebar: **Project Settings** (gear) → **API**.
2. Copy and keep in a scratch note:

| Label in UI | Use as |
| --- | --- |
| **Project URL** | `SUPABASE_URL` / `VITE_SUPABASE_URL` (e.g. `https://abcdefghijk.supabase.co`) |
| **anon** `public` key | `SUPABASE_ANON_KEY` / `VITE_SUPABASE_ANON_KEY` |

**Never** put the **service_role** key in the Flutter app, portal `.env`, or git. Service role bypasses RLS — only for trusted server/Edge Functions later (Phase 2).

### 1c. Free-tier sanity check

On Free you should have Auth, Database (Postgres), Storage, and Edge Functions available without entering a card for normal prototype use. If the UI nudges you toward Pro for Storage or Auth, stop and re-check you are on Free / not using a Blaze-style requirement — that was the Firebase problem we are avoiding.

---

## Step 2 — Enable Google Auth in Supabase

Supabase Auth will federate Google. You create a Google Cloud OAuth **Web** client, then paste Client ID + Secret into Supabase.

### 2a. Google Cloud project + OAuth consent

1. Open [Google Cloud Console](https://console.cloud.google.com/).
2. Create a project (e.g. `femm`) or reuse an existing one. Note: this is **not** a Firebase project requirement anymore.
3. **APIs & Services → OAuth consent screen**.
4. User type **External** (unless Workspace Internal fits you).
5. App name `femm`, support email, developer contact → Save.
6. Publishing **Testing** is fine: under **Test users**, add the Google accounts you and practitioners will use.
7. Scopes: default (`email`, `profile`, `openid`) is enough for prototype sign-in.

### 2b. Create OAuth Web client

1. **APIs & Services → Credentials → Create credentials → OAuth client ID**.
2. Application type: **Web application**.
3. Name: `femm supabase` (or similar).
4. **Authorized JavaScript origins** — add:
   - `http://localhost:5173`
   - Optionally `http://127.0.0.1:5173`
   - Your Supabase URL origin, e.g. `https://YOUR_PROJECT_REF.supabase.co`
5. **Authorized redirect URIs** — add **exactly** (replace `YOUR_PROJECT_REF`):

   ```text
   https://YOUR_PROJECT_REF.supabase.co/auth/v1/callback
   ```

   Also add local portal callback if you use a custom redirect in the SPA (often the Supabase callback alone is enough when using `signInWithOAuth` with `redirectTo` pointing at the portal origin — still keep the Supabase callback URI above):

   ```text
   http://localhost:5173
   http://localhost:5173/auth/callback
   ```

   (Match whatever path the portal implements after cutover; if unsure, start with Supabase callback + `http://localhost:5173`.)

6. Create. Copy **Client ID** and **Client secret**.

### 2c. Paste into Supabase Auth

1. Supabase Dashboard → **Authentication → Providers → Google**.
2. Enable Google.
3. Paste **Client ID** and **Client Secret** from Google Cloud.
4. Save.

### 2d. Site URL and redirect allow list

1. Supabase → **Authentication → URL Configuration**.
2. **Site URL:** for local portal work use `http://localhost:5173` (change when you deploy).
3. **Redirect URLs** allow list — include:
   - `http://localhost:5173`
   - `http://localhost:5173/**` (if wildcards are supported in your dashboard version)
   - Any production portal URL later

Without these, Google sign-in completes at Google/Supabase then fails to return to the portal.

---

## Step 3 — Android package + SHA-1 (native Google Sign-In)

Flutter on Android often uses a native Google Sign-In flow, then passes the ID token into Supabase (`signInWithIdToken`). Google still needs the Android app’s package name + SHA-1.

### 3a. Confirm package name

```bash
grep applicationId apps/mobile/android/app/build.gradle.kts
```

Expect `com.femm.femm_app`.

### 3b. Debug SHA-1

Default debug keystore (`password` / `alias` both related to `android`):

```bash
keytool -list -v \
  -alias androiddebugkey \
  -keystore ~/.android/debug.keystore \
  -storepass android -keypass android
```

Copy the `SHA1:` fingerprint. If the keystore is missing, run a debug build once (`cd apps/mobile && flutter build apk --debug`) then retry.

### 3c. Android OAuth client in Google Cloud

1. Credentials → **Create credentials → OAuth client ID**.
2. Type: **Android**.
3. Package name: `com.femm.femm_app`.
4. SHA-1: paste debug fingerprint.
5. Create. You usually do **not** put this Android client’s ID into Supabase’s Google provider fields — Supabase wants the **Web** client ID/secret (Step 2). The Android client exists so Play Services will issue a token for your package.

### 3d. What Flutter needs at runtime

After cutover, mobile typically needs:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- Web **Client ID** (same as Supabase Google provider) for requesting an ID token — often passed as `--dart-define=GOOGLE_SERVER_CLIENT_ID=...` or equivalent env used by `google_sign_in`

Exact dart-defines land in the Phase 0.5 PR/commit on `main`; this doc locks the **values you must create**, not the final Dart API surface.

---

## Step 4 — Postgres baseline (users profile)

Phase 0.5 only needs a minimal profile so sign-in proves Auth + DB. Seed clinics come in Phase 1.

### 4a. SQL Editor

Supabase → **SQL → New query**. Paste and run the checked-in migration  
`supabase/migrations/20261031140000_profiles_and_lab_pdfs.sql`  
(or the equivalent below):

```sql
-- Minimal profile; extend in later phases
create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  email text,
  display_name text,
  role text not null default 'user' check (role in ('user', 'practitioner')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

create policy "profiles_select_own"
  on public.profiles for select
  using (auth.uid() = id);

create policy "profiles_insert_own"
  on public.profiles for insert
  with check (auth.uid() = id);

create policy "profiles_update_own"
  on public.profiles for update
  using (auth.uid() = id);
```

Optional: a trigger on `auth.users` insert to auto-create `profiles` — nice-to-have; app-side upsert is fine for the prototype.

### 4b. Confirm

**Table Editor → `profiles`**: table exists, RLS on. Do not turn RLS off for convenience.

---

## Step 5 — Storage bucket for lab PDFs

### 5a. Create bucket

1. Supabase → **Storage → New bucket**.
2. Name: `lab-pdfs` (match app code later).
3. **Public bucket:** **off** (private). Path C downloads go through signed URLs or auth’d download.
4. Create.

### 5b. Starter policies (tighten in Phase 5)

In Storage policies (or SQL), allow authenticated users to upload/read objects under a prefix owned by their uid, e.g. `{uid}/...`. Example shape:

```sql
-- Adjust names if the dashboard UI created policies already
create policy "lab_pdfs_insert_own"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'lab-pdfs'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "lab_pdfs_select_own"
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'lab-pdfs'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
```

Practitioner read-by-booking comes in Phase 5 — do not leave the bucket world-readable.

### 5c. Free tier

Stay within Free Storage quotas for prototype PDFs (synthetic panels are small). No Blaze equivalent required.

---

## Step 6 — Flutter mobile env / config

After code cutover (Phase 0.5.5), the app should read Supabase URL + anon key (and Google Web client ID for native sign-in). Typical patterns:

**Option A — dart-defines (no secrets in git):**

```bash
cd apps/mobile
flutter pub get
flutter run \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT_REF.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJhbGciOi... \
  --dart-define=GOOGLE_SERVER_CLIENT_ID=123456789012-xxxx.apps.googleusercontent.com
```

**Option B — local env file** gitignored (e.g. `.env` / `--dart-define-from-file`) if the repo adopts that — still never commit the anon key if you treat the project as sensitive; anon is public-by-design but RLS must be correct.

Remove Firebase:

- Drop `firebase_options.dart` / `google-services.json` as the live path (or leave inert until deleted in 0.5.7).
- Remove FlutterFire / Firebase Auth / Firestore / Storage dependencies from `pubspec.yaml` as part of cutover.

Expected after sign-in: Supabase Auth user exists; `profiles` row for that `id`.

---

## Step 7 — Portal `.env.local`

### 7a. Create the file

```bash
cd apps/portal
cp .env.example .env.local
```

If `.env.example` still lists `VITE_FIREBASE_*`, replace those names when cutting over (Phase 0.5.6). Target shape:

```env
VITE_SUPABASE_URL=https://YOUR_PROJECT_REF.supabase.co
VITE_SUPABASE_ANON_KEY=eyJhbGciOi...
```

Vite only exposes `VITE_`-prefixed vars. Restart `npm run dev` after edits.

### 7b. Run portal

```bash
cd apps/portal
npm install
npm run dev
```

Open `http://localhost:5173`. Google button should use Supabase `signInWithOAuth({ provider: 'google', ... })` (or the pattern chosen in cutover). Auth users appear under Supabase **Authentication → Users**.

---

## Step 8 — Edge Functions note (Phase 2, not required for 0.5 exit)

PDF lab-table extract will be a **Supabase Edge Function** on the free tier (Phase 2). For Phase 0.5 you only need Auth + Postgres + Storage wired. When you get there:

- Deploy with Supabase CLI (`supabase functions deploy ...`).
- Use **service role** only inside the function secret store — never in the client.
- Keep extract deterministic against the Phase 1 golden fixture.

---

## Step 9 — Decommission Firebase (repo hygiene)

Once mobile + portal talk only to Supabase:

1. Remove Firebase SDK usage and emulator docs from README (point here instead).
2. Stop using `.firebaserc` / Firebase Console for day-to-day Auth/DB/Storage.
3. You may delete the old Firebase project later; not urgent if nothing billable is enabled — do **not** upgrade it to Blaze “just in case.”
4. Push cutover to `main` (no PR).

---

## Checklist

- [ ] Supabase project created on **Free**; region noted
- [ ] Project URL + **anon** key copied (service_role kept secret)
- [ ] Google OAuth consent screen + test users
- [ ] Google **Web** client: Client ID + secret in Supabase Auth → Google
- [ ] Redirect URI `https://YOUR_PROJECT_REF.supabase.co/auth/v1/callback` authorized in Google Cloud
- [ ] Supabase Site URL + redirect allow list include `http://localhost:5173`
- [ ] Android OAuth client: `com.femm.femm_app` + debug SHA-1
- [ ] `profiles` table + RLS policies applied
- [ ] Private `lab-pdfs` bucket + own-uid policies
- [ ] Flutter runs with Supabase URL/anon key + Web client ID; Google sign-in upserts profile
- [ ] Portal `.env.local` has `VITE_SUPABASE_URL` + `VITE_SUPABASE_ANON_KEY`; Google sign-in works
- [ ] No Firebase client calls remain for Auth/DB/Storage
- [ ] Cutover pushed to `main` (no PR)

---

## Related

- Stack + Phase 0.5: build-plan (project docs)
- Product locks: prototype-lock (project docs)
