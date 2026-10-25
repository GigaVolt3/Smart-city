# CivicAI — Setup Guide

## Prerequisites

| Tool          | Version   | Install Link                                 |
|---------------|-----------|----------------------------------------------|
| Flutter / Dart | ≥ 3.44   | https://docs.flutter.dev/get-started/install |
| Python        | ≥ 3.11    | https://www.python.org/downloads/            |
| Node.js       | ≥ 20      | https://nodejs.org/                          |
| Git           | any       | https://git-scm.com/                        |
| PostgreSQL    | ≥ 15      | https://www.postgresql.org/download/         |
| Android SDK   | API 33+   | Via Android Studio                           |

## 1. Clone & Bootstrap

```powershell
git clone <your-repo-url>
cd Smart-city
```

## 2. Flutter Mobile App (Phase 1)

```powershell
cd mobile

# Download Inter font files from https://fonts.google.com/specimen/Inter
# Place them in assets/fonts/:
#   Inter-Regular.ttf, Inter-Medium.ttf, Inter-SemiBold.ttf, Inter-Bold.ttf

flutter pub get
flutter run                    # Connected Android device or emulator
```

### Optional: Run on specific device

```powershell
flutter devices                # List available devices
flutter run -d <device-id>
```

## 3. Backend API (Phase 2)

```powershell
cd backend

# Create virtual environment
python -m venv .venv
.\.venv\Scripts\Activate.ps1   # Windows PowerShell

pip install -r requirements.txt

# Copy and fill in environment variables
Copy-Item .env.example .env
notepad .env                   # Edit DB URL, JWT secret, etc.

# Run database migrations
alembic upgrade head

# Seed demo data
python -m scripts.seed_demo

# Start development server
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

API docs available at: http://localhost:8000/docs

## 4. React Dashboard (Phase 7)

```powershell
cd dashboard
npm install
npm run dev                    # http://localhost:5173
```

## 5. Connecting Mobile to Backend

In Phase 3, the backend URL is configured via `mobile/lib/core/constants/api_constants.dart`.

For a device on the same local network:
- Backend runs on `http://<your-laptop-ip>:8000`
- Replace `localhost` with your laptop's LAN IP (e.g. `192.168.1.100`)

## 6. Development Escalation Testing

The escalation engine supports a `DEV_MODE=true` environment variable that:
- Sets deadlines to minutes instead of days
- Enables a dry-run mode (`/admin/escalation/dry-run` endpoint)
- Logs escalation decisions verbosely

See `docs/escalation-testing.md` for detailed test procedures (Phase 4).

## 7. Running Tests

### Flutter
```powershell
cd mobile
flutter test
flutter analyze
```

### Backend
```powershell
cd backend
pytest -v
pytest tests/test_escalation.py -v   # Escalation-specific tests
```

## Troubleshooting

### Flutter pub get fails with socket error
- Check internet connection
- Try: `flutter pub get --no-offline`
- Or set PUB_HOSTED_URL to a mirror if behind a firewall

### Android device not found
- Enable USB debugging on device
- Run `flutter doctor` and follow its suggestions
- `adb devices` to verify ADB sees the device

### Font not rendering
- Ensure font files exist in `mobile/assets/fonts/`
- Or remove the fonts section from `pubspec.yaml` to use system defaults

### PostgreSQL connection refused
- Ensure PostgreSQL service is running
- Check `DATABASE_URL` in `.env`
- Default: `postgresql://civicai:civicai@localhost:5432/civicai_db`
