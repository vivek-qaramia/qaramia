# Bundle ID rebrand runbook — `com.streamr.streamr` → `com.qaramia.app`

Code-level changes are committed. Three external surfaces require manual setup before the app will build and Firebase will accept requests under the new identifier.

---

## Step 1 — Register the new Android app in Firebase Console

The committed `flutter_app/android/app/google-services.json` has the new `package_name` value but **the API keys / project numbers inside it still point at the old Firebase Android app registration**. The file must be re-downloaded after registering the new app.

1. Go to https://console.firebase.google.com → your Qaramia project
2. Project settings → **Your apps** → **Add app** → Android
3. **Android package name:** `com.qaramia.app`
4. **App nickname:** `Qaramia Android`
5. (Optional) Add SHA-1 fingerprint for Google Sign-In:
   ```powershell
   cd E:\claude\qaramia-v2\flutter_app
   .\android\gradlew signingReport
   ```
6. **Download `google-services.json`**
7. Replace `flutter_app/android/app/google-services.json` with the new file
8. Optionally **delete the old Android app** (`com.streamr.streamr`) from Firebase Console once the new one is verified working

---

## Step 2 — Register the new iOS app in Firebase Console

Same Firebase project, separate app entry for iOS.

1. Project settings → **Your apps** → **Add app** → iOS
2. **iOS bundle ID:** `com.qaramia.app`
3. **App nickname:** `Qaramia iOS`
4. **Download `GoogleService-Info.plist`**
5. Open `flutter_app/ios/Runner.xcworkspace` in Xcode
6. Drag the new `GoogleService-Info.plist` into the `Runner` folder, replacing the existing one (check "Copy items if needed", target: `Runner`)
7. Delete the old iOS app from Firebase Console after verifying

---

## Step 3 — Regenerate `firebase_options.dart`

The auto-generated `lib/firebase_options.dart` references both Android and iOS Firebase app IDs (the `appId`, `apiKey`, etc. — not just the bundle IDs we fixed in the rebrand). After both apps are registered, regenerate:

```powershell
cd E:\claude\qaramia-v2\flutter_app
dart pub global activate flutterfire_cli   # if not already installed
flutterfire configure
```

Pick the same Firebase project. Confirm `com.qaramia.app` for both platforms. The CLI overwrites `lib/firebase_options.dart` with fresh values.

---

## Step 4 — App Store Connect (when you're ready to ship to TestFlight)

The IAP product IDs in this commit (`com.qaramia.app.coins.{packId}`) follow the new bundle ID. App Store Connect requires:

1. Apple Developer Portal → **Identifiers** → **App IDs** → register `com.qaramia.app` as an Explicit App ID
2. App Store Connect → **Apps** → **+** → create new app with Bundle ID `com.qaramia.app`
3. Under the new app: **Features → In-App Purchases** → register all five Consumables with these exact IDs:
   - `com.qaramia.app.coins.starter` ($0.99)
   - `com.qaramia.app.coins.casual` ($4.99)
   - `com.qaramia.app.coins.regular` ($9.99)
   - `com.qaramia.app.coins.power` ($24.99)
   - `com.qaramia.app.coins.whale` ($99.99)
4. Generate a fresh App-Specific Shared Secret → use as `APPLE_IAP_SHARED_SECRET` Firebase secret
5. Enrol in the **Apple Small Business Program** before Jan 1 for the 15% fee tier in the following calendar year

---

## Step 5 — Google Play Console (when ready for closed testing)

1. Play Console → **Create app** → set Application ID `com.qaramia.app`
2. **Monetization → Products → In-app products** → register the same five Consumables with the IDs above
3. **Setup → API access** → link a new GCP service account with `androidpublisher` scope → encode service-account JSON as base64 → set as `GOOGLE_PLAY_SERVICE_ACCOUNT` Firebase secret
4. Build a signed release bundle:
   ```powershell
   cd E:\claude\qaramia-v2\flutter_app
   flutter build appbundle --release --dart-define=AGORA_APP_ID=... --dart-define=API_BASE_URL=https://qaramia.com
   ```

---

## Step 6 — Verify the rebrand build

```powershell
cd E:\claude\qaramia-v2\flutter_app
flutter clean
flutter pub get
flutter analyze                                  # should be clean
flutter build apk --debug                        # Android sanity build
# iOS: open ios/Runner.xcworkspace in Xcode, Product → Build
```

If `flutter build apk` complains that `com.qaramia.app` doesn't match the Firebase app: you skipped Step 1, or the new `google-services.json` wasn't replaced.

---

## Surfaces touched in this commit (auto)

| Surface | Old | New |
|---|---|---|
| Android `applicationId` (build.gradle.kts) | com.streamr.streamr | com.qaramia.app |
| Android `namespace` (build.gradle.kts) | com.streamr.streamr | com.qaramia.app |
| Kotlin package directory | `kotlin/com/streamr/streamr/` | `kotlin/com/qaramia/app/` |
| `MainActivity.kt` package | com.streamr.streamr | com.qaramia.app |
| iOS `PRODUCT_BUNDLE_IDENTIFIER` (6 entries in project.pbxproj) | com.streamr.streamr / `.RunnerTests` | com.qaramia.app / `.RunnerTests` |
| macOS `PRODUCT_BUNDLE_IDENTIFIER` (4 entries) | com.streamr.streamr | com.qaramia.app |
| Linux `APPLICATION_ID` (CMakeLists.txt) | com.streamr.streamr | com.qaramia.app |
| `firebase_options.dart` `iosBundleId` x2 | com.streamr.streamr | com.qaramia.app |
| `google-services.json` `package_name` | com.streamr.streamr | com.qaramia.app |
| Flutter `CoinPack.catalog` (5 packs × 2 platforms) | `com.streamr.streamr.coins.*` | `com.qaramia.app.coins.*` |
| Flutter `IapService._androidPackageName` | com.streamr.streamr | com.qaramia.app |
| Cloud Function `COIN_PACKS` map keys (5 packs) | `com.streamr.streamr.coins.*` | `com.qaramia.app.coins.*` |

## Surfaces NOT touched (intentional)

- **Dart package name** (`pubspec.yaml: name: streamr`) — internal Dart identifier only. Changing it cascades to every `package:streamr/...` import. Kept as-is unless you want a separate rename pass.
- **`test/widget_test.dart`** uses `package:streamr/...` — stays valid because the Dart package name didn't change.
