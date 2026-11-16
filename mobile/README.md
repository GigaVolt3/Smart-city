# CivicAI Mobile

Citizen and field-officer app for the CivicAI platform. Flutter, Riverpod, real REST
backend — no demo data.

## Requirements

- Flutter 3.41+ / Dart 3.11+
- A running CivicAI API (see `../backend/README.md`)

## Run

```bash
flutter pub get

# Web preview (fastest for review)
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8000/api/v1

# Android emulator: 10.0.2.2 maps to the host machine
flutter run -d emulator-5554

# Physical device on the same network
flutter run --dart-define=API_BASE_URL=http://192.168.1.20:8000/api/v1
```

The base URL resolution order is: a URL saved from the in-app server setting,
then `--dart-define=API_BASE_URL`, then `http://10.0.2.2:8000/api/v1` on Android,
then `http://127.0.0.1:8000/api/v1` elsewhere. The trailing `/api/v1` is optional
in the in-app field — it is added automatically.

## Point the app at your backend without rebuilding

The login screen shows `Server: http://10.0.2.2:8000/api/v1` with a **Change**
link. Enter any reachable host (`192.168.1.20:8000`, `10.0.2.2:8000`, a full
`https://api.example.gov/api/v1`), hit Save, and the app uses it from then on —
the value is persisted in `shared_preferences`. This is how a sideloaded APK
works on a real phone without a custom build.

## Build

```bash
flutter build apk --release --dart-define=API_BASE_URL=https://api.example.gov/api/v1
flutter build web --release --dart-define=API_BASE_URL=https://api.example.gov/api/v1
```

The universal APK lands at `build/app/outputs/flutter-apk/app-release.apk`
(~53 MB; `--split-per-abi` produces ~20 MB arm64 and ~22 MB armeabi-v7a variants).

Signing: if `mobile/android/key.properties` exists, the release build is signed with
the key it points at. `start-civicai.bat` (option 7 or 8) creates that file plus
`mobile/android/keystore/civicai-release.jks` once — both are gitignored. Keeping one
key means a newer APK installs over the previous copy; a rebuild signed with a
*different* key is rejected with `App not installed` until the old app is uninstalled.
Without `key.properties` the build still works, falling back to the debug keystore.

To sign a store build by hand, put your own values in `mobile/android/key.properties`
(`storeFile`, `storePassword`, `keyAlias`, `keyPassword`) — the module reads them
directly, so no Gradle edit is needed.

On a physical phone the backend must be reachable over the network: either set the
address from the login screen's **Change** link (no rebuild), or bake it in at build
time (`10.0.2.2` only works inside the Android emulator):

```bash
flutter build apk --release --dart-define=API_BASE_URL=http://192.168.1.20:8000/api/v1
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

The release manifest declares `android.permission.INTERNET` and
`android:usesCleartextTraffic="true"` (the local FastAPI server is plain HTTP).
Without the permission the release APK silently fails every request with the
"Cannot reach the CivicAI service" message, even though debug builds work — the
debug manifest adds `INTERNET` on its own.

If Gradle fails with `Could not close incremental caches` on Windows, the workaround is
already committed in `android/gradle.properties` (`kotlin.incremental=false`).

## Demo accounts

Password `DemoPass1!` for every seeded account.

| Email | Role | What the app shows |
| --- | --- | --- |
| `citizen@demo.civicai` | Citizen | Own cases, own KPIs, report form |
| `officer@demo.civicai` | Officer | Department queue, assignment, status updates |
| `supervisor@demo.civicai` | Supervisor | Department oversight |
| `admin@demo.civicai` | Administrator | Full municipal dataset |

## Structure

```
lib/
  main.dart                     app bootstrap, theme, auth gate
  data/
    models.dart                 typed API models and parsers
    api_client.dart             auth, complaints, analytics, hotspots,
                                notifications, attachments; token refresh
  core/
    providers.dart              riverpod: auth session, filters, analytics,
                                notifications, unread count, shell tab
    theme/app_theme.dart        shared design tokens and widget themes
    utils/format.dart           dates, relative time, SLA labels, numbers
    widgets/civic_ui.dart       KPI tiles, status pills, section cards,
                                skeletons, empty/error states
  features/
    auth/auth_screen.dart       sign in / register
    shell/app_shell.dart        bottom navigation + report FAB
    home/home_screen.dart       KPIs, status mix, attention queue, activity
    complaints/complaints_screen.dart
    complaints/complaint_detail_screen.dart
    complaints/report_screen.dart
    map/map_screen.dart         flutter_map + hotspot overlay
    notifications/notifications_screen.dart
    profile/profile_screen.dart
```

## Behaviour notes

- Tokens are stored with `shared_preferences`. A 401 triggers a single refresh attempt;
  if that fails the session is cleared and the auth screen appears.
- Every list has loading skeletons, an empty state, and an error state with retry.
- Pull-to-refresh invalidates the matching providers.
- Status updates and complaint creation invalidate complaints, analytics, and unread
  counts together so the home screen never shows stale numbers.
- Evidence photos are picked from camera or gallery (`image_picker`) and uploaded as
  multipart form data; failures surface the server's message.
- The map uses OpenStreetMap tiles plus hotspot circles from `/ai/hotspots`.

## Checks

```bash
flutter analyze     # no issues
flutter test        # auth screen smoke test
flutter build web --release
```

## Known constraints

- Web build has no camera capture (browser file picker only).
- No offline write queue; reads are cached in memory for the session only.
- English only.
