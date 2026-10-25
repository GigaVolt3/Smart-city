# CivicAI Mobile — Flutter Android App

## Phase 1 Status

✅ Screens implemented with demo data:
- Splash → Onboarding → Login / Register
- Home (stats, quick actions, recent complaints)
- My Complaints (search + filter)
- Complaint Detail (complete timeline)
- Submit Complaint (4-step form)
- Notifications
- Profile (language picker)

⚠️  All data is clearly labelled **DEMO DATA**. Phase 3 connects to the real backend.

## Running the App

### Prerequisites
- Flutter 3.44+ (`flutter --version`)
- Android device connected via USB (or emulator running)
- USB debugging enabled on device

### Steps

```powershell
cd mobile
flutter pub get          # Install dependencies
flutter run              # Run on connected Android device
```

### Useful commands

```powershell
flutter devices          # List connected devices
flutter run -d <id>      # Run on a specific device
flutter analyze          # Static analysis
flutter test             # Run unit tests
```

## Folder Structure

```
lib/
├── main.dart
├── core/
│   ├── theme/app_theme.dart        # Design system
│   ├── router/app_router.dart      # GoRouter + navigation shell
│   └── widgets/                    # Shared UI components
└── features/
    ├── splash/
    ├── onboarding/
    ├── auth/
    ├── home/
    ├── complaints/
    ├── notifications/
    └── profile/
```

## Dependencies

| Package              | Purpose                          |
|----------------------|----------------------------------|
| flutter_riverpod     | State management                 |
| go_router            | Navigation / routing             |
| dio                  | HTTP client (Phase 3)            |
| flutter_secure_storage | JWT token storage (Phase 3)    |
| image_picker         | Camera / gallery (Phase 3)       |
| geolocator           | GPS location (Phase 3)           |
| flutter_map          | OpenStreetMap display (Phase 3)  |
| intl                 | Date/number formatting           |
| shimmer              | Loading skeletons                |

## Fonts

Inter font (400/500/600/700 weights) is declared in `pubspec.yaml`.
**You must download the font files** and place them in `assets/fonts/`:
- `Inter-Regular.ttf`
- `Inter-Medium.ttf`
- `Inter-SemiBold.ttf`
- `Inter-Bold.ttf`

Download from: https://fonts.google.com/specimen/Inter

> Alternatively, remove the font declaration from `pubspec.yaml` and the app
> will fall back to the system default font — it will still work.

## Known Limitations (Phase 1)

- No real backend connection — all data is demo/mock
- Image picker and camera are declared but not wired up
- GPS location picker uses a hardcoded demo coordinate
- Map preview is a placeholder (Phase 3 integrates flutter_map)
- Push notifications are not implemented (Phase 4)
- Authentication does not verify credentials (Phase 3)
