# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Streamr** — a live streaming social platform combining Douyin (short vertical video feed) and Bilibili (live streaming with danmaku bullet comments). Two apps share a single Firebase backend.

## Directory Layout

```
qaramia-v2/
  flutter_app/      # Mobile app (iOS + Android)
  web_app/          # Next.js 14 creator studio + viewer (TypeScript)
  functions/        # Firebase Cloud Functions (Node.js 20)
  firestore.rules   # Firestore security rules
  database.rules.json # Realtime Database rules (danmaku)
  firebase.json     # Firebase project config
```

## Development Commands

### Flutter (mobile)
```bash
cd flutter_app
flutter pub get                          # Install dependencies
flutter run                              # Run on device/emulator
flutter build apk                        # Android APK
flutter analyze                          # Lint/type-check
flutter test                             # Run tests
dart run build_runner build              # Regenerate Riverpod code
```

### Next.js (web)
```bash
cd web_app
npm install                              # Install dependencies
npm run dev                              # Dev server (localhost:3000)
npm run build && npm run start           # Production build
npm run lint                             # ESLint
```

### Firebase backend
```bash
firebase deploy --only firestore:rules   # Deploy Firestore rules
firebase deploy --only database          # Deploy Realtime DB rules
firebase deploy --only functions         # Deploy Cloud Functions
cd functions && npm install              # Install function deps

# Set secrets (never commit these)
firebase functions:secrets:set AGORA_APP_ID
firebase functions:secrets:set AGORA_APP_CERTIFICATE
```

## Architecture

### Data Flow
```
User speaks/records → Flutter FeedScreen or web VideoGrid
User goes live → GoLiveScreen (Flutter) or Studio page (web)
              → Agora.io RTC (video/audio transport)
              → Firestore streams/{id} (metadata, viewer count)
              → Firebase RTDB danmaku/{streamId} (bullet comments)
Viewer joins → LiveViewerScreen (Flutter) or /live/[id] (web)
            → Agora subscriber role
            → RTDB onChildAdded listener for danmaku
```

### Firebase Collections (Firestore)
| Collection | Purpose |
|---|---|
| `users/{uid}` | Profile, follower/following counts |
| `users/{uid}/following/{targetUid}` | Follow graph |
| `users/{uid}/followers/{uid}` | Reverse follow graph |
| `videos/{id}` | Short video metadata |
| `videos/{id}/likes/{uid}` | Like tracking |
| `streams/{id}` | Live stream metadata + viewer/gift counts |
| `streams/{id}/gifts/{id}` | Gift events for a stream |

### Firebase Realtime Database
| Path | Purpose |
|---|---|
| `danmaku/{streamId}/{messageId}` | Bullet comments (high-frequency writes) |

Danmaku lives in RTDB (not Firestore) because RTDB handles high-frequency small writes more efficiently. Firestore is used for everything else.

### Live Streaming (Agora)
- **Flutter**: `agora_rtc_engine` package
- **Web**: `agora-rtc-sdk-ng` npm package
- Host joins channel as `ClientRoleBroadcaster` / `host`
- Viewers join as `ClientRoleAudience` / `audience`
- Channel ID = Firestore stream document ID
- Token generation: `getAgoraToken` Cloud Function (set `AGORA_APP_CERTIFICATE` secret for production; empty string = dev mode, no auth)

### State Management
- **Flutter**: Riverpod — all providers in `lib/providers/providers.dart`
- **Web**: Zustand (`store/auth-store.ts`) + local `useState` hooks

## Key Conventions

- Swipe left to delete in Flutter list views (`Dismissible` widget)
- Danmaku messages are stored as `sentAt: millisecondsSinceEpoch` (int) in RTDB — not a Firestore Timestamp
- `firebase_options.dart` is auto-generated — re-run `flutterfire configure` to regenerate
- API keys never committed — Agora keys in Firebase Secrets; Firebase config in `firebase_options.dart` and `.env.local`
- `agoraChannel` field on a stream document equals the Firestore document ID
- Gift coin values are client-side only (no real payment); replace with Stripe for production monetization

## Environment Setup

### Flutter
1. `dart pub global activate flutterfire_cli`
2. Create Firebase project at console.firebase.google.com
3. `flutterfire configure` → generates `lib/firebase_options.dart`
4. Enable Auth: Email/Password + Google
5. Create Firestore DB (production mode) + Realtime Database
6. `firebase deploy --only firestore:rules`
7. `firebase deploy --only database`
8. Get Agora App ID at console.agora.io → add to `--dart-define=AGORA_APP_ID=xxx` or your IDE run config
9. `flutter pub get && flutter run`

### Next.js
1. Copy `.env.local.example` → `.env.local` and fill in Firebase + Agora keys
2. `npm install && npm run dev`

### Firebase Functions
1. `cd functions && npm install`
2. `firebase functions:secrets:set AGORA_APP_ID`
3. `firebase functions:secrets:set AGORA_APP_CERTIFICATE` (optional; empty = dev mode)
4. `firebase deploy --only functions`
