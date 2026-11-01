# Phase 5 — Path C summary pack + practitioner portal

After a clinical (or upsell) booking, a **summary pack** is snapshotted. The thin web portal lets the **booked clinic practitioner** open upcoming appointments, scan the pack, expand full labs, and download the original PDF. Sticky not-a-diagnosis line on every pack.

**Prerequisite:** Phases 1–4 migrations + Phase 1 seed applied.

## What landed in git

| Piece | Location |
| --- | --- |
| Schema + RLS + RPCs | `supabase/migrations/20261101200000_phase5_path_c_summary_packs.sql` — `summary_packs`, `profiles.clinic_id`, `claim_demo_clinic`, pack generation inside `confirm_clinical_booking` / `book_upsell_partner`, Storage select for booked practitioners |
| Portal UI | `apps/portal` — Google Auth → claim demo clinic → upcoming appointments → summary → expand labs → PDF download |
| Seed safety | `supabase/seed/phase1_demo_supply.sql` clears bookings/packs before wiping clinics |

Pack fields (clinical): goals, spend, match reason, flagged labs only (scannable), full labs snapshot (expand), path tag `Path A`, disclaimer, original PDF path. Upsell packs are lighter (no full labs table).

## 1. Apply the Phase 5 migration

Supabase Dashboard → **SQL → New query** → paste  
`supabase/migrations/20261101200000_phase5_path_c_summary_packs.sql` → **Run**.

Confirm:

- Table Editor: `summary_packs`; `profiles.clinic_id` column
- Database → Functions: `claim_demo_clinic` (+ updated confirm/upsell RPCs)

## 2. Smoke steps (Peter)

### A. User Path A → clinical book (Flutter)

1. Sign into Flutter with a **user** Google account (dart-defines as Phase 0.5).
2. Upload/confirm synthetic PDF → spend → survey → **Start match**.
3. **Confirm clinical booking**.
4. Table Editor: `clinical_bookings` row + matching `summary_packs` row (`kind = clinical`, `path_tag = Path A`, disclaimer set, `flagged_labs` / `labs` populated).

Note which **clinic** was booked (specialty / clinic name).

### B. Practitioner Path C (portal)

1. `cd apps/portal && cp .env.example .env.local` (fill `VITE_SUPABASE_*`) → `npm run dev` → `http://localhost:5173`.
2. Sign in with a **different** Google account (practitioner). Prefer a separate test user so mobile `role: user` is not overwritten.
3. **Claim a demo clinic** — pick the same fictional clinic that received the booking.
4. **Upcoming appointments** lists that booking (slot time + patient snapshot).
5. **Open summary** → see goals, spend, why-match, flagged labs, path tag, disclaimer.
6. **Expand** full labs table.
7. **Download original PDF** (Storage RLS allows booked practitioner only).

### C. Access control checks

1. Sign out → sign in as another Google account → claim a **different** clinic → that booking must **not** appear.
2. Without claiming the booked clinic, pack fetch / PDF download must fail (RLS).

## Not in Phase 5

Path B, real partners, EHR write-back, partner-facing upsell portal UI (upsell packs are generated but the thin portal is clinical-clinic scoped).
