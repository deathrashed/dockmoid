# Dockmoid user guide

## Setup and permissions

Install with `./install.sh` or `kpackagetool6 -t Plasma/Applet -i package.plasmoid`. Add Dockmoid to a
panel, desktop or System Tray. The package ID is `com.github.deathrashed.dockmoid`; earlier versions
used `dockmoid.plasmoid` (see Upgrading from dockmoid.plasmoid below).
An update may require reloading the widget or signing out and back in. Dockmoid does not install an engine.

Select Docker/Podman and the connection context in Settings. Test the same command in a terminal as the
same user. For an unreachable engine, open Doctor to inspect its connection evidence. Do not grant
blanket privileges just to bypass a socket error. Remote Compose discovery/deployment is not supported;
local discovery runs Docker Compose against the configured project directory.

### Upgrading from dockmoid.plasmoid

Earlier versions were installed under the package ID `dockmoid.plasmoid`; it is now
`com.github.deathrashed.dockmoid`, the reverse-domain form Plasma widgets use. Plasma treats the two as
different widgets, so installing this version does not replace the old one, and widgets you placed
before keep running the old package. To move them, with their settings, to the new package:

```sh
./install.sh                                    # or: kpackagetool6 -t Plasma/Applet -i dockmoid-<version>.plasmoid
systemctl --user stop plasma-plasmashell.service
cp ~/.config/plasma-org.kde.plasma.desktop-appletsrc ~/.config/plasma-org.kde.plasma.desktop-appletsrc.bak
sed -i 's/dockmoid\.plasmoid/com.github.deathrashed.dockmoid/g' ~/.config/plasma-org.kde.plasma.desktop-appletsrc
systemctl --user start plasma-plasmashell.service
kpackagetool6 -t Plasma/Applet -r dockmoid.plasmoid
```

The `sed` line renames the widget's entries in the panel layout, including System Tray entries, and
keeps their settings. If Plasma does not run under systemd on your system, quit it with
`kquitapp6 plasmashell` and start it again with `kstart plasmashell` instead. If anything looks wrong,
stop Plasma, copy the `.bak` file back and start it again. Not wanting to edit the file? Remove the old
widget, add Dockmoid again from Add Widgets, and set it up again. Settings shared with "share with
my other Dockmoid widgets" (Settings → General) are stored outside the widget, in
`~/.local/share/dockmoid`, and the rename does not affect them.

## Main page and navigation

Choose List, Table, Grid or Groups from **View**, then Minimal, Normal, Detailed or Verbose from
**Detail**. Table column selection includes every column regardless of detail level. Containers are
grouped into Running, Stopped and Pending Deployment sections; click a section heading to collapse it.
Under each name, clock icons show how long a container has been up, when it stopped, and (after a
recent recreate) its age; hover for exact dates and the image. Less frequent toolbar actions live in
More, and hidden toolbar actions move there at narrow widths.

The inspector follows the selected container: **Overview** (state, actions and key facts), **Logs**
(live tail; Full Logs opens Details on its Logs tab), **Events** (Dockmoid alerts and engine events),
**Compose** (the service's Compose file, with Validate, Preview, Apply and Edit) and **Health** (its
healthcheck, restarts, last exit, what its logs repeat, recent events and the fixes that apply). Its
tabs sit on a strip at the bottom with Select at the left and Search at the right. Pressing the open
tab again hides the pane; the chevron does the same. The layout button on the strip puts the inspector
below the list or beside it (when the popup is wide enough); drag the divider to size it either way.
A hidden inspector folds to the strip below the list. Home (bottom right of the footer) goes back to
the default view with no filters or selection, and leaves the inspector as it was.
Switching view keeps the selected container in sight; arrow keys in the list move the inspector with
them. When a filter hides the inspected container, the inspector says so and offers Show in List.

Footer counts are clickable filters. If a refresh fails, the footer shows how old the displayed state
is and the list dims until a refresh succeeds; click the note to retry. Saved Views (in the More
menu) remember the view, detail level, search and state filter.

