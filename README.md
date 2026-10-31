# femm

Hong Kong menopause **care-navigation** prototype (not a diagnosis).  
Stack lock: **Flutter Android** user client · **thin web** practitioner portal · **Firebase** Auth / Firestore / Storage · **Google Auth** for users and practitioners.

Phase 0 ships empty shells you can sign into. Later phases add Path A → Path C.

## Repo layout

| Path | Role |
| --- | --- |
| `apps/mobile` | Flutter Android user app |
| `apps/portal` | Vite + TypeScript practitioner portal stub |
| `firebase/` | Firestore + Storage security rules |
| `firebase.json` | Emulators + Hosting (portal `dist`) |

## Prerequisites

- Flutter 3.35+ (stable), Android SDK / emulator or device
- Node 22+ (24 recommended) for the portal and Firebase emulators
- A Firebase project with **Google** sign-in enabled (Auth), plus Firestore and Storage
- Android OAuth client (package `com.femm.femm_app`) and a **Web** OAuth client (used as `serverClientId` / portal)

## One-time Firebase setup (Peter)

Live Google OAuth / Firebase credentials are **not** in this repo. Placeholders compile; Auth against production needs your project.

1. Create a Firebase project (suggested id kept as `femm-prototype-REPLACE` until you rename).
2. Enable **Authentication → Google**, **Cloud Firestore**, **Storage**.
3. Register an **Android** app with package name `com.femm.femm_app`. Add your debug SHA-1.
4. Register a **Web** app for the practitioner portal.
5. From `apps/mobile`, run FlutterFire (or paste console values):

   ```bash
   dart pub global activate flutterfire_cli
   flutterfire configure --project=YOUR_PROJECT_ID
   ```

   That overwrites `lib/firebase_options.dart` and `android/app/google-services.json`.  
   Keep a copy of the example at `android/app/google-services.json.example` if you need a template again.

6. Portal env: copy `apps/portal/.env.example` → `apps/portal/.env.local` and fill the `VITE_FIREBASE_*` values from the Web app config.
7. Update `.firebaserc` `default` project id.
8. For Android Google → Firebase ID tokens, pass the **Web client ID**:

   ```bash
   flutter run --dart-define=GOOGLE_SERVER_CLIENT_ID=YOUR_WEB_CLIENT_ID.apps.googleusercontent.com
   ```

9. Authorized domains / OAuth redirect URIs: add `localhost` for portal dev.

**Do not commit** service-account JSON, `.env.local`, or production keystores. Client `google-services.json` / `firebase_options.dart` are public-ish app configs; still prefer replacing placeholders locally or via FlutterFire rather than pasting unrestricted keys into PRs when avoidable.

## Run — Firebase emulators

From repo root (after `npm install`):

```bash
npm run emulators
```

- Auth `9099` · Firestore `8080` · Storage `9199` · Emulator UI `4000`

Emulator mode unlocks an **anonymous smoke sign-in** button on both clients so you can verify wiring without Google OAuth client IDs.

## Run — Flutter Android (`apps/mobile`)

```bash
cd apps/mobile
flutter pub get

# Production / real Google Auth (after FlutterFire configure):
flutter run

# Against local emulators (Android emulator host loopback):
flutter run --dart-define=USE_FIREBASE_EMULATOR=true

# Physical device + emulators on your machine: set host to your LAN IP
flutter run --dart-define=USE_FIREBASE_EMULATOR=true --dart-define=FIREBASE_EMULATOR_HOST=192.168.x.x
```

Sign-in writes/merges Firestore `users/{uid}` (`uid`, `email`, `displayName`, `photoURL`, `role: user`, timestamps).

## Run — practitioner portal (`apps/portal`)

```bash
cd apps/portal
npm install
cp .env.example .env.local   # then edit

# Real Firebase:
npm run dev

# Emulators:
# set VITE_USE_FIREBASE_EMULATOR=true in .env.local
npm run dev
```

Or from root: `npm run portal:dev`.

Build / Hosting preview:

```bash
npm run portal:build
# optional: firebase deploy --only hosting  (after project linked)
```

## Phase 0 acceptance

- [x] 0.1 Flutter Android scaffold runnable  
- [x] 0.2 Firebase Auth / Firestore / Storage configs present (placeholders + rules + emulators)  
- [x] 0.3 Google Auth sign-in/out; UID → `users/{uid}`  
- [x] 0.4 Thin web portal stub with Google Auth button  
- [x] 0.5 README; secrets not committed  

## Explicitly not in this build (yet)

Path B, wearables, iOS day-one, real partner inventory, imaging OCR/AI, diagnosis/HRT claims, bilingual UI — see product lock docs outside this repo if present.

## License

UNLICENSED / private prototype.
