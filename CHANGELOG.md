# Changelog

## Unreleased

- Performance: about two thirds fewer UI objects (10.6k to 3.4k in the offscreen test with 16 containers).
  Action menus, the toolbar menus, the update review dialog, the icon chooser and tooltips are built when
  first needed; list rows use a light icon button; usage meters no longer animate on every refresh; SVG
  data URLs are cached; search waits a moment while you type.

- Shared building blocks: style tokens (`lib/style.js`), `DockButton`, `StatusLine`, `SectionHeader` and `Tones`.
- Podman users see "Podman" instead of "Docker"; the usage-bar scale setting is honoured; usage bars turn amber/red past the CPU/memory alert thresholds.
- Doctor findings carry an explicit severity; log colours follow light and dark themes; a failing health check hollows the state dot.
- The toolbar hides list-only controls on other pages; a host chip shows remote or context connections.
- Needs attention rows offer Restart and Logs; the panel tooltip names the containers that need attention.
- Destructive dialogs use verb buttons; Docker Hub results show an Official badge; the deployment output panel opens when a command runs.
- Faster record lookups, cached view settings and one fewer pass over log lines.
- Removed three unused settings pages that duplicated live ones.

## 2.4.0 — 2026-10-15

This release refreshes the main layout, settings, diagnostics and Compose service visibility.

- Native system tray activation now respects Plasma's shared-popup selection contract.
- Running, Needs attention and Inactive use resizable sections; inactive services support Cards, List
  and Icons. Per-view sizing, density, expansion, preview and embedded tools are remembered.
- Optional cached hover/selection preview, plus embedded Doctor, New and Resources panes.
- Responsive toolbar with Doctor and Maintain, compact grouped menus and searchable views.
- Docker Compose discovery retains Not created services. Cleanup preserves stopped containers and
  volumes by default; stopped-container removal is explicit.
- Doctor provides evidence, selected plans and visible results; unsupported dry runs are Plan only.
- New-container workflows use a page, with collapsible controls and resizable command output.
- Framed Docker Hub results show stars/downloads, Official filtering and sorting of returned results.
- Inspect Tree/Raw and expansion controls, ANSI log colors, clearer disclosures and aligned resources.
- Short-lived read caches, duplicate stats guards and scrollbar-loop fixes reduce avoidable work.

### Validation and limits

Validated locally on Plasma 6.7.5, with native tray opening confirmed by the user. Production Qt views
were exercised at 360 and 1050 pixels across views/detail levels, maintenance pages and continuation
controls. Installer rollback, helpers and packaging have isolated checks. This does not certify every
Plasma 6 minor version or every remote/rootless/Podman configuration. No before/after memory claim is
made. Docker Hub sorting covers up to 50 returned results, not a global popularity ranking.

Install/update instructions are in README.md. This document and the generated archives prepare a release;
they do not imply that a GitHub Release or KDE Store listing has already been published.

## 2.3.0

### Added
- Grouped toolbars with four label styles, wrapping layouts and attached-popup resize handles.
- Direct action groups on container details, distinct submenu artwork and reorganized settings tabs.
- Custom service-icon file picker, per-service/name/image overrides and previews.
- Theme-aware monochrome service/action icons, with neutral bundled action fallbacks.
- Reviewable sequential image updates, precise per-service Compose recreation and pull-only standalone operations.
- Read-only monitoring mode, saved views, versioned per-host settings profiles and explicit command import/export.
- Responsive settings tabs, structured rule editors, diagnostics, page defaults and native notification test.
- Portable release archive/CI checks and isolated installer, engine, profile and job-runner regressions.

### Fixed
- Attached-popup height cap and details overview scrolling.
- Missing row record fields hid update actions and produced misleading badges.
- Late process output could complete a timed-out retry; connection generations now isolate stale results.
- Multi-file Compose labels, Docker 23 health fallback, failed stop/offline states and polling fallback cadence.
- Custom icon cache invalidation, paused severity, image-cache refresh and record-specific output routing.
- Unsafe installer/download replacement, hardcoded data paths and invalid AppStream metadata.
- Group inventory failures no longer report successful mutation; unsupported engine capabilities are gated.


## 2.2.0

### Added
- Images, volumes and networks page with "unused" markers and removal.
- Compose project actions: up, down, pull, pull and recreate, force recreate.
- Optional image update check (registry digest comparison) with a one-click update.
- Resource alerts (sustained CPU or memory), and web-page health probes.
- CPU and memory graphs, a filterable log viewer, and a "Run" tab for one-off commands.
- Pinning, a "needs attention" filter, sorting, and switchable Docker hosts (contexts).
- Keyboard shortcuts, configurable middle click, first-run help when Docker is
  missing, unreachable or not permitted.
- Monitoring settings page; translation scaffold; AppStream metadata.

### Changed
- Panel logo is a two-layer mark with a gauge ring showing running/total and state colour.
- Refreshing is tiered: a cheap change check, then a list refresh only on change.
- All bundled service icons are real logos (selfh.st, CC BY 4.0).

### Fixed
- Notifications were written to a misspelled directory and never appeared.
- Docker coming back after being down was never noticed.
- Stopped containers kept counting as unhealthy.
- Search broke on regular-expression characters.
- Pull and compose output never updated after the page opened.

## 2.1.0
- Restart-policy control, crash and unhealthy notifications, launchers, settings rewrite.

## 2.0.0
- Fork of dockercompanion.
