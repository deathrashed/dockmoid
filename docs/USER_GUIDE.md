# Dockmoid user guide

## Setup and permissions

Install with `./install.sh` or `kpackagetool6 -t Plasma/Applet -i package.plasmoid`. Add Dockmoid to a
panel, desktop or System Tray. Existing settings use the stable package ID `dockmoid.plasmoid`.
An update may require reloading the widget or signing out and back in. Dockmoid does not install an engine.

Select Docker/Podman and the connection context in Settings. Test the same command in a terminal as the
same user. For an unreachable engine, open Doctor to inspect its connection evidence. Do not grant
blanket privileges just to bypass a socket error. Remote Compose discovery/deployment is not supported;
local discovery runs Docker Compose against the configured project directory.

## Main page and navigation

Choose List, Table, Grid or Groups, then Minimal, Normal, Detailed or Verbose. Table column selection
includes every column regardless of detail level. Search opens from its magnifying-glass button;
filters and sort sit beside it. Less frequent actions live in More. Hidden toolbar actions move there
at narrow widths without duplicating their visible counterparts.

Running uses the chosen detail level. Needs attention shows unhealthy, restarting, paused or failed
services with evidence. Inactive supports Cards, List and Icons, and keeps Stopped distinct from Not
created. Use Start for an existing container or Create and start for a missing Compose service.

The gear beside Services enables previews on hover or selection, or embeds Doctor, New and Resources.
Previews read cached records rather than issuing inspect commands. At narrow widths preview stacks
below the services. Drag dividers to size sections and preview; per-view settings preserve choices.
Collapsed embedded tools unload their visual pages. Returning from Details preserves main-page filters,
selection and scroll. Footer count icons are clickable filters and have descriptive tooltips.

## Compose discovery

Configure the local project root in Storage settings. Discovery considers supported Compose file names
within the configured directory depth, resolves them with `docker compose config --format json`, and
retains only service identities, image references, selected links and bind-path checks. It does not
publish environment variables or resolved configuration bodies. `_archive`, `_backups`, `startup`,
hidden directories, `.git` and `node_modules` are excluded. Missing containers remain visible as Not
created. Keep Compose files and bind-mounted data in their existing locations.

## Details, logs and commands

Open Details for identity, project/service, published ports, mounts, health and restart policy.
Extended diagnostics use disclosure sections. Browser links include ports; hover for the full URL.
Logs support filtering, ANSI colors, wrapping, timestamps, follow controls and copying. Inspect provides
Tree/Raw modes, expansion controls and JSON/value/path copying. The Run tab executes a command inside
an existing container; it is separate from the Images and new containers page.

## Images and deployment

New opens Images, Deploy, Import and Storage tabs inside the widget. Image controls and command output
collapse independently. Search shows stars and download counts when Docker Hub supplies them; the
Official filter and sort apply to at most the first 50 returned results. Similar uses the repository
name; Popular sorts returned browsing results by downloads, not a global popularity index.

Review deployment settings before creating a project. Command output appears at the bottom, where its
height can be adjusted. Edit options restores the editable form. Named volumes and bind mounts are
different kinds of storage; existing project files are never silently overwritten.

## Doctor and cleanup

Doctor separates Overview, Containers, Compose, Storage and About. Findings include evidence and
specific actions rather than a blanket repair. Preview commands and affected services first. Plan only
means Docker provides no native dry run, so the preview is not a guarantee. Select actions explicitly,
then inspect progress, output and results. Doctor does not start all configured services automatically.

Cleanup defaults remove dangling images and build cache. Stopped-container removal is a separate,
explicit option; selecting it deletes container instances, not Compose files or bind-mounted data.
Named volumes are retained. Removing all unused images is also explicit; a configured Compose service
can still reference an image without having a container. Resources distinguishes these relationships.
Do not treat Unknown or zero existing containers as proof that an image is unwanted.

## Refresh and troubleshooting

Change checks, full-list heartbeat and usage samples have separate intervals. Statistics run while
open unless background statistics are enabled. Duplicate in-flight stats requests are suppressed.
Successful resource inventories and Doctor checks may be reused for 30 seconds on reopen; explicit
Refresh/Check bypasses this cache. Changing connection resets the relevant caches and cancels stale
results. Two Dockmoid instances still own independent backends; reduce background work when using both
panel and tray copies. No global cross-instance cache or memory-saving benchmark is claimed.

For a report, include Dockmoid version, Plasma version, engine type/version, connection type and steps
to reproduce. Redact credentials, tokens, private URLs and paths from logs, inspect output and diagnostics.
