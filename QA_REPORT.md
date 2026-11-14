# QA Report

Verification of the CivicAI delivery against the brief: production-quality desktop console,
dedicated mobile app, shared backend, no fabricated data, and working end-to-end workflows.

Everything below was exercised against a live stack: FastAPI on `127.0.0.1:8000`,
Vite console on `127.0.0.1:5173`, Flutter web build on `127.0.0.1:5174`, with the seeded
municipality (5 departments, 10 categories, 10 users, 48 complaints).

## 1. Automated checks

| Check | Command | Result |
| --- | --- | --- |
| Backend test suite | `python -m pytest backend/tests -q` | **50 passed**, 4 deprecation warnings (Starlette constant only) |
| Web type check + production build | `cd dashboard && npm run build` | Clean. `index` 482 kB, `charts` 397 kB, `maps` 154 kB, `query` 51 kB, `react` 44 kB |
| Flutter static analysis | `cd mobile && flutter analyze` | **No issues found** |
| Flutter tests | `cd mobile && flutter test` | Pass |
| Flutter release build | `cd mobile && flutter build web --release` | Success |

Backend coverage on the new surface: notifications (list, unread count, mark one, mark all,
delete, cross-user isolation), analytics (shape, role scoping, invalid window), escalations
(summary, events, rules, sweep, role restriction, human-readable reason text), audit
(admin-only, filter, actor), profile and password (update, wrong password, same password,
re-login), officers directory and catalogue PATCH (RBAC enforced), paged feed, overdue and
assigned-to-me filters, status update → timeline + notification, attachment upload, list,
delete, MIME rejection, empty-file rejection.

## 2. Desktop console — 1440×900

Every route loaded against seeded data with no console errors and no failed requests.

| Route | Verified | Evidence |
| --- | --- | --- |
| `/login` | Demo chips fill credentials, validation, sign-in | `web-dashboard.png` (post-login) |
| `/` overview | 4 KPI tiles with real counts, SLA posture alert, 30-day trend, status/priority mix, department table, needs-attention queue | `web-dashboard.png` |
| `/complaints` | 48-row paginated table, status/priority/department/ward/search filters, URL state | `web-complaints.png` |
| `/complaints/:id` | SLA hero and progress bar, AI panel, assignment, status form, timeline, evidence | `web-complaint-detail.png` |
| `/complaints/new` | Department → category linkage, AI routing suggestion, ward, coordinates, submit | `web-new-complaint.png` |
| `/map` | Leaflet + OSM tiles, status-coloured pins, ward filter, hotspot overlay, synced side list | `web-map.png` |
| `/analytics` | KPI row, trend, SLA ring, department performance, categories, wards, hotspots | `web-analytics.png` |
| `/escalations` | Summary counters, rules table, event history, "Run sweep now" | `web-escalations.png` |
| `/departments` | Department cards, create/edit modal, category table | `web-departments.png` |
| `/users` | People table, create user, role/department change, activate/deactivate | `web-users.png` |
| `/audit` | Paginated audit table with actor, action, resource, timestamp | `web-audit.png` |
| `/notifications` | Unread styling, mark all read, delete, empty state | `web-notifications.png` |
| `/profile` | Profile form, password change, role facts | `web-profile.png` |
| `/does-not-exist` | 404 with a way back | `web-404.png` |

Role checks: citizen only sees own complaints and own analytics; officer is scoped to their
department; supervisor and admin see the municipal dataset; deep links to `/users` and
`/audit` as a citizen redirect to the overview.

## 3. Console at mobile width — 390×844

The web app is responsive but this is not the primary mobile experience; the Flutter app
covers that. Verified that nothing breaks when the console is opened on a phone.

| Route | Verified | Evidence |
| --- | --- | --- |
| `/` | Sidebar becomes slide-over, KPI tiles 2-up, bottom nav with report FAB | — |
| `/complaints` | Table swaps to stacked cards, filters collapse to chips | `web-mobile-complaints.png` |
| `/complaints/:id` | Single column, SLA panel first, timeline readable | `web-mobile-detail.png` |
| `/complaints/new` | Sticky summary moves under the form, single column fields | `web-mobile-new-complaint.png` |
| `/map` | Map fills the viewport, toolbar becomes a 2-column grid with full-width search | `web-mobile-map.png` |

## 4. Mobile app — 390×844 (Flutter web build)

Real API calls only. Session persists across reloads; a 401 triggers one refresh attempt.

| Screen | Verified | Evidence |
| --- | --- | --- |
| Sign in | Demo credentials link, validation, error toast on bad password | — |
| Home | Greeting with ward, SLA alert card, 4 KPI tiles, "Report a civic issue" CTA, needs-attention queue, status mix, recent activity | `mobile-home.png` |
| Cases | Filter chips by status, priority/category rows, empty and error states | `mobile-cases.png` |
| Case detail | Header, SLA card, description, location, evidence, timeline, officer actions | `mobile-detail.png` |
| Status update | Bottom sheet with status picker, note field, submit; list and KPIs refresh | `mobile-status-update.png` |
| Report an issue | Category gated on department, ward picker, address, optional photo, submit | `mobile-report.png` |
| Report validation | Inline errors and red borders on every required field | `mobile-report-validation.png` |
| Map | OSM tiles, status pins, priority filter chips, hotspot toggle, case counter | `mobile-map.png` |
| Alerts | All/Unread filters, unread count, mark-all-read, per-item delete, deep link to the case | `mobile-alerts.png` |
| Profile | Account facts, notification summary, sign out | `mobile-profile.png` |

