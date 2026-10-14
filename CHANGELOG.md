# Changelog

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
