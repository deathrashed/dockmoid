<div align="center">
<p align="center"><img src="contents/icons/dockmoid.png" width="88" alt="Dockmoid logo"></p>
<p align="center">
<picture>
<source media="(prefers-color-scheme: dark)" srcset="https://shieldcn.dev/header/graph.svg?title=DOCKMOID&subtitle=Your+containers.+In+your+panel.&mode=dark&align=center&logo=docker&logoColor=2560ff&theme=blue&height=160&border=false" />
<img alt="DOCKMOID" src="https://shieldcn.dev/header/graph.svg?title=DOCKMOID&subtitle=Your+containers.+In+your+panel.&mode=light&align=center&logo=docker&logoColor=2560ff&theme=blue&height=160&border=false" />
</picture>
</p>
<p align="center"><strong>Monitor containers, manage Compose services and diagnose problems from KDE Plasma.</strong></p>
<p align="center"><a href="https://kde.org/plasma-desktop/"><picture><source media="(prefers-color-scheme: dark)" srcset="https://shieldcn.dev/badge/Plasma%206.svg?variant=secondary&size=sm&logo=kdeplasma&mode=dark&theme=blue&logoColor=ffffff" /><img alt="Plasma 6" src="https://shieldcn.dev/badge/Plasma%206.svg?variant=secondary&size=sm&logo=kdeplasma&mode=light&theme=blue&logoColor=ffffff" /></picture></a><a href="https://docs.docker.com/"><picture><source media="(prefers-color-scheme: dark)" srcset="https://shieldcn.dev/badge/Docker.svg?variant=secondary&size=sm&logo=docker&mode=dark&theme=blue&logoColor=ffffff" /><img alt="Docker" src="https://shieldcn.dev/badge/Docker.svg?variant=secondary&size=sm&logo=docker&mode=light&theme=blue&logoColor=ffffff" /></picture></a><a href="https://podman.io/"><picture><source media="(prefers-color-scheme: dark)" srcset="https://shieldcn.dev/badge/Podman.svg?variant=secondary&size=sm&logo=podman&mode=dark&theme=blue&logoColor=ffffff" /><img alt="Podman" src="https://shieldcn.dev/badge/Podman.svg?variant=secondary&size=sm&logo=podman&mode=light&theme=blue&logoColor=ffffff" /></picture></a></p>
<p align="center"><a href="#quick-start">Quick start</a> | <a href="#features">Features</a> | <a href="#screenshots">Screenshots</a> | <a href="docs/USER_GUIDE.md">Guide</a> | <a href="CHANGELOG.md">Changelog</a> | <a href="#license">License</a></p>
</div>


## <img src="docs/assets/headers/download.svg" height="22" alt="Install"> Quick Start

KDE Plasma 6 and an accessible Docker or Podman CLI are required. Python 3 and Docker Compose
are needed for Compose discovery/recreation; Python 3 is also needed for Docker Hub search.
Tested on Plasma 6.7.5. Older Plasma 6 versions have not all been exercised.

```sh
git clone https://github.com/deathrashed/dockmoid.git
cd dockmoid
./install.sh
```

Add **Dockmoid** through Plasma's widget browser, or enable it in **System Tray Settings → Entries**.
Choose the engine and connection in Dockmoid Settings, then run **Test connection**.
The installer updates only the current user's package and restores the previous package if installation fails.

<details>
<summary><strong>Install or update a downloaded package</strong></summary>

Download the `.plasmoid` file from the project's release assets when available.

```sh
# First installation
kpackagetool6 -t Plasma/Applet -i dockmoid-2.4.0.plasmoid
# Update an existing installation
kpackagetool6 -t Plasma/Applet -u dockmoid-2.4.0.plasmoid
```

For KDE Store publication, the same `.plasmoid` is the upload package. A Store listing is not yet
linked here because its public URL has not been assigned. Remove Dockmoid using Plasma's widget tools.

</details>

## <img src="docs/assets/headers/layout-dashboard.svg" height="22" alt="Features"> Features

