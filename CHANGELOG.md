# Changelog

## Unreleased

- **Package ID changed** from `dockmoid.plasmoid` to `com.github.deathrashed.dockmoid`, the
  reverse-domain form Plasma widgets use. Plasma sees it as a new widget: existing widgets keep the old
  package until moved. docs/USER_GUIDE.md → "Upgrading from dockmoid.plasmoid" moves them with their
  settings; `install.sh` says so when the old package is still installed. The translation domain is now
  `plasma_applet_com.github.deathrashed.dockmoid`.
- The widget description is now "Deploy · Monitor · Control / Docker & Podman Management" (Add Widgets
  and AppStream).
- Lighter start-up: only the ~160 interface icons Dockmoid uses are embedded in its icon data (72 KB,
  was 900 KB with all 1,958 Lucide icons). Any other bundled Lucide name still loads from its file. A
  test fails if an icon is used without regenerating.
- Repository layout: the translation template moved from `po/` to `translate/` beside its scripts, and
  `contents/ui/Views` and `contents/ui/Backend` are now lowercase `views` and `backend`.
- The inspector can sit below the list or beside it: the layout button on the inspector strip
  switches, and the divider resizes it either way (sizes are remembered). Hidden while beside the list,
  it folds to the strip below the list. A popup too narrow for two panes stacks them; the search field
  only takes the room the strip's tabs and buttons leave, and opens a box instead when there is none.
- Search sits pinned at the right of the inspector strip and slides out to the left; its icon shows the
  scope and opens the choices (Containers, Go to, Docker Hub Images). It reads "Search" unless the
  icon-only setting is on. Go to matches loosely: "dpl" finds Deploy. More → Search sets its look,
  icon-only and scope.
- Fixed: buttons in inspector page headers (Compose, Health) drew a dark fill, label and icon on a dark
  theme. They turn icon-only and back as the pane settles, and Plasma's button kept its own colours
  after that; Dockmoid buttons now always follow the colours around them.
- Refresh moved to the far left of the footer; Select moved to the inspector bar before Overview.
- The Health tab shows the selected container's health: its healthcheck, last check and output,
  restarts, last exit, what its logs repeat, its events and the fixes that apply to it.
- Sort and Detail menus have icons; the Table's Columns menu uses the same style as the Detail levels.

- Search is on the bottom strip, in one of three looks (a box that toggles with its button, a field that
  becomes a field on press, or a field always shown), set in Settings or More → Search. Ctrl+F opens it
  by default; the key is set in Settings → Appearance.
- The inspector tabs toggle: pressing the open tab again hides the pane. The Health tab lists what needs
  attention across containers, with Diagnose, Restart, Logs and Details buttons, and the recent events.
- Home in the footer returns to the default view with no filter, selection or open page; the
  inspector stays as it was.
- Labelled toolbar buttons have more room at each side, so their labels no longer run together.
- Diagnose words health the same way as the Health tab; Go to → Health shows the inspector if it was hidden.
- Internal: the inspector layout rules, the page list and the health/log read each live in one tested
  module, and the image update check moved out of the engine backend into its own controller.
- The Table's Detail button is Columns: presets (Compact, Standard, Everything) instead of levels.

- Toolbar: Filter, Sort, Search and a Select toggle sit with View and Detail. The strip under the list
  holds only the inspector's tabs and stays pinned to the bottom; pressing the open tab hides the pane.
- Search has three looks (a box under the button, a field that opens in the toolbar, or always a
  field) and three scopes: filter containers, go to a page or container, or search Docker Hub (Enter
  opens the results on Deploy). Set in Settings → Appearance; the scope can be switched in the box.
- Context menu: Apply Compose Changes moved to the Compose submenu; "Select" replaces "Select Several";
  Logs With Others appears only in select mode; entries that do not apply are hidden instead of greyed.
- Buttons share one look: a selected tab's light accent wash for primary and toggled buttons, no solid
  accent fill. Log toolbar toggles (Freeze, Follow, Wrap) and Filter/Sort use it.
- Log digest: Diagnose and the Events inspector summarise the newest log lines in plain sentences:
  error loops, recurring messages and single errors, with counts (not raw lines).
