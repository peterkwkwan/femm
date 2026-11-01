# Phase 2 — PDF upload, extract, confirm

Happy path: authenticated user uploads a lab PDF → Edge Function extracts biomarker rows → Flutter confirm/edit → rows persisted as confirmed.

**Prerequisite:** Phase 0.5 (Auth + `lab-pdfs` bucket) and Phase 1 (synthetic PDF + golden fixture) applied on your Free project.

## What landed in git

| Piece | Location |
| --- | --- |
| Schema | `supabase/migrations/20261101140000_phase2_lab_documents.sql` — `lab_documents`, `lab_biomarker_rows` + RLS |
| Edge Function | `supabase/functions/extract-lab-pdf/` — callable; downloads from Storage; pure PDF text extract (no paid OCR) |
| Fixture test | `npm run test:extract-fixture` (Deno) vs `fixtures/labs/synthetic-hk-womens-panel.*` |
| Flutter UI | Path A: upload / demo PDF → extract → edit/delete rows → **Confirm labs** |
| Flags | H/L shown only when present on the PDF / left in the row — UI never invents meaning |

## 1. Apply the Phase 2 migration

Supabase Dashboard → **SQL → New query** → paste  
`supabase/migrations/20261101140000_phase2_lab_documents.sql` → **Run**.

Confirm tables exist under **Table Editor**: `lab_documents`, `lab_biomarker_rows` (RLS on).

## 2. Deploy the Edge Function

Install the [Supabase CLI](https://supabase.com/docs/guides/cli) if needed, then from the repo root:

```bash
# One-time: link this repo to your Free project
npx supabase login
npx supabase link --project-ref YOUR_PROJECT_REF

# Deploy (JWT verification on — Flutter sends the user session)
npx supabase functions deploy extract-lab-pdf
```

Free-tier Edge Functions are enough for the synthetic panel. No third-party OCR keys.

Optional local serve (Docker required):

```bash
npx supabase functions serve extract-lab-pdf --env-file apps/portal/.env.local
```

(`SUPABASE_URL` / `SUPABASE_ANON_KEY` are injected automatically when deployed on Supabase.)

## 3. Offline golden-fixture test (no project needed)

```bash
# Deno: https://deno.land
npm run test:extract-fixture
```

Expect: `OK — extract matches golden fixture within tolerance`.

## 4. Smoke-test on your project

1. Sign into the Flutter app with Google (same dart-defines as Phase 0.5).
2. On the home shell tap **Upload lab PDF** (or **Use synthetic demo PDF** to skip the file picker).
3. Confirm extract returns ~18 rows (FSH flagged H, Vitamin D L, HbA1c/lipids H, etc.).
4. Edit or delete an ambiguous row → **Confirm labs**.
5. In Dashboard → **Table Editor**:
   - `lab_documents.status` = `confirmed`
   - `lab_biomarker_rows` match what you confirmed (`is_deleted` for removed rows)
6. **Storage → lab-pdfs → `{your-uid}/...pdf`** object present.

Callable shape (for curl debugging with a user access token):

```bash
curl -sS -X POST \
  "https://YOUR_PROJECT_REF.supabase.co/functions/v1/extract-lab-pdf" \
  -H "Authorization: Bearer USER_ACCESS_TOKEN" \
  -H "apikey: YOUR_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{"document_id":"DOCUMENT_UUID"}'
```

## Flag rule (locked)

Show **H** / **L** only when the extract (or user edit) supplies them. Do not colour-code or invent clinical meaning when `flag` is null — even if a ref range exists.

## Not in Phase 2

Spend/symptoms (Phase 3), match/hold (Phase 4), practitioner pack (Phase 5).
