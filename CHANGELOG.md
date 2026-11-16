# Changelog

All notable changes to CivicAI. Versions follow [SemVer](https://semver.org/).

## [1.2.2] - 2026-11-16

### Added

- `start-civicai.bat`: Windows launcher with a live status block and one action per flow —
  start API + website, start either one alone, open the mobile app in the emulator against
  this PC, reset app data, stop servers. Each action is also reachable as an argument
  (`start-civicai.bat 4`) for scripting.
- Launcher installs its own dependencies: creates `.venv` and installs
  `backend/requirements.txt`, runs `npm ci` in `dashboard` and `flutter pub get` in
  `mobile` when the packages are missing, so a fresh clone needs only Python, Node.js
  and Flutter on `PATH`. Option 8 forces the whole check; the status block shows
  whether anything is still missing.
- Launcher option 7 builds the release APK and installs it on a USB-attached phone,
  then prints the LAN address the phone must use for the API.

### Fixed

- Launcher waits use a real delay and `curl` health probes instead of `timeout`, which
  refuses to run when stdin is redirected; the API is polled until `/health` answers
  before the website or the app is opened.
- Option 4 no longer hangs at `adb wait-for-device` when no emulator exists: it attaches
  with a 2-minute timeout, checks the SDK, offers to download `platform-tools` +
  `emulator` + the Android 14 system image, creates an `ms_test` AVD when none is present,
  reuses an existing AVD otherwise, verifies the APK actually registered, and prints
  manual setup steps instead of stalling when the SDK cannot be installed.
- `start-civicai.bat` broke the API window once the virtualenv existed: `cmd /k` received
  the unquoted `.venv\Scripts\python.exe` path and split it at the space in the repo
  folder name. The launcher now quotes it.
- Installing the APK on a phone failed with no explanation. The launcher now reports
  adb's own error with the matching cause, retries the non-streaming installer, and
  uninstalls-then-reinstalls when the phone holds a build signed with a different key.

### Changed

- Android release builds are signed with a real keystore instead of the debug key.
  `mobile/android/app/build.gradle.kts` reads `mobile/android/key.properties` (created
  once by the launcher, both files gitignored) and falls back to the debug key when it
  is absent. One stable key means a newer APK upgrades the installed app instead of
  being rejected with `App not installed`, and Play Protect stops flagging the build.

## [1.2.1] — 2026-11-14

Release-APK fixes found while running the signed build on a real Android device.

### Fixed — Mobile

- Release APK had no `android.permission.INTERNET`: every request failed with
  "Cannot reach the CivicAI service" even with the backend running. Debug builds hid the
  bug because Flutter's debug manifest adds the permission. The main manifest now
  declares `INTERNET`, and `android:usesCleartextTraffic="true"` so the plain-HTTP local
  API is reachable.
- App label is now `CivicAI` instead of `civicai` in the launcher and task switcher.

### Added — Mobile

- In-app backend target: the login screen shows the active API URL with a **Change**
  action, validates and normalises whatever the user types (`host:port`,
  `http://host:port`, full `/api/v1` URL), persists it, and uses it for the rest of the
  session. A sideloaded APK now works on any phone without rebuilding.
- "Use citizen demo credentials" re-runs form validation so stale "required field" errors
  clear as soon as the fields are filled.

## [1.2.0] — 2026-11-13

Full product delivery: web operations console, mobile client rewrite, backend feature
completion, QA, and documentation.

### Added — Backend

- Notification model, schemas, service, and router (list, unread count, mark one,
  mark all, delete) with fan-out on complaint creation, status change, assignment, and
  escalation.
- Analytics overview endpoint with role scoping: KPIs, status and priority breakdowns,
  30-day trend, department/category/ward performance, SLA summary, recent activity, map
  points, personal counters.
- Evidence upload service: MIME allow-list, 8 MB cap, safe filenames, per-complaint
  storage, `/uploads` static mount, attachment list/delete endpoints.
- Profile update (`PUT /auth/me`) and password change with current-password verification.
- Assignable officer directory (`GET /users/officers`), department and category PATCH
  endpoints.
- Escalation engine with rule selection, idempotent level advancement, recipient
  resolution, notifications, and audit writes; escalation summary/events/rules endpoints
  and a manual sweep; APScheduler worker on app lifespan.
- Audit trail read endpoint and audit writes across complaint, catalogue, profile,
  password, and escalation actions.
- Paginated complaint feed (`/complaints/paged`) returning totals, plus `overdue`,
  `assigned_to_me`, and search filters on both list endpoints.
- Seed script now guarded (refuses to double-seed; `--force` wipes and rebuilds).

### Changed — Backend

- Priority scoring treats the category default as a floor, reports a
  `[Category Default]` factor, and uses the category SLA for low-priority tiers instead of
  a hard 72-hour minimum.
- Escalation reasons use human-readable durations and say "SLA deadline reached" instead
  of "exceeded by 0.0h".
- Complaint creation now calls the current AI module path.

### Added — Web console (`dashboard/`)

- React 19 + Vite + TypeScript single-page app with TanStack Query, React Hook Form +
  Zod, Recharts, and Leaflet.
- Design system in `src/styles/globals.css`: tokens, layout shell, 40+ components,
  breakpoints at 1240/1080/760/420, reduced-motion support.
- Pages: overview, complaint queue, complaint detail, new complaint, live map, analytics,
  escalations, departments and categories, people and roles, audit trail, notifications,
  profile and settings, login, register, 404.
- Role-aware navigation and route guards, persisted session with refresh, notification
  bell with unread count, toast feedback, skeleton and empty/error states.
- Responsive layouts: icon rail, slide-over nav, card-based mobile tables, bottom nav with
  a report FAB.

### Changed — Mobile (`mobile/`)

- Replaced the demo-data UI with a real API client: token storage and refresh, typed
  models, multipart evidence upload, platform-aware base URL.
- New mobile UX: `NavigationBar` shell with Home/Cases/Map/Alerts/Profile and a report
  FAB; home dashboard, filterable case list, detail with status update, report form with
  validation and photo picker, live map with hotspots, alerts, profile.
- Shared theme tokens aligned with the web console; shared widgets for KPI tiles, status
  pills, section cards, empty/error states, and skeletons.
- Removed `go_router`, `shimmer`, `uuid`, splash/onboarding, and the demo dataset.
- Lowered SDK constraint to `^3.11.0` for the available Flutter toolchain; enabled web.

### Fixed

- Complaint detail crash caused by an early return inside `useMemo` (SLA progress now
  computed in an IIFE).
- SLA progress bar rendered brand teal even for breached cases; now red/amber/green to
  match the state label.
- Complaint reference column wrapped onto two lines in the queue table.
- Mobile-width map filter toolbar overflowed; now a two-column grid with full-width
  search and ward select.
- Audit table rendered `#null` for events without a resource id.
- Departments directory stats overflowed below 420px; now a two-column grid with the last
  item spanning both.
- Status update sent `PATCH` to a `PUT` endpoint on mobile; method corrected.
- Dashboard resolution hint mis-stated the resolved count; now `${resolved} of ${total}
  resolved all-time`.
- Escalation copy showed "SLA deadline exceeded by 0.0h".

### Documentation

- Added PROJECT_ANALYSIS.md, IMPLEMENTATION_PLAN.md, DESIGN_SYSTEM.md, CHANGELOG.md,
  QA_REPORT.md, `dashboard/README.md`, and rewrote the root and mobile READMEs.
- Backend test suite grown from 32 to 50 tests covering every new endpoint.

## [1.1.0] — 2026-11-11

- Backend: analytics, notifications, uploads, escalation engine, audit, profile and
  catalogue administration, paged complaint feed.
- Web console: initial dashboard build with full route set and design system.
- Mobile: rewrite started against the live API.

## [1.0.0] — baseline

- Phase 1 mobile demo UI (splash, onboarding, auth, home, complaints, submit, alerts,
  profile) driven by local demo data.
- Phase 2 FastAPI backend: JWT auth, RBAC, complaint lifecycle, SLA calculation, status
  timeline, escalation models, audit model, seed data, 32 tests.
- AI services: keyword classifier, duplicate detection, priority scoring, hotspot
  clustering, image verification.
