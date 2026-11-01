# Phase 3 — Spend + survey

After labs are confirmed, the user multi-selects spend buckets, answers ≤8 clinical + skin/hair questions, and only then can open the match gate (Phase 4 UI lands later).

**Prerequisite:** Phase 2 migration applied (`lab_documents` confirmed status works).

## What landed in git

| Piece | Location |
| --- | --- |
| Schema | `supabase/migrations/20261101160000_phase3_spend_and_survey.sql` — `path_a_sessions`, `path_a_spend_selections`, `path_a_survey_answers` + RLS |
| Spend UI | `apps/mobile/lib/screens/spend_screen.dart` — six locked buckets, ≥1 required |
| Survey UI | `apps/mobile/lib/screens/survey_screen.dart` — exactly 8 questions |
| Gate | `apps/mobile/lib/screens/match_gate_screen.dart` — match locked until spend + survey complete |
| Service | `apps/mobile/lib/services/intake_service.dart` |

Spend keys reuse Phase 1 `public.spend_bucket` enum (skincare/aesthetics, gym/physio, supplements, wellness/spa, mental health, private GP).

## 1. Apply the Phase 3 migration

Supabase Dashboard → **SQL → New query** → paste  
`supabase/migrations/20261101160000_phase3_spend_and_survey.sql` → **Run**.

Confirm under **Table Editor**: `path_a_sessions`, `path_a_spend_selections`, `path_a_survey_answers` (RLS on).

## 2. Smoke-test on your project

1. Sign into Flutter with Google (same dart-defines as Phase 0.5).
2. **Upload lab PDF** / **Use synthetic demo PDF** → confirm labs.
3. On **Spend categories**, select ≥1 bucket → **Continue**.
4. Answer all **8** survey questions → **Save survey & continue**.
5. **Match** screen shows **Ready for match** → **Start match** opens Phase 4 hold/upsell UI (after Phase 4 SQL is applied).
6. Dashboard → Table Editor:
   - `path_a_sessions.spend_completed_at` and `survey_completed_at` set
   - `path_a_spend_selections` rows for chosen buckets
   - `path_a_survey_answers` = 8 rows
7. From home, with an incomplete session: **Open match gate** stays locked and points you to finish spend/survey. Match cannot start early.

## Survey keys (8)

`primary_goal`, `hot_flushes`, `sleep`, `mood`, `cycle_bleeding`, `bone_heart`, `skin`, `hair`

## Not in Phase 3

Rule-based match, 15-min hold, upsell cards (Phase 4); Path C pack (Phase 5).