Right-click a container (or press the Menu key) for Details, Web, Logs, Diagnose and Select; Logs With
Others appears while Select mode is on. Then **Manage** (Start, Stop, Pause, Restart, Kill, Update and a Force submenu), Links, its Compose project, Customize (icon, name, pin, preferred URL) and Inspect
diagnostics, including Compare Network With. Buttons and menu entries follow the same rules: an action
that cannot apply to the container's state is not offered, and a greyed-out one says why on hover.

**Restart, Apply and Update are different.** Restart restarts the process with its current
configuration; edits to a Compose file or its environment are not applied. Apply Compose Changes runs
`compose up` for that service, which recreates it only if its configuration or image changed (a stopped
service stays stopped). Update pulls a newer image and recreates the service. Recreating replaces the
container: its mounts are kept, files written inside it are not, and the confirmation lists both.
With Compose 2.17 or newer, Preview Changes shows what Apply would do without doing it.

**Select** (left end of the inspector strip, or a container's menu) adds tick boxes to every view. Picks survive
filtering; the bar says how many are hidden. Start, Stop, Restart and Update each open a review that
lists the containers they apply to and those skipped, with the reason. Results appear per container.
Removal is not offered in bulk.

Search is pinned at the right of the inspector strip. Its look, icon-only and scope are set in More → Search
or Settings → Appearance; the icon inside the field opens the scope choices. Looks:
a button that opens a box above the strip (press it again to close), a button that becomes a field, or a
field always shown. Scope **Containers** filters the list; **Go to** opens a page or container;
**Images** searches Docker Hub and opens the results on Deploy. Go to → Health shows the inspector on
its Health tab, opening it if it was hidden. The scope can also be switched inside the
box. Ctrl+F opens search by default; change or clear the key in Settings → Appearance (it works while the
widget has keyboard focus, not as a desktop-wide shortcut).

Grid, Table and Groups use the keyboard like List: arrows select (the inspector follows), Enter opens
Details, and the Menu key or Shift+F10 opens the actions menu. Active filters appear as chips over the
list; remove one with its ×. Manage Saved Views (More → Saved Views) renames, reorders and deletes views.

## Settings

- **General**: when to check Docker, how often to look for changes (or wait for engine events), and
  "share with my other Dockmoid widgets", which keeps a panel copy and a System Tray copy in step.
- **Appearance**: the popup (views, detail levels, toolbar, search look, scope and shortcut, the
  inspector's default tab and size), the panel icon and label, container rows, and service icons.
- **Storage**: where new Compose projects and bind-mount data go, deployment defaults, and the
  engine's own storage location.
- **Monitoring**: resource warnings, web-page probes, the log watch, image update checks and which
  notifications to show.
- **Connections**: browser links and addresses, the terminal and editor commands, and the "Open in"
  launchers (one per line: label, icon, scope, command; launchers whose program is missing are hidden).
- **Advanced**: the engine (Docker, Podman or a preset), its context, and every command Dockmoid runs,
  each editable.

### Service icons

About 120 common service logos ship with Dockmoid, so most containers get an icon with no download. In
Settings → Appearance → Icons you can download the full Dashboard Icons library (only when you press
the button; it is stored in Dockmoid's data folder with its licence), pick artwork for one container
from Dashboard Icons, selfh.st or a local file, and add rules: `text=icon-name` gives every container
whose name, image or service contains the text that icon, and a rule with no icon hides it.

The "Icon name" of an "Open in" launcher is an icon from your icon theme, such as `konsole` or
`system-file-manager`.

## Compose discovery

Configure the local project root in Storage settings. Discovery considers supported Compose file names
within the configured directory depth, resolves them with `docker compose config --format json`, and
retains only service identities, image references, selected links and bind-path checks. It does not
publish environment variables or resolved configuration bodies. `_archive`, `_backups`, `startup`,
hidden directories, `.git` and `node_modules` are excluded. Missing containers remain visible as
Undeployed (Pending Deployment). Keep Compose files and bind-mounted data in their existing locations.

## Details, logs and commands

Open Details for an overview, usage, container identity, networks and storage, plus published ports,
mounts, health and restart policy. Browser links include ports; hover for the full URL. Logs support
filtering, ANSI colors, errors-only, timestamps, copying and three toggles: **Freeze** holds the display
while you read (newer lines wait until you show them), **Follow** keeps the newest line in view and
**Wrap** wraps long lines. Inspect provides Tree/Raw modes, expansion controls and JSON/value/path
copying. The Run tab executes a command inside an existing container.

## Deploy and resources

Deploy opens Find Image, Configure, Import and Storage tabs. Search shows stars and download counts when
Docker Hub supplies them; the Official filter and sort apply to at most the first 50 returned results.
Similar uses the repository name; Popular sorts returned results by downloads, not a global index.
Review deployment settings before creating a project. Command output appears at the bottom, where its
height can be adjusted; Edit options restores the editable form. After a create, a result card shows
whether the container exists, runs and is healthy, with Details, Logs, Web and Project Folder. An
unfinished form is kept while Plasma runs (in memory only, never on disk, since environment values can be
secrets); Discard Draft clears it. Named volumes and bind mounts are
different kinds of storage; existing project files are never silently overwritten.

Resources lists images, volumes and networks, what uses each, and offers cleanup and image pulls.

## Diagnose

The Diagnose tab is second in a container's Details. Its log section counts error loops, repeated
messages and single errors in the last 300 lines, in sentences. With the log watch on (Settings →
Monitoring, every 15 minutes by default), a few running containers are checked in the background and a
new error loop is announced once.

Diagnose gathers one container's trouble: its state, last exit code with the usual meaning of that
code, out-of-memory kills, restart count, healthcheck output, recent Dockmoid alerts and engine events,
the error and warning lines from the last 300 log lines, and the actions that fit. It reports what the
engine says; it does not guess a cause. Activity entries for crashes, restarts and health changes open
the container on its Logs tab.

Compare Network With (Inspect menu) shows whether two containers share a network, the names each one
answers to there, and their published ports. On a shared network, use the other container's name and
its container port; inside a container, localhost is that container itself. A shared network is
configuration, not proof that a connection works.

Logs With Others merges the logs of the containers you tick (the selected one and its Compose project to
start with) into one timeline for a chosen window, each line labelled with its container.

## Doctor and cleanup

Doctor opens on insights from state Dockmoid already has, and runs no checks until you press Run checks.
Doctor separates Overview, Containers, Compose, Storage and About. Findings include evidence and
specific actions rather than a blanket repair. Preview commands and affected services first. Plan only
means Docker provides no native dry run, so the preview is not a guarantee. Select actions explicitly,
then inspect progress, output and results. Doctor does not start all configured services automatically.

Cleanup defaults remove dangling images and build cache. Stopped-container removal is a separate,
explicit option; selecting it deletes container instances, not Compose files or bind-mounted data.
Named volumes are retained. Removing all unused images is also explicit; a configured Compose service
can still reference an image without having a container. Resources distinguishes these relationships.
Do not treat Unknown or zero existing containers as proof that an image is unwanted.
Reclaimable sizes are the engine's estimate; images that share layers can make them larger than what a
cleanup frees. After a cleanup, the output reports the measured change in disk use.

Services behind a Compose profile are optional by design: they are marked in the list, and Doctor
reports them as information rather than a problem.

## Refresh and troubleshooting

Change checks, full-list heartbeat and usage samples have separate intervals. Statistics run while
open unless background statistics are enabled. Duplicate in-flight stats requests are suppressed.
Successful resource inventories and Doctor checks may be reused for 30 seconds on reopen; explicit
Refresh/Check bypasses this cache. Changing connection resets the relevant caches and cancels stale
results. Two Dockmoid instances still own independent backends; reduce background work when using both
panel and tray copies. No global cross-instance cache or memory-saving benchmark is claimed.

When the engine cannot be reached, the placeholder explains the cause for this kind of connection
(local Docker, rootless Docker, Podman or a remote host) and offers what applies: a command to copy,
Try Again, Connection Settings, or Start for a local system Docker.

For a bug report, use **More → Problem Report…**. It collects versions, the connection type and recent
errors, replaces your home folder, user name, remote host names and IP addresses, and shows the result
for review before you copy it. Check the error lines yourself, and add the steps to reproduce.
