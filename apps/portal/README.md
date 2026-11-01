# femm practitioner portal

Thin Vite + TypeScript Path C portal with Google Auth via **Supabase**.

After Phase 5: claim a fictional clinic → upcoming clinical appointments → scannable summary pack → expand labs → download original PDF. Access is booking-scoped (auth’d booked practitioner only).

See the [repo root README](../../README.md), [`docs/phase5-path-c-portal.md`](../../docs/phase5-path-c-portal.md), and the Path A → Path C demo script [`docs/phase6-demo-handoff.md`](../../docs/phase6-demo-handoff.md).

```bash
cp .env.example .env.local
# fill VITE_SUPABASE_URL + VITE_SUPABASE_ANON_KEY
npm install
npm run dev
```
