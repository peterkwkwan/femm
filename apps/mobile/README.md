# femm mobile (Flutter / Android)

User client for the femm prototype. Auth is **Supabase** (Google via ID token). See the [repo root README](../../README.md) for project setup and dart-defines.

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
