# Release Checklist — Sugar Plus

Everything below is what's left after this pass. Items marked **(you)** need
a Mac, a console login, or a business decision I can't make from here.

## 1. Signing & secrets — done, verify before you commit

- `android/app/upload-keystore.jks` and `android/key.properties` were
  generated locally and are gitignored (`android/.gitignore` already covers
  `key.properties`, `*.jks`, `*.keystore`). **Run `git status` before you
  commit and confirm neither file shows up as staged.**
- **(you) Back up `android/key.properties` and `upload-keystore.jks`
  somewhere safe outside this repo** (password manager / secure cloud
  storage). If you lose them, you cannot publish updates to the same Play
  Store listing again — Google's key-reset process exists but is slow and
  requires proof of ownership.
- The keystore password and key password are in `android/key.properties`
  (plaintext, local only, gitignored). Rotate them if this machine is ever
  shared or compromised.

## 2. Package identity — decision already made, one caveat

- `applicationId` stays `com.example.sugar_plus` for now (your call) since
  Firebase project `diabetic-app-k` is already registered under that exact
  name, and the app has never actually shipped so a `com.example.*` id isn't
  a hard blocker. **(you)** If you rename it before your first real Play
  Store upload: add a new Android app in the
  [Firebase console](https://console.firebase.google.com/) under
  `diabetic-app-k` with the new package name, add your release keystore's
  SHA-1 and SHA-256 fingerprints (get them with
  `keytool -list -v -keystore android/app/upload-keystore.jks -alias sugarplus_upload`),
  download the new `google-services.json`, and replace
  `android/app/google-services.json`. Skip this if you're keeping the
  current id.

## 2a. Fastlane (Android) — files ready, **(you)** need to install Ruby/Fastlane

`android/fastlane/Appfile` + `Fastfile` and `android/Gemfile` are set up.
This machine has no Ruby, so I couldn't install or run Fastlane itself —
these files are unverified until you do:

1. Install Ruby (Windows: [RubyInstaller](https://rubyinstaller.org/),
   pick a "with DevKit" version), then from `android/`:
   ```
   cd android
   gem install bundler
   bundle install
   ```
2. Get a Google Play service account JSON key (Play Console → Setup → API
   access → create/link a service account with Release access → create
   key), save it as **`android/fastlane/pc-api-key.json`**. It's gitignored
   (`android/.gitignore` covers `fastlane/*.json`, and the root `.gitignore`
   also covers `pc-api-key.json` wherever it lands) — verify with
   `git status` before committing.
3. Your app needs to exist in Play Console already with at least one manual
   upload before the Play Developer API will accept uploads from Fastlane —
   if you haven't done the very first upload by hand yet, do that first.
4. Lanes (`bundle exec fastlane android <lane>`, from `android/`):
   - `test` — runs Android unit tests
   - `internal` — builds a release AAB and uploads to the Internal Testing
     track
   - `promote_to_production` — promotes the current internal build to
     Production without rebuilding
   - `deploy` — builds and uploads straight to Production (use with care)

## 3. Backend deployment — **(you)**, blocks GlucoScan in production

`sugar_plus_backend/` (sibling folder, own repo) has a `Dockerfile` and
`Procfile` ready for any container/buildpack host (Render, Railway, Fly.io,
a VPS). It's stateless — no database, nothing to migrate.

1. Deploy it, confirm `GET https://<host>/health` → `{"status":"ok"}`.
2. Every release build must pass the real URL:
   ```
   flutter build apk --release --dart-define=GLUCOSCAN_API_BASE_URL=https://<host>
   flutter build appbundle --release --dart-define=GLUCOSCAN_API_BASE_URL=https://<host>
   ```
   Without this flag, the app falls back to `http://10.0.2.2:8000` (the
   Android emulator's localhost alias), which will just fail to connect on a
   real user's phone — GlucoScan will show a "could not reach server" error
   instead of a result. Nothing else in the app breaks.

## 4. iOS — **(you)**, needs a Mac

I scaffolded `ios/` (`flutter create --platforms=ios`) and set:
- Bundle ID: `com.example.sugarPlus`
- Display name: "Sugar Plus"
- `NSCameraUsageDescription` / `NSPhotoLibraryUsageDescription` in Info.plist
- iOS launcher icons generated from `assets/icons/app_icon/sugar+.png`

Still needed, on a Mac with Xcode:
1. `flutter pub get`, open `ios/Runner.xcworkspace` (or `.xcodeproj` — this
   Flutter version uses Swift Package Manager, no CocoaPods `Podfile`) in
   Xcode, set your Team under Signing & Capabilities.
2. Register an iOS app for bundle ID `com.example.sugarPlus` in the
   `diabetic-app-k` Firebase project, download `GoogleService-Info.plist`,
   add it to `ios/Runner/` in Xcode (must be added via Xcode, not just
   copied, so it's included in the build).
3. Google Sign-In on iOS needs a URL scheme from that plist's
   `REVERSED_CLIENT_ID` added to `CFBundleURLTypes` in Info.plist — the
   [google_sign_in iOS setup docs](https://pub.dev/packages/google_sign_in)
   cover the exact snippet.
4. `flutter build ipa --release --dart-define=GLUCOSCAN_API_BASE_URL=https://<host>`,
   then upload via Xcode Organizer or Transporter.
5. If Xcode complains about minimum deployment target for a Firebase pod,
   bump `IPHONEOS_DEPLOYMENT_TARGET` (currently 13.0) in the Runner target.

No Apple Developer account activity (signing, TestFlight, submission) can
happen from this Windows machine — it genuinely requires a Mac or a macOS CI
service (Codemagic, GitHub Actions macOS runner, etc.).

## 5. Store listings — **(you)**

- **Privacy policy**: `PRIVACY_POLICY.md` is drafted — fill in the date and
  contact email, publish it somewhere public (GitHub Pages is free), and
  link it in both Play Console and App Store Connect.
- **Play Console → Data Safety form**: declare collection of email
  (account management), health info / fitness data (blood sugar readings),
  and camera access (processed transiently, not stored — matches the
  privacy policy). Mark data as encrypted in transit, deletable in-app.
- **Play Console → Content rating questionnaire**: answer honestly re:
  health/medical content.
- **App Store Connect → App Privacy**: same categories — Health & Fitness
  data linked to identity, Contact Info (email).
- **Apple health-app scrutiny**: apps that estimate a medical value from a
  photo get extra review scrutiny. Keep the in-app "experimental, not a
  medical device" disclaimers (already present on GlucoScan's capture and
  result screens) intact — don't soften that language in marketing copy or
  screenshots, or expect a rejection.
- Screenshots, feature graphic (Play), app preview text, keywords, support
  URL — none of that exists yet; still to do.
- **In-app account deletion** is now implemented (Profile → Delete Account),
  satisfying Apple Guideline 5.1.1(v) and Play's account-deletion
  requirement.

## 6. Versioning

`pubspec.yaml` is at `1.0.0+1`. Since this has never actually been
published, that's fine as a first submission. For every subsequent release,
bump the build number (`+N`) at minimum; bump the version name for
user-visible changes.

## 7. Before you upload anywhere

- Smoke-test the **release** build on your device, not just debug:
  `flutter install --release` (or `flutter build apk --release` then
  sideload the APK). R8 minification is now on — this is the one build
  variant most likely to hide a runtime issue that debug mode won't show
  (e.g. a reflection-based library missing a keep rule).
- Test GlucoScan end-to-end against your deployed backend, not
  `10.0.2.2`, from an actual device on cellular or a different Wi-Fi network
  than the backend host.
