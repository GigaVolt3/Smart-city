# Design System

The CivicAI interface is a calm civic-operations surface, not a marketing dashboard. It
reads like a municipal record system: warm paper background, deep teal as the working
color, amber for caution, red only for a genuine breach.

The same tokens drive both clients. On the web they live in
`dashboard/src/styles/globals.css` as CSS custom properties; on mobile they live in
`mobile/lib/core/theme/app_theme.dart` as Dart constants. Values are deliberately aligned
so a screenshot from either client looks like the same product.

## 1. Color

### Surfaces

| Token | Value | Use |
| --- | --- | --- |
| `--bg` | `#f4f6f3` | Page canvas |
| `--bg-deep` | `#eef1ed` | Recessed bands, table headers |
| `--surface` | `#ffffff` | Cards, panels, inputs |
| `--surface-2` | `#f8faf8` | Nested rows, hover fill |
| `--surface-3` | `#f1f4f1` | Chips, skeletons, inert controls |
| `--line` | `#dfe5e0` | Default border |
| `--line-strong` | `#c8d2cc` | Emphasized divider |

### Text

| Token | Value | Use |
| --- | --- | --- |
| `--ink` | `#101c18` | Headings, primary text |
| `--ink-2` | `#43544d` | Body copy |
| `--ink-3` | `#6d7d76` | Secondary labels, metadata |
| `--ink-4` | `#94a29c` | Placeholder, disabled |

### Brand and semantic

| Token | Value | Meaning |
| --- | --- | --- |
| `--brand` | `#0e7c66` | Primary action, links, active nav |
| `--brand-dark` | `#0a5c4c` | Hover/pressed |
| `--brand-deep` | `#073c32` | High-contrast text on soft brand |
| `--brand-soft` | `#e6f2ee` | Selected rows, brand badges |
| `--amber` | `#f5b942` | Attention, "at risk", highlights |
| `--amber-deep` | `#b07508` | Amber text on light fill |
| `--amber-soft` | `#fdf3dc` | Warning fill |
| `--danger` | `#bf3f38` | SLA breach, destructive action |
| `--danger-soft` | `#fbeceb` | Danger fill |
| `--warn` | `#b26a0b` | Non-critical warning text |
| `--success` | `#177a5b` | Resolved, on-track |
| `--info` | `#2e6c9e` | Neutral informational |

### Sidebar

`--sidebar #0b1714`, `--sidebar-2 #10211d`, ink `#cfdad5`, muted `#83978f`.

The sidebar is the only dark region in the product. That contrast is the primary
orientation cue, so the content area never uses a dark theme.

### Status mapping

| Domain state | Token pair |
| --- | --- |
| `submitted` | info / info-soft |
| `in_progress` / assigned | amber / amber-soft |
| `resolved` | success / success-soft |
| `rejected` | danger / danger-soft |
| `escalated` | danger / danger-soft with left rule |
| SLA on track | success |
| SLA at risk | amber |
| SLA breached | danger |

Role badges use the same palette: citizen neutral, officer brand, supervisor amber,
admin deep brand.

## 2. Typography

- Family: **Inter Variable**, loaded via `@fontsource-variable/inter`. Fallback stack is
  system UI. Monospace is used only for tracking numbers, coordinates, and IDs.
- Base: 14px / 1.5. Optical features `cv11` and `ss01` enabled for the single-storey `a`
  and tabular numerals.
- Headings: weight 650, letter-spacing `-0.022em`.
- Scale in practice:

| Role | Size / weight |
| --- | --- |
| Page title | `clamp(22px, 2.3vw, 30px)` / 650 |
| Section title | 15-16px / 650 |
| Card title | 13.5-14px / 600 |
| Body | 13.5-14px / 400 |
| Table body | 12.5-13px |
| Metadata / label | 11-11.5px / 500-600, often uppercase with `0.04em` tracking |
| Tracking number | 11.5px mono |

Numbers that appear in KPIs use tabular figures so columns do not jitter.

## 3. Spacing, radius, elevation

- Spacing follows a 4pt scale: 4, 8, 12, 16, 20, 24, 32, 40.
- Radii: `6px` (xs, chips inside chips), `9px` (sm, inputs/badges), `13px` (default cards),
  `18px` (lg, hero panels and modals), `999px` (pills).
- Shadows are restrained:

| Token | Use |
| --- | --- |
| `--shadow-xs` | Inputs, table rows |
| `--shadow-sm` | Cards at rest |
| `--shadow-md` | Popovers, raised cards on hover |
| `--shadow-lg` | Modals and the mobile nav sheet |

No glassmorphism, no glow, no gradient fills except the single subtle hero wash used on
the map and profile headers (teal-to-paper, low opacity).

## 4. Layout

- Shell: fixed dark sidebar `252px`, topbar `66px`, content max width `1440px`.
- Content grid: 12 columns, gaps 16-20px. Utility spans `.span-4`, `.span-5`, `.span-7`,
  `.span-8`, `.span-12` drive dashboard composition.