Role switch verified: signing out and back in as `officer@demo.civicai` shows the department
queue and exposes the status-update action; the citizen account does not.

## 5. Workflow QA

| Workflow | Steps | Result |
| --- | --- | --- |
| File a complaint (web) | `/complaints/new` → department 5, ward 12, category 9 → submit | 201, tracking number `CIVIC-2026-0049`, redirected to detail, appears in queue |
| Update status (web) | Detail → status `in_progress`, note, assign officer → submit | 200, timeline gains an entry, citizen receives a notification |
| AI analysis | Detail → "Run analysis" | Priority score and factors returned; category default respected as a floor |
| Mark all read | Notifications → mark all | Unread badge clears to 0 |
| Profile save | Profile → change name/phone → save | `PUT /api/v1/auth/me` 200, values persist after reload |
| Change password | Profile → wrong current password | Inline error, `400`, password unchanged |
| Department create | Departments → create | 201; test row removed afterwards, catalogue back to 5 |
| Escalation sweep | Escalations → run sweep | 200, `escalated: 0` when every overdue case already sits at its level (idempotent), reasons readable |
| Attachment upload | Detail → add evidence | 201, thumbnail renders from `/uploads` |
| Deep link + refresh | Reload on `/complaints?status=open&page=2` | Filters and page restored from the URL |
| Token expiry | Force an expired access token | One refresh, request replayed, no visible error |

Test rows created during QA were deleted from the database so the shipped demo dataset stays
at exactly 48 complaints.

## 6. Defects found and fixed

| # | Defect | Cause | Fix |
| --- | --- | --- | --- |
| 1 | Complaint detail crashed with a blank page | Early `return` inside `useMemo` | SLA progress computed in an IIFE |
| 2 | SLA progress bar was teal on breached cases | No state modifier on the bar | `sla-progress--breached/at_risk/met` colours |
| 3 | Resolution KPI hint read "29 of 48 resolved all-time" as a percentage | Wording implied a rate | `${resolved} of ${total} resolved all-time` |
| 4 | Complaint reference column wrapped to two lines | `.cell-ref` allowed wrapping | `white-space: nowrap` |
| 5 | Mobile-width map toolbar overflowed | Four controls in one row | 2-column grid, search and third select span both |
| 6 | Mobile-width new-complaint summary floated mid-form | Sticky applied to the main column | Sticky confined to `.compose-side` |
| 7 | Audit table and cards printed `#null` | Unconditional `#${resource_id}` | Render id only when present |
| 8 | Directory stats overflowed under 420px | 3-column grid | 2-column grid, last item spans both |
| 9 | Mobile status update failed with `405` | Client sent `PATCH` to a `PUT` route | Method corrected |
| 10 | Mobile "mark read" failed | Client sent `POST` instead of `PUT` | Method corrected |
| 11 | Mobile report form's photo tile was cramped | Half-width tile with nested padding | Full-width tile, centred caption |
| 12 | Mobile FAB overlapped the bottom nav | `FloatingActionButton.extended` | Icon-only FAB with tooltip |
| 13 | Mobile map caption was clipped by the FAB | Caption spanned full width | Caption ends above the FAB; copy shortened to "Tap a pin" |
| 14 | Escalation copy read "SLA deadline exceeded by 0.0h" | Fixed one-decimal formatting | "SLA deadline reached." under 30 minutes; whole hours above 10h |
| 15 | Priority scorer could downgrade a category below its configured default | Model score replaced the default | Category default is a floor, `[Category Default]` factor emitted |
| 16 | Negative "time remaining" on some detail pages | SQLite naive datetimes parsed as local | `as_utc` server-side, `parseApiDate` client-side |
| 17 | Mobile home had no primary reporting action above the fold | Reporting only via FAB | Full-width "Report a civic issue" button that invalidates caches and switches tab |

## 7. Accessibility and robustness spot checks

- Keyboard: tab order follows the visual order, focus ring visible on every control, skip
  link jumps to main content, Escape closes modals and the profile menu.
- Screen reader labels present on icon-only buttons (bell, sidebar collapse, row actions,
  FAB); map pins expose popup text.
- Colour is never the only signal: status badges and SLA states carry text.
- Touch targets on mobile are ≥44×44; the FAB is 56×56.
- Reduced motion disables spinner and skeleton animation.
- Loading states use layout-matched skeletons; every list has distinct "nothing yet" and
  "nothing matches your filters" empty states.
- API failures surface a message and a retry, never an infinite spinner. Verified by
  stopping the backend mid-session: the console shows its error card, the mobile app shows
  `ErrorState` with retry.

## 8. Known gaps at handover

- No automated browser E2E suite; this pass was manual with screenshots.
- Flutter web has no camera capture; the picker falls back to the file chooser.
- No offline write queue on mobile; reads are in-memory per session.
- English only.
- Production hardening items (Postgres migrations for the new tables, object storage,
  dedicated escalation worker, rate limiting) are listed in `PROJECT_ANALYSIS.md` §6.
