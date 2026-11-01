# Phase 4 — Rule-based match, 15-min hold, upsell

After spend + symptoms, the user opens the match screen: one clinical specialty (deterministic rules + canned why-copy), a **15-minute auto-hold** on a Phase 1 seed slot, and same-bucket upsell partners. Clinical and upsell book **independently**. Sticky “not a diagnosis” disclaimer stays on the match screen.

**Prerequisite:** Phase 1 seed loaded, Phase 3 migration applied.

## What landed in git

| Piece | Location |
| --- | --- |
| Schema + RPCs | `supabase/migrations/20261101180000_phase4_match_hold_upsell.sql` — `path_a_matches`, `clinical_bookings`, `upsell_bookings`; `hold_slot_for_match`, `confirm_clinical_booking`, `book_upsell_partner`, `release_expired_slot_holds` |
| Match engine | `apps/mobile/lib/services/match_engine.dart` — symptom chips (+ optional H/L labs) → specialty + why-copy; no LLM |
| Match service | `apps/mobile/lib/services/match_service.dart` |
| Match UI | `apps/mobile/lib/screens/match_screen.dart` — clinical primary, upsell secondary, countdown, sticky disclaimer |
| Gate | `apps/mobile/lib/screens/match_gate_screen.dart` — **Start match** when ready |
| Unit tests | `apps/mobile/test/match_engine_test.dart` |

Hold TTL: `expires_at = now() + 15 minutes` on `appointment_slots.held_until` + `path_a_matches.hold_expires_at`.

## 1. Apply the Phase 4 migration

Supabase Dashboard → **SQL → New query** → paste  
`supabase/migrations/20261101180000_phase4_match_hold_upsell.sql` → **Run**.

Confirm under **Table Editor**: `path_a_matches`, `clinical_bookings`, `upsell_bookings` (RLS on).  
Confirm under **Database → Functions**: the four RPCs above.

If slots were exhausted in earlier demos, re-run Phase 1 seed: `supabase/seed/phase1_demo_supply.sql` (see [`phase1-demo-seed.md`](./phase1-demo-seed.md)).

## 2. Smoke steps (Android)

1. Sign into Flutter with Google (same dart-defines as Phase 0.5).
2. Path A: upload/confirm labs → spend (≥1 bucket) → symptoms (≥1 chip) → **Start match**.
3. Match screen shows:
   - Clinical specialty + clinic + **Why this match** canned copy
   - Recommended slot with **Hold expires in MM:SS** (~15:00)
   - Upsell partners **only** for selected spend buckets
   - Sticky disclaimer at the bottom
4. **Confirm clinical booking** → clinical saved; upsell still bookable/skippable.
5. On another path (or before clinical confirm): **Book** / **Skip** partners independently; session stays valid if clinical is never confirmed.
6. Optional: wait for hold to expire (or set `held_until` past in SQL) → UI shows expired → **Hold another slot**.
7. Table Editor checks:
   - `path_a_matches` row with specialty / why_copy / hold fields
   - `appointment_slots.status` = `held` then `booked` after confirm
   - `clinical_bookings` and/or `upsell_bookings` as chosen

## Match rules (summary)

- Selected symptom chips carry specialty weights (e.g. sleep/mood chips → sleep_mood; cycle/bleeding → gynae; bone/heart chip → bone_heart_risk; hot flushes / night sweats → menopause-aware GP).
- Optional flagged labs (H/L only when present): name hints for lipids/bone/glucose → bone/heart; FSH/LH/estradiol/TSH → gynae/endocrine.
- Tie-break: highest score, then specialty enum order.
- Why-copy is canned from specialty lead-in + top symptom/lab reasons + “not a diagnosis”.
- A derived `primary_goal` answer is stored for Path C from the winning specialty.

## Hold edge cases (hardened in Phase 6)

Expire/release, double-confirm, and leave-and-return behaviors: [`phase6-demo-handoff.md`](./phase6-demo-handoff.md) §6.2.

## Not in Phase 4

Path C practitioner summary pack (Phase 5); Path B; real partners; LLM matching.
