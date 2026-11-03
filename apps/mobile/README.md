# femm mobile (Flutter / Android)

User client for the femm prototype. Auth is **Supabase** (Google via ID token). Path A: upload lab PDF → extract → confirm → spend → symptoms → match (15-min hold + upsell). See the [repo root README](../../README.md), phase docs under `docs/`, and the final demo script [`docs/phase6-demo-handoff.md`](../../docs/phase6-demo-handoff.md).

```bash
flutter pub get
flutter run \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT_REF.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJ... \
  --dart-define=GOOGLE_SERVER_CLIENT_ID=YOUR_WEB_CLIENT_ID.apps.googleusercontent.com

# Or:
flutter run --dart-define-from-file=dart_defines.json
# (copy dart_defines.example.json → dart_defines.json; gitignored)
```

`GOOGLE_SERVER_CLIENT_ID` must be the Google Cloud **Web** OAuth client ID (same string as Supabase Auth → Google → Client IDs). Enable **Skip nonce check** on that provider. See [`docs/supabase-setup.md`](../../docs/supabase-setup.md) §2c–3e if you hit `Bad ID token`.
