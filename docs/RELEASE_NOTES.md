# Dockmoid 2.4.0 — 15 October 2026

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

## Validation and limits

Validated locally on Plasma 6.7.5, with native tray opening checked in a running session. Production Qt views
were exercised at 360 and 1050 pixels across views/detail levels, maintenance pages and continuation
controls. Installer rollback, helpers and packaging have isolated checks. This does not certify every
Plasma 6 minor version or every remote/rootless/Podman configuration. No before/after memory claim is
made. Docker Hub sorting covers up to 50 returned results, not a global popularity ranking.

Install/update instructions are in README.md. This document and the generated archives prepare a release;
they do not imply that a GitHub Release or KDE Store listing has already been published.
