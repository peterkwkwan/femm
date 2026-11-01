# Phase 6 — Demo hardening + handoff

Reliable Android demo of full **Path A → Path C**; hold edge cases defined; disclaimers audited; deferred scope listed. No engineer improvisation required for the happy path.

**Prerequisite:** Phases 0.5–5 migrations applied, Phase 1 seed loaded, `extract-lab-pdf` deployed, Google OAuth wired (see [`supabase-setup.md`](./supabase-setup.md)).

---

## 6.1 End-to-end demo script (<10 min)

Use **two Google accounts**: Account A = Flutter user, Account B = practitioner (claim clinic).

### Prep (once per session, ~1–2 min)

1. Reset demo supply if slots are exhausted:

   ```bash
   # Option A: Supabase SQL Editor → paste supabase/seed/phase1_demo_supply.sql → Run
   # Option B:
   export DATABASE_URL='postgresql://postgres.:YOUR_DB_PASSWORD@db.YOUR_PROJECT_REF.supabase.co:5432/postgres'
   npm run seed:phase1
   ```

2. Confirm migrations through Phase 5 are applied (Table Editor shows `path_a_sessions`, `path_a_matches`, `clinical_bookings`, `summary_packs`).

3. Start portal:

   ```bash
   cd apps/portal && npm install && npm run dev
   # http://localhost:5173
   ```

4. Start Flutter (device or emulator) with real dart-defines:

   ```bash
   cd apps/mobile
   flutter run --dart-define-from-file=dart_defines.json
   ```

### Path A — user (Account A, ~5–6 min)

1. **Sign in** with Google (Account A).
2. **Upload lab PDF** → pick `fixtures/labs/synthetic-hk-womens-panel.pdf` (or the asset copy under `apps/mobile/assets/labs/`).
3. Wait for extract → **confirm labs** (edit optional; keep H/L flags as shown).
4. **Spend** → select ≥1 bucket (demo tip: pick 2–3 so upsell cards appear).
5. **Survey** → answer all 8 questions (primary goal drives specialty).
6. **Open match gate** → **Start match**.
7. Match screen shows:
   - Clinical specialty + clinic + **Why this match**
   - **Hold expires in MM:SS** (~15:00)
   - Same-bucket upsell partners
   - Sticky disclaimer at bottom
8. Optionally **Book** / **Skip** partners (independent of clinical).
9. **Confirm clinical booking**.

### Path C — practitioner (Account B, ~2–3 min)

1. Portal → **Sign in with Google** (Account B).
2. **Claim** the same fictional clinic named on the match screen.
3. **Upcoming appointments** → open the booking.
4. Scan summary: goals, spend, match reason, flagged labs, path tag **Path A**, disclaimer.
5. **Expand** full labs → **Download original PDF**.

**Done** when pack + PDF open without error and Account B on a *different* clinic cannot see the booking.

---

## 6.2 Hold edge cases (defined + tested in client)

| Case | Expected behavior |
| --- | --- |
| **Expire / release** | Countdown → `00:00` calls `release_expired_slot_holds`; slot returns to `available`; UI shows “Hold expired” + **Hold another slot**. |
| **Double-confirm** | Second confirm is a no-op on the client; RPC returns existing `clinical_bookings` row (`already_booked`). |
| **Leave-and-return (app resume)** | Active hold is reused and countdown refreshed. Expired hold does **not** silently take a new slot — user taps **Hold another slot**. |
| **Re-enter match after expire** | **Start match** / **Hold another slot** runs `startOrResumeMatch` → new 15-min hold on next free seed slot. |
| **Clinical vs upsell** | Confirm clinical only, upsell only, both, or neither — session stays valid. |

Unit coverage: `apps/mobile/test/hold_edge_cases_test.dart` (active/expired hold, double-confirm payload, disclaimer strings).

---

## 6.3 Disclaimer audit

| Surface | Copy | Sticky? |
| --- | --- | --- |
| Match screen footer | `FemmDisclaimers.stickyMatch` | Yes |
| Match gate / home Path A blurb | `FemmDisclaimers.oneLiner` | Banner / inline |
| Path C `summary_packs.disclaimer` (DB default + pack gen) | `Care-navigation only — not a diagnosis or medical advice.` | Persisted on every pack |
| Portal claim / appointments / pack views | `PATH_C_DISCLAIMER` (+ pack field) | Yes (`.disclaimer.sticky`) |

Locked rule: sticky on match + Path C summary; one-line on every Path C pack. Counsel review still open before public users (see prototype lock).

---

## 6.4 Android smoke notes

This environment has no Flutter SDK / emulator. Peter (or CI with Android) should smoke once before a live demo:

1. Fresh install: uninstall `com.femm.femm_app` if present → `flutter run --dart-define-from-file=dart_defines.json`.
2. Google Auth succeeds (debug SHA-1 + Android OAuth client).
3. Full happy path from §6.1 on **one** physical device or emulator.
4. Optional hold spot-check: open match → wait for expire (or set `held_until` / `hold_expires_at` past in SQL) → re-hold → confirm.
5. Portal Path C on the same machine while Flutter stays signed in as Account A.

If Auth fails: re-check [`supabase-setup.md`](./supabase-setup.md) (Web client ID as `GOOGLE_SERVER_CLIENT_ID`, Android SHA-1, Supabase Google provider).

---

## 6.5 Deferral checklist (not in this build)

Explicitly **not** shipped — do not demo as if present:

- [ ] Path B (post–health-check / GP-nudge entry)
- [ ] Wearables sync or snapshot
- [ ] iOS day-one client
- [ ] Real partner / clinic inventory (fictional seed only)
- [ ] Imaging OCR / AI / storage of diagnostic images
- [ ] Cancer/CT advice, HRT dosing, diagnosis claims
- [ ] Bilingual UI, EHR write-back, own skincare line
- [ ] Inventing new spend categories (upsell only within selected buckets)
- [ ] Firebase / Blaze billing

Open (non-blocking): redacted real PDF from Andrew; legal disclaimer counsel; real partners when leaving prototype stage.

---

## Acceptance (Phase 6)

- [x] 6.1 E2E demo script written (<10 min Path A → Path C)
- [x] 6.2 Hold expire/release, double-confirm, leave-and-return defined + client hardened
- [x] 6.3 Disclaimer audit (sticky match + Path C; one-line on packs)
- [x] 6.4 Android smoke notes for Peter’s device/emulator
- [x] 6.5 Deferral checklist in this doc + root README
- [ ] Peter: run §6.1 once on Android + portal (outside git)