- Cards always sit on the canvas with a 1px border; elevation is secondary.
- Tables: sticky header on scroll, right-aligned numerics, monospace references,
  row hover `--surface-2`, no zebra striping.

### Breakpoints

| Width | Behavior |
| --- | --- |
| > 1240px | Full 12-column layouts, sidebar expanded |
| ≤ 1240px | Grid columns collapse to 6, side panels stack |
| ≤ 1080px | Sidebar becomes icon rail; dense tables scroll horizontally |
| ≤ 760px | Sidebar becomes a slide-over with backdrop; bottom nav appears; tables convert to card lists (`.table-desktop` hidden, `.cards-mobile` shown); page padding drops to 14px |
| ≤ 420px | Single column everywhere; directory stats go 2-up with the last item spanning both; filter toolbar becomes a 2-column grid with the search full width |

Motion respects `prefers-reduced-motion`: spinners and transitions are disabled.

## 5. Components

### Buttons

`.btn` with variants `--primary` (brand fill), `--secondary` (amber), `--outline`,
`--ghost`, `--danger`, `--icon`; sizes `--sm` and `--lg`. Height 36px default, 30px small,
42px large. Focus ring is a 2px brand outline with 2px offset, applied to all interactive
elements via `:focus-visible`.

### Form controls

`.input`, `.select`, `.field` (label + control + hint + error), `.input-with-action`
(search + submit), `.check-toggle`. Errors render in `.inline-error` under the field and
add a danger border; success is communicated by toast, never by silent state.

### Data display

| Component | Classes | Notes |
| --- | --- | --- |
| KPI tile | `.stat-card` + `--brand/--warn/--danger/--success/--neutral` | Label, large value, delta line, optional icon |
| Card | `.card`, `.card--padded`, `.card--flush` | Header slot, body, footer |
| Table | `.table-wrap`, `.data-table` | Horizontal scroll container always present |
| Badge | `.badge` + status/role modifiers | Pill, 11px uppercase |
| Chip | `.chip`, `.filter-chips` | Filter toggles, aria-pressed |
| Segmented | `.segmented` | Time-window switches |
| SLA meter | `.sla`, `.sla--on/at/breached/met`, `.sla-progress`, `.sla-hero` | Never color-only: always text label |
| Skeleton | `.skeleton`, `--title/--row/--card/--panel/--notif` | Shimmer-free pulse, disabled under reduced motion |
| Empty state | `.empty-state`, `--error` | Icon, title, one sentence of guidance, single action |
| Modal | `.modal-backdrop`, `.modal` with `--sm/md/lg` | Focus trap, escape to close |
| Toast | provider-driven | Bottom-right, dismissible, role=status |

### Product-specific

- `.attention-list` — overdue queue rows with countdown and owner.
- `.ai-card`, `.ai-suggest`, `.ai-factors` — AI panel. Always labeled as a suggestion and
  every factor is shown, so staff can see why a score was produced.
- `.timeline` — vertical status history with actor, timestamp, and comment.
- `.evidence-grid` — attachment thumbnails with file name and size; PDFs get a glyph.
- `.map-shell`, `.map-side`, `.map-legend`, `.map-canvas-card` — map workspace with a
  synchronized list.
- `.hotspot-list`, `.bar-list`, `.donut` — analytics visualizations.

## 6. Interaction rules

1. Every action that mutates data shows a pending state on the control and a toast on
   success or failure. No optimistic UI for status changes.
2. Destructive actions require confirmation in a modal; the confirm button repeats the
   verb ("Delete department").
3. Loading uses skeletons that match the final layout, not centered spinners, for
   page-level fetches. Inline mutations use `.inline-loading`.
4. Empty states distinguish "nothing yet" from "nothing matches these filters" and offer
   the relevant reset.
5. Navigation state is in the URL (filters, pagination, selected complaint) so refresh and
   back preserve context.
6. Role guards hide nav items a role cannot use and redirect deep links to the dashboard.

## 7. Accessibility

- Contrast: body text on canvas is 11.9:1; `--ink-3` on white is 4.6:1; amber text always
  uses `--amber-deep` on soft fill rather than raw amber on white.
- Focus is always visible, and a `.skip-link` jumps to main content.
- Status is never encoded by color alone: badges carry text, SLA bars carry a label, map
  pins carry a legend and popup text.
- Touch targets on mobile are at least 44×44; the report FAB is 56×56.
- Live regions announce toast messages and the unread count.
- Icon-only buttons carry `aria-label`; the sidebar collapse control announces state.

## 8. Mobile mapping

| Web | Flutter |
| --- | --- |
| `.stat-card` | `KpiTile` in `civic_ui.dart` |
| `.badge` | `StatusPill` / `PriorityPill` |
| `.card` | `SectionCard` |
| `.skeleton--card` | `SkeletonCard` |
| `.empty-state` | `EmptyState` / `ErrorState` |
| Sidebar nav | `NavigationBar` + FAB in `app_shell.dart` |
| `.map-shell` | `flutter_map` with hotspot circles and a bottom sheet list |

Type on mobile runs one step smaller (12-13px body, 20-22px page titles) to keep density
without shrinking touch targets.
