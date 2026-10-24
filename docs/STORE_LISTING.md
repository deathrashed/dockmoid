# KDE Store listing — ready to paste

## Fields

- Name: Dockmoid
- Version: 2.4.0
- Add-on type: Plasma 6 widget / Plasmoid
- Category in metadata: System Information
- License: GPL-3.0-or-later
- Homepage/source: https://github.com/deathrashed/dockmoid
- Bugs: https://github.com/deathrashed/dockmoid/issues
- Tags: plasma, docker, podman, containers, compose, monitoring
- Upload: dockmoid-2.4.0.plasmoid (ZIP-format KPackage; metadata.json at archive root)

## Short description

Container status, Compose services and reviewable diagnostics in your KDE Plasma panel or system tray.

## Description

Dockmoid brings Docker and Podman container controls into KDE Plasma 6. Use List, Table, Grid or Groups
with collapsible Running, Stopped and Pending Deployment sections. Keep configured Docker Compose
services visible even when their containers have been removed, and create only the service you choose.

An inspector below or beside the list follows the selected container with its overview, live logs,
events, Compose file and health. A Diagnose tab gathers exit codes, restarts, health output and the log
lines worth reading first, without guessing a cause. Open Details for usage, ports, networks, mounts, ANSI-colored logs, JSON tree/raw
inspection and commands. Start, Stop, Restart, Pause, Kill and Update follow the same rules in every
view. Doctor presents evidence and selected action plans with command previews and visible results;
no blanket automatic repair runs.

Docker Hub search shows star/download metadata, an Official filter and sorting of returned results.
Resource inventories distinguish existing-container use from configured Compose references. Cleanup
preserves stopped containers and volumes by default; removing stopped instances is a separate choice.

Requires Plasma 6 and accessible Docker or Podman command-line tools. Python 3 is needed for image
search and Compose discovery; local Compose workflows need Docker Compose. Tested on Plasma 6.7.5.
Podman support is limited to core container controls and read-only inventories; local Docker Compose
features and selected Docker-specific diagnostics are unavailable for Podman. Image sorting covers
up to 50 returned results, not all Docker Hub images. Commands run with your account's permissions.

## Screenshots and submission

Use docs/assets/overview.png, grid.png, detail.png, deploy.png, resources.png and narrow.png. These show
production QML with example data, rather than a personal host; caption them accordingly. The project
icon is contents/icons/dockmoid.png.

Select the Plasma 6 category shown by the live upload form and supply its requested image dimensions,
download architecture/type and source/license fields. The Store assigns the listing URL; add that
actual URL to README.md after submission rather than guessing an ID. Uploading/submitting is separate
from committing this release preparation. No listing has been submitted by this workflow.

References: https://develop.kde.org/docs/plasma/widget/setup/ and
https://develop.kde.org/docs/plasma/widget/properties/ describe metadata/package structure. The live
Store form remains authoritative for its submission fields: https://store.kde.org/