| Workflow | Available controls |
| --- | --- |
| Containers | List, Table, Grid and Groups; Minimal, Normal, Detailed and Verbose information |
| Main view | Resizable Running, Needs attention and Inactive panes; Cards, List or Icons for Inactive |
| Preview | Cached summary on hover or selection; optional embedded Doctor, New and Resources panes |
| Diagnosis | Doctor findings, evidence, selected repair plans, command previews and visible results |
| Details | Resource graphs, ports, mounts, Compose identity, logs, Inspect Tree/Raw and Run tab |
| Images | Framed Docker Hub results, star/download counts, Official filter, sort and related searches |
| Resources | Images, volumes and networks; existing-container use distinguished from Compose references |
| Monitoring | Health/crash alerts, resource thresholds, web probes and configurable polling intervals |
| Desktop | Panel and system tray support, detachable window, saved views and per-view pane sizes |

Compose discovery keeps configured services visible as **Not created** when their containers have been
removed. **Stopped** starts an existing container; **Not created** creates and starts only the chosen
service. Nothing starts every configured service automatically.

## <img src="docs/assets/headers/image.svg" height="22" alt="Screenshots"> Screenshots

These previews render the production QML with demonstration records, without exposing a personal host.

![Dockmoid container overview with vertically stacked service sections](docs/assets/overview.png)

<details>
<summary><strong>Images, deployment and Doctor</strong></summary>

![Images and new containers page with collapsible command output](docs/assets/new-containers.png)

![Doctor with evidence and reviewable actions](docs/assets/doctor.png)

</details>

## <img src="docs/assets/headers/settings.svg" height="22" alt="Configure"> Configure

The gear beside **Services** controls the main-page preview and embedded tools. Drag the section
separators to resize; sizes, expansion, density and inactive presentation are saved per view.
At narrow widths, preview moves below the services and toolbar actions move into **More**.

In **Settings**, configure the connection, storage paths, monitoring and command presets.
See the [user guide](docs/USER_GUIDE.md) for cleanup choices, logs, connection troubleshooting and refresh behavior.

> [!NOTE]
> Cleanup preserves stopped containers and volumes by default. Removing stopped containers is an
> explicit choice. Docker access and customized shell commands carry the permissions of your account.

## <img src="docs/assets/headers/info.svg" height="22" alt="Compatibility"> Compatibility

- Docker supports local Compose discovery and guided deployments. Discovery skips `_archive`, `_backups`,
  `startup`, hidden directories, `.git` and `node_modules`; it is not a recursive backup/config importer.
- Podman supports container listing, stats, events, logs, inspect, direct controls, pull and read-only
  image/volume/network inventories. Compose, registry digest checks, restart-policy editing, full disk
  summaries and system-service controls are not enabled for Podman.
- Metrics depend on engine output; unavailable metrics are not evidence of zero usage.
- Image search sorts the first 50 returned Docker Hub results. Popular is not a global ranking, and
  Similar searches by repository name. Docker Hub requires an internet connection.
- Doctor uses **Plan only** where the engine has no dry-run operation. A command preview cannot
  guarantee the outcome; inspect the selected actions before execution.
- No low-memory or measured before/after performance guarantee is made. Background statistics are
  optional, expensive reads are gated, and diagnostic/resource pages reuse short-lived cached results.

## <img src="docs/assets/headers/braces.svg" height="22" alt="Development"> Development

```text
contents/
  ui/          # Plasma views, settings and backend components
  lib/         # Parsing, commands and presentation helpers
  scripts/     # Standard-library Python discovery and registry helpers
  assets/      # Bundled interface and service artwork, with licenses
tests/         # Isolated regression and packaging checks
docs/          # User guide, screenshots and Store submission text
packaging/     # AppStream metadata and package manifest
```

Read [CONTRIBUTING.md](CONTRIBUTING.md) for prerequisites and checks, [SECURITY.md](SECURITY.md)
for reporting guidance, and [RELEASE_CHECKLIST.md](RELEASE_CHECKLIST.md) for packaging and upload steps.
The [2.4.0 release notes](docs/RELEASE_NOTES.md) describe this release; artifact creation does not upload it.

Bundled artwork licenses and historical attribution are in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

## <a href="https://opensource.org/license/GPL-3.0"><img src="docs/assets/license/logo.svg" height="20" alt="GPL"></a> License

<div align="center">

[**𝗚𝗣𝗟 𝗟𝗜𝗖𝗘𝗡𝗦𝗘**](LICENSE)

<a href="LICENSE"><img src="docs/assets/license/badge.svg" alt="GPL Badge" width="180"></a>

**𝗖𝗢𝗣𝗬𝗥𝗜𝗚𝗛𝗧 © 𝟮𝟬𝟮𝟲 𝗗𝗘𝗔𝗧𝗛𝗥𝗔𝗦𝗛𝗘𝗗**

</div>
