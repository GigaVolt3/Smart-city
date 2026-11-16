# CivicAI

AI-assisted civic grievance and escalation platform for Indian municipalities.

Citizens report civic issues from a mobile app or the web portal. The backend scores
priority, routes the complaint to the right department, tracks an SLA clock, and
escalates unresolved cases up a configurable authority chain. Municipal staff work the
same data from a desktop operations console with maps, analytics, assignment, evidence
review, and an immutable audit trail.

Three deployables share one FastAPI backend and one SQLite/PostgreSQL database:

| App | Path | Stack | Purpose |
| --- | --- | --- | --- |
| Operations console | `dashboard/` | React 19, Vite, TypeScript, TanStack Query, Recharts, Leaflet | Desktop-first staff console |
| Mobile app | `mobile/` | Flutter 3.41, Riverpod, flutter_map, http | Citizen/officer field app (Android + web) |
| API | `backend/` | FastAPI, SQLAlchemy 2, APScheduler, scikit-learn | Auth, complaints, analytics, escalation, audit |

## What actually works

- JWT auth with refresh, four roles (`citizen`, `officer`, `supervisor`, `admin`) and
  role-scoped queries enforced on every read path.
- Complaint intake with AI category suggestion, priority scoring, SLA derivation, and
  sequential tracking numbers (`CIVIC-2026-0001`).
- Status workflow with immutable timeline, officer assignment, and in-app notifications.
- Photo/PDF evidence upload stored on disk and served from `/uploads`.
- SLA breach detection plus a configurable escalation engine (rules per level, rerun on
  demand or via the background worker).
- Analytics overview: KPIs, status/priority mix, 30-day trend, department and ward
  performance, SLA compliance, hotspot coordinates.
- Admin surfaces: departments, categories, users, escalation rules, audit log.
- Mobile app with bottom navigation, touch-sized controls, offline-tolerant list
  caching, camera/gallery evidence capture, and a live hotspot map.

## Quick start

Requirements: Python 3.11+, Node 20+, Flutter 3.41+ (mobile/web only).

```bash
# 1. API
python -m venv .venv
source .venv/bin/activate            # Windows: .venv\Scripts\activate
pip install -r backend/requirements.txt
cp backend/.env.example backend/.env
python -m backend.scripts.seed_demo  # 48 complaints, 10 users, 5 departments
python -m uvicorn backend.main:app --reload --port 8000
# http://127.0.0.1:8000/docs

# 2. Web console
cd dashboard
npm install
npm run dev
# http://127.0.0.1:5173

# 3. Mobile (web preview or device)
cd mobile
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8000/api/v1
```

The seed script refuses to run against a database that already has users; pass
`--force` to wipe and rebuild the demo dataset.

### Demo accounts

Password for every seeded account: `DemoPass1!`

| Email | Role |
| --- | --- |
| `citizen@demo.civicai` | Citizen (Ward 12) |
| `officer@demo.civicai` | Officer, Roads |
| `supervisor@demo.civicai` | Supervisor, Roads |
| `admin@demo.civicai` | Municipal administrator |

## One-click launcher (Windows)

`start-civicai.bat` in the repo root is a menu for the everyday flows:

| Option | What it does |
| --- | --- |
| 1 | Starts the API (new window, `0.0.0.0:8000`) + web console (new window, `:5173`) and opens the site |
| 2 | Starts only the API |
| 3 | Starts only the web console |
| 4 | Boots the `ms_test` emulator if needed, installs the current APK, and opens the app pointed at this PC (`10.0.2.2:8000`) |
| 5 | Clears app data so the mobile app falls back to `10.0.2.2:8000` |
| 6 | Stops whatever is listening on 8000 and 5173 |
| 0 | Exit |

Double-click it, or run one action directly:

```bash
start-civicai.bat        # menu
start-civicai.bat 1      # API + website, no menu
start-civicai.bat 4      # open the app in the emulator
```

The status block at the top shows whether the API, the website and the emulator are
already up. Both servers stay running in their own windows when the launcher closes.

## Install the Android app

1. Download `app-release.apk` from the latest release:
   <https://github.com/GigaVolt3/Smart-city/releases/latest/download/app-release.apk>
2. Allow installs from the browser/file manager when prompted (signed with a debug
   keystore — fine for demos, not for Play Store).
3. Run the API so the phone can reach it:
   `python -m uvicorn backend.main:app --host 0.0.0.0 --port 8000`
4. In the app, tap **Change** next to `Server:` on the sign-in screen and enter the host
   running the API — `10.0.2.2:8000` inside the Android emulator, or
   `<your-computer-ip>:8000` for a phone on the same Wi-Fi. `/api/v1` is appended
   automatically.
5. Sign in with `citizen@demo.civicai` / `DemoPass1!` (or officer, supervisor, admin).

## Repository layout

```
backend/
  ai/                 priority scorer, classifier, duplicate detection
  core/               config, database, security, dependencies
  models/             SQLAlchemy models
  routers/            auth, users, departments, categories, complaints, ai,
                      analytics, notifications, escalations, audit
  schemas/            Pydantic request/response models
  services/           escalation engine, notifications, uploads, audit, scoping
  scripts/seed_demo.py
  tests/              50 pytest cases

dashboard/src/
  pages/              dashboard, complaints, detail, new, map, analytics,
                      departments, users, escalations, audit, notifications,
                      profile, auth, 404
  components/         layout, charts, maps, complaint primitives, ui
  providers/          auth session, toasts
  hooks/queries.ts    TanStack Query hooks for every endpoint
  styles/globals.css  the whole design system and responsive rules

mobile/lib/
  data/               typed models + API client
  core/               providers, theme, formatting, shared widgets
  features/           auth, shell, home, complaints, map, notifications, profile

docs/                 architecture and setup notes
```

## Quality gates

```bash
python -m pytest backend/tests -q                       # 50 passed
cd dashboard && npm run build                           # tsc -b + vite build
cd mobile && flutter analyze && flutter test
```

## Documentation

- [PROJECT_ANALYSIS.md](PROJECT_ANALYSIS.md) — baseline audit, gaps, decisions
- [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md) — phases, deliverables, status
- [DESIGN_SYSTEM.md](DESIGN_SYSTEM.md) — tokens, components, responsive rules
- [QA_REPORT.md](QA_REPORT.md) — test matrix, screenshots, defects fixed
- [docs/screenshots/](docs/screenshots/) — 26 captured screens (web desktop, web mobile, Flutter)
- [CHANGELOG.md](CHANGELOG.md) — release history
- [docs/architecture.md](docs/architecture.md) — system architecture
- [docs/setup.md](docs/setup.md) — environment troubleshooting

## Limits

The default configuration is a single-node demo deployment: SQLite, local disk uploads,
in-process scheduler, and an AI scorer based on keyword/heuristic models rather than a
trained municipal dataset. See PROJECT_ANALYSIS.md for the production gap list.

MIT licensed, academic use.
