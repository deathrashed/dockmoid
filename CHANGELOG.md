# Changelog

## Unreleased

- Fixed: Full Logs in the inspector opened the detail page on Overview; it now opens on Logs and
  loads them straight away.
- Fixed: saved views with Pending Deployment, Updates Available or Failed came back as All
  Containers.
- Fixed: on a remote engine the inspector's Compose tab read a local file with the same path. It
  now says the file is on the remote host; Edit is hidden there. Projects with override files can
  switch between them.
- Narrow popups: log timestamp options moved into one menu so the log toolbar fits, and the detail
  header puts its action buttons on their own row under the status badges. Removed the combo-box
  sizing loops in Logs, Details and Resources.

- Container actions follow one rule set (lib/actions.js) in the menu, list rows, grid, table, detail
  header and inspector. Fixed: a paused container offered Restart, which then did nothing; the
  start/stop button showed Start on a paused container. A crash-looping container can now be
  stopped or killed, menu entries grey out while an action is running, and Run Command needs a
  reachable engine.

- Settings → Appearance → Panel: pick the panel style from live preview tiles, see it in all four
  states (all well, paused, problem, Docker down), with labelled colour swatches that are always
  visible. One "Badge shows" choice replaces the old style/checkbox/dot mix and adds "Nothing" and
  "Problems only". Empty rows ("State colour goes to:", "Dot:") are gone.
- Settings → Appearance → Popup gains the inspector: open or closed, which tab it opens on, and
  whether it follows the selection, the mouse or nothing.
- Advanced command fields and the launcher editor are wide enough to read a whole command.

- The panel under the list is now an inspector for the selected container: Overview (with live CPU and
  memory graphs), Logs (a live tail), Events (Dockmoid's alerts plus the engine's last 24 hours) and
  Compose (the file, with Validate and Edit). Filter, Sort and Search moved into its bar; Doctor,
  Resources and Deploy open as pages from the toolbar, and Activity joined the toolbar with a badge for
  entries you have not seen.
- Detail page: Started, Restarts, Last exit (with out-of-memory), each network's IP address, CPU and
  memory limits, the health-check command, user and working directory.
- Resources: a menu per item with Deploy from This Image, Pull Latest, Show Containers, Inspect,
  Layer History, Connect/Disconnect a Container (networks), Copy and Remove.

- Settings can be shared between Dockmoid widgets (panel, system tray, desktop): General → Behavior →
  "share with my other Dockmoid widgets" and "Copy These Settings to All Widgets". Popup size and list
  layout stay per widget.
- List sections fold on click, with a coloured icon and a count at the right end of the rule.
  Compose services without a container are "Pending Deployment" (blue, circle-plus) and a row
  reads "Undeployed". Stopped is red, Needs Attention yellow; All is grey and last in the status bar.
- Detail page: Overview, Container and Storage on the left, Usage and Network on the right; headings
  share one band with a coloured icon and rule. Pause/Resume, Kill and Update sit beside Stop and
  Restart (the Logs button went; the Logs tab stays). Link buttons name their network. The misleading
  "Up for" row (it showed time since creation) is gone.
- Context menu: Container (Details, Web, Logs, Manage, Links), Project (Open, Compose, Copy) and Tools
  (Customize, Inspect, Terminal). Manage holds Start/Stop/Pause/Restart/Kill/Update, a Force submenu
  (Restart Now, Recreate, Remove…) and Autostart. Compose splits into Inspect, Whole Project, This
  Service and Files, adding Start, Pause/Resume, Images, Processes, Validate Configuration and
  per-service Logs/Restart/Pull/Force Recreate. Inspect adds Processes, Usage Snapshot, Health Checks,
  Port Mappings, Filesystem Changes and Recent Events (all read-only).
- "New" is now Deploy (package-plus icon; Find Image, Configure, Import, Storage); its forms use the detail-page cards.
- Resources: labelled Refresh, Clean Up and Pull/Create buttons, summary tiles (unused filters the
  list), card rows with side-by-side usage badges, and a layout that fits the tray popup.
- Tabs look like tabs when not selected. Grid cards without live usage show state, image and
  project. A narrow status bar reads "CPU 8.7% · RAM 5.3%".
- Menus use title case with clearer wording (Remove Dangling Images…, Run Command…, More Cleanup Options…).
- Refresh is always a normal button; a click during a background read runs right after it.
- Badges have even padding; state icons line up on narrow rows; dock tabs centre their icons; the
  detached window and tooltip logos render smoothly on HiDPI screens.

- Less background work: one sleeping helper now waits for container change events instead of
  starting an `events` query every 3 s (open) or 15 s (closed); polling stays as the fallback.
  While closed, the full re-read relaxes to every 5 minutes, web probes to every 5 minutes (unless
  probe notifications are on), and `docker info` to every 10 minutes. The heartbeat reads the list
  without a separate engine check. All of these are under General → Refresh and Monitoring.
- Usage is sampled every 15 s on pages that only show the status-bar totals (New, Doctor, output).
- An unchanged container list skips re-processing; model sync uses an id index.
- The polling fallback recovers after ten minutes as intended (its check never re-ran before).
- The pulsing status dot stops while the popup is closed.
- Detail overview: one card style for every section, two columns when wide, foldable cards with
  a summary when folded; Usage shows memory, network, disk I/O and processes; ports, mounts and
  networks list one per line; web links appear under Network.
- Image search shows two cards per row, compact download counts (2.4B rather than 2.37e+09), and
  no longer opens the command output panel.
- Buttons have even padding and keep their icon and label centred; page-header badges wrap on a
  narrow popup instead of running under the action buttons.

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
