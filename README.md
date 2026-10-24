# Asanova — yoga, breathwork and meditation (Flutter)

Asanova is a guided yoga app for Android and iOS: day-by-day courses, single classes,
filmed pose demonstrations with spoken cues, breathwork and guided meditation.
Package / bundle id: `com.asanova.yoga`.

## Build

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --release        # build/app/outputs/flutter-apk/app-release.apk
flutter build appbundle --release  # Play Store bundle
```

## CI

| Workflow | What it does |
| --- | --- |
| `.github/workflows/build.yml` | Debug APK on every push to `main` (artifact `asanova-debug-apk`). |
| `.github/workflows/release.yml` | Manual. Signed AAB → Play internal track (draft by default) and IPA → TestFlight from the same commit. Version name comes from `pubspec.yaml`; the build number is the `build_number` input or the run number. |
| `.github/workflows/sync-source.yml` | Applies a source snapshot uploaded by the Asanova build workspace as a normal commit. |

Release secrets (GitHub → Settings → Secrets and variables → Actions):

- Android: `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`,
  `ANDROID_STORE_PASSWORD`, `PLAY_SERVICE_ACCOUNT_JSON`
- iOS: `IOS_DEV_P12_BASE64`, `IOS_DEV_P12_PASSWORD`, `ASC_KEY_ID`, `ASC_ISSUER_ID`,
  `ASC_PRIVATE_KEY`

Signing material never goes in Git (`.gitignore` blocks keystores, certificates and
`android/key.properties`). Locally, release signing reads `android/key.properties`:

```
storeFile=/absolute/path/to/upload.jks
storePassword=…
keyAlias=…
keyPassword=…
```

Without it, release builds fall back to the debug key (installable, not uploadable).

## Privacy pages

`docs/` holds the privacy policy and terms served by GitHub Pages for both store
listings. They are generated together with the in-app copy, so edit the source text in
the Asanova workspace rather than the HTML here.

## Structure

| Path | What |
| --- | --- |
| `lib/theme/` | Design tokens (colors, gradients, shadows, type) |
| `lib/data/` | Content models + loader for `assets/data/content.json` |
| `lib/logic/` | Business rules and the coach voice script |
| `lib/state/app_state.dart` | Persisted on-device state |
| `lib/services/` | Audio/voice, reminders, purchases, store links |
| `lib/widgets/` | Shared UI (buttons, rings, sheets, tab bar, ruler, breath orb…) |
| `lib/screens/` | One file per screen |
| `assets/` | Generated content, images, films, audio and voice clips |