- Log watch (Settings → Monitoring, default every 15 minutes): reads a few running containers' recent
  logs and announces a new error loop once (notification and Activity). Health and probe alerts are
  unchanged.
- Details has a Diagnose tab second after Overview; the menu's Diagnose opens it.
- Doctor opens on insights built from state Dockmoid already has (unhealthy or non-answering containers,
  recent crashes and restarts, repeated log errors, updates, undeployed services). It runs no checks until
  Run checks is pressed.
- Minimal view: cards keep clear of their frame, so icons and state marks no longer overlap the edge.

- Greyed-out buttons say why on hover (read-only mode, engine offline, another action running, or
  not possible in the container's state); greyed-out menu entries carry a short reason, and row
  tooltips name the container ("Stop navidrome").
- Compose: "Apply Compose Changes" re-reads the files and recreates only what changed (a stopped
  service stays stopped), unlike Restart. "Preview Changes" uses `--dry-run` where the installed
  Compose supports it (2.17+). Both are in the menus and the inspector's Compose tab.
- Update, Recreate and Apply confirmations list the mounts that are kept and the paths written inside
  the container that would be lost (`docker diff`), and say this is not a backup.
- Details: the healthcheck's progress (starting, healthy, failing streak, or none configured) and its
  last result and output; the image-update state says up to date, update available, not checked,
  check failed, a local image, or needs buildx, with when it was checked.
- Compose profiles: discovery keeps services behind profiles (Compose 2.20+ wildcard, older versions
  as before); rows mark them as optional and Doctor reports them as info, not a warning.
- Diagnose (container menu, Doctor): exit code and its usual meaning, OOM, restarts, health output,
  recent events, the log lines worth reading first and the actions that fit, with no guessed cause.
- Compare Network With (Inspect menu): shared networks, the names each container answers to,
  published ports and what localhost means inside a container.
- Logs With Others: several containers' logs as one timeline, labelled and time-bounded.
- Select Several: tick containers in any view, review exactly which ones Start/Stop/Restart/Update
  apply to and which are skipped and why, then see a result per container.
- Activity entries open the container (crashes and restarts on its Logs tab); Deploy ends with a
  result card (state, Details, Logs, Web, project folder) and keeps an unfinished form as a draft
  in memory only (never on disk, since environment values can be secrets).
- Engine unreachable: advice fits the connection (local, rootless, Podman, remote), with the command
  to copy, Try Again and Connection Settings; a remote host never gets a Start button.
- Problem Report (More menu): versions, connection type and recent errors with the home folder, user
  name, remote host names and IP addresses redacted, shown for review before copying.
- Removable filter chips over the list; Manage Saved Views renames, reorders and deletes views;
  Grid, Table and Groups support arrow keys, Enter and the Menu key like List.
- Cleanup reports the measured change in engine disk use; reclaimable sizes are labelled estimates.
- Faster with large output (measured on 350 KB of inspect JSON and a 5000-line log): Inspect expand
  all 36 s → 0.15 s, search ~30 s → ~0.15 s; log load 2.2 s → 0.2 s. The tree parses once and
  draws only visible rows; logs format each line once and draw at most the newest 2000 lines.
- Internal: one Compose recipe module shared by immediate actions and Doctor; one LogSession owner
  for the inspector, detail and output log views.

- Under each name, a timeline replaces the image: clock icons with how long it has been up, when it
  stopped ("Oct 10 · 9d") and, after a recent recreate, the container's age. Tooltips give the exact
  dates; the image moves to the name's tooltip and to Detailed rows. The times come from the
  existing restart-policy inspect read, re-read only when a container's state changes.
- The detail header shows one "Running · Healthy" badge instead of a separate health badge; the
  inspector's current tab keeps its label on a narrow popup, and the list's Filter/Sort/Search are
  set apart from the tabs.
- Logs: Freeze, Follow and Wrap are named toggles on a wide viewer, and a frozen display says so,
  with "Show New Lines".
- Stale data: when a refresh fails the footer shows a clock with the data's age (click to retry) and
  the list is dimmed, instead of last-known colours looking like a fresh check.
- One selection across views: switching List, Table, Grid or Chips scrolls to the inspected
  container; arrow keys in the list move the inspector with them; when a filter hides the
  inspected container the inspector says so and offers "Show in List".

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
