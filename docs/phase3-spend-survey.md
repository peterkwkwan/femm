# Phase 3 — Spend + symptoms

After labs are confirmed, the user multi-selects spend buckets, selects menopause-relevant symptom chips, and only then can open the match gate (Phase 4).

**Prerequisite:** Phase 2 migration applied (`lab_documents` confirmed status works).

## What landed in git

| Piece | Location |
| --- | --- |
| Schema | `supabase/migrations/20261101160000_phase3_spend_and_survey.sql` — `path_a_sessions`, `path_a_spend_selections`, `path_a_survey_answers` + RLS |
| Symptoms storage note | `supabase/migrations/20261102100000_path_a_symptoms_chips.sql` — table comments + Path C `goals.symptoms[]` |
| Spend UI | `apps/mobile/lib/screens/spend_screen.dart` — six locked buckets, ≥1 required; **STEP 1 OF 3 · SPEND** |
| Symptoms UI | `apps/mobile/lib/screens/symptoms_screen.dart` — chip multi-select; **STEP 2 OF 3 · SYMPTOMS** |
| Gate | `apps/mobile/lib/screens/match_gate_screen.dart` — match locked until spend + symptoms complete; **STEP 3 OF 3 · MATCH** |
| Service | `apps/mobile/lib/services/intake_service.dart` |

Spend keys reuse Phase 1 `public.spend_bucket` enum (skincare/aesthetics, gym/physio, supplements, wellness/spa, mental health, private GP).

Symptom chips reuse `path_a_survey_answers`: one row per selected chip (`question_key` = chip key, `answer` = label) plus a derived `primary_goal` row for Path C.

## 1. Apply the Phase 3 (+ symptoms) migrations

Supabase Dashboard → **SQL → New query** → paste in order:

1. `supabase/migrations/20261101160000_phase3_spend_and_survey.sql`
2. `supabase/migrations/20261102100000_path_a_symptoms_chips.sql` (after Phase 5 snapshot exists, or anytime after Phase 3 if Path C not yet applied — function replace is idempotent once Phase 5 is in)

Confirm under **Table Editor**: `path_a_sessions`, `path_a_spend_selections`, `path_a_survey_answers` (RLS on).

## 2. Smoke-test on your project

1. Sign into Flutter with Google (same dart-defines as Phase 0.5).
2. **Upload lab PDF** / **Use synthetic demo PDF** → confirm labs.
3. On **Spend categories**, confirm **STEP 1 OF 3 · SPEND**, select ≥1 bucket → **Continue**.
4. On **Symptoms**, confirm **STEP 2 OF 3 · SYMPTOMS**, heading “What are you dealing with right now?”, tap ≥1 chip → see **N selected** → **Continue**.
5. **Match** gate shows **STEP 3 OF 3 · MATCH** and **Ready for match** when spend + symptoms are saved.
6. Dashboard → Table Editor:
   - `path_a_sessions.spend_completed_at` and `survey_completed_at` set
   - `path_a_spend_selections` rows for chosen buckets
   - `path_a_survey_answers` = one row per selected chip + `primary_goal`
7. From home, with an incomplete session: **Open match gate** stays locked and points you to finish spend/symptoms. Match cannot start early.

## Symptom chip keys

`hot_flushes`, `night_sweats`, `poor_sleep`, `mood`, `brain_fog`, `fatigue`, `cycle_bleeding`, `vaginal_dryness`, `low_libido`, `joint_aches`, `weight_changes`, `skin`, `hair`, `bone_heart`

Plus derived meta key: `primary_goal` (specialty-mapped label for Path C).

## Not in Phase 3

Rule-based match, 15-min hold, upsell cards (Phase 4); Path C pack (Phase 5).
