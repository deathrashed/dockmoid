<div align="center">

<p align="center"><img alt="dockmoid" src="https://shieldcn.dev/header/graph.svg?title=dockmoid&subtitle=deploy+%C2%B7+monitor+%C2%B7+control&logo=https%3A%2F%2Fraw.githubusercontent.com%2Fdeathrashed%2Fdockmoid%2Fmain%2Fcontents%2Ficons%2Fdockmoid.png&mode=dark&align=left&font=jetbrains-mono"></p>

<p align="center"><strong>Monitor containers, manage Compose services and diagnose problems from KDE Plasma.</strong></p>

<p align="center"><a href="https://kde.org/plasma-desktop/"><picture><source media="(prefers-color-scheme: dark)" srcset="https://shieldcn.dev/badge/Plasma%206.svg?variant=outline&size=sm&logo=kdeplasma&mode=dark&theme=blue&logoColor=ffffff" /><img alt="Plasma 6" src="https://shieldcn.dev/badge/Plasma%206.svg?variant=outline&size=sm&logo=kdeplasma&mode=light&theme=blue&logoColor=ffffff" /></picture></a> <a href="https://docs.docker.com/"><picture><source media="(prefers-color-scheme: dark)" srcset="https://shieldcn.dev/badge/Docker.svg?variant=outline&size=sm&logo=docker&mode=dark&theme=blue&logoColor=ffffff" /><img alt="Docker" src="https://shieldcn.dev/badge/Docker.svg?variant=outline&size=sm&logo=docker&mode=light&theme=blue&logoColor=ffffff" /></picture></a> <a href="https://podman.io/"><picture><source media="(prefers-color-scheme: dark)" srcset="https://shieldcn.dev/badge/Podman.svg?variant=outline&size=sm&logo=podman&mode=dark&theme=blue&logoColor=ffffff" /><img alt="Podman" src="https://shieldcn.dev/badge/Podman.svg?variant=outline&size=sm&logo=podman&mode=light&theme=blue&logoColor=ffffff" /></picture></a> <a href="#license"><picture><source media="(prefers-color-scheme: dark)" srcset="https://shieldcn.dev/badge/GPL%203.svg?variant=outline&size=sm&logo=lu%3AScale&mode=dark&theme=blue&logoColor=ffffff" /><img alt="GPL-3.0 license" src="https://shieldcn.dev/badge/GPL%203.svg?variant=outline&size=sm&logo=lu%3AScale&mode=light&theme=blue&logoColor=ffffff" /></picture></a></p>

<p align="center"><a href="#quick-start">Quick start</a> | <a href="#features">Features</a> | <a href="#screenshots">Screenshots</a> | <a href="#configure">Configure</a> | <a href="#compatibility">Compatibility</a> | <a href="#development">Development</a> | <a href="docs/USER_GUIDE.md">User guide</a> | <a href="CHANGELOG.md">Changelog</a> | <a href="#license">License</a></p>

</div>

---

## <img src="https://api.iconify.design/lucide/download.svg?color=%232560ff" height="22" alt="Install"> Quick Start

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

Upgrading from a version installed as `dockmoid.plasmoid`? The package ID is now
`com.github.deathrashed.dockmoid`; see [Upgrading from dockmoid.plasmoid](docs/USER_GUIDE.md#upgrading-from-dockmoidplasmoid)
to move existing widgets and their settings.

For KDE Store publication, the same `.plasmoid` is the upload package. A Store listing is not yet
linked here because its public URL has not been assigned. Remove Dockmoid using Plasma's widget tools.

</details>

## <img src="https://api.iconify.design/lucide/layout-dashboard.svg?color=%23759bff" height="22" alt="Features"> Features

| Workflow | Available controls |
| --- | --- |
| Containers | List, Table, Grid and Groups; Minimal, Normal, Detailed and Verbose information; collapsible state sections |
| Inspector | Below or beside the list for the selected container: Overview, live Logs, Events, its Compose file and Health |
| Actions | Start, Stop, Restart, Pause, Kill, Update and Apply Compose Changes everywhere, with one set of rules and a reason when greyed out |
| Details | Overview, usage graphs, ports, networks, mounts, logs, Inspect Tree/Raw and a Run tab |
| Deploy | Docker Hub search with star/download counts, an Official filter, guided Compose deployment and import |
| Resources | Images, volumes and networks, with what uses each one, cleanup and image pulls |
| Diagnosis | Doctor insights and checks, a Diagnose tab per container with a log digest, background log watch, network comparison, merged logs and a redacted problem report |
| Bulk actions | Select Several, then review exactly which containers Start/Stop/Restart/Update apply to |
| Monitoring | Health and crash alerts, resource thresholds, web probes, an Activity log and event-driven refresh |
| Desktop | Panel and system tray, a detachable window, saved views and settings shared between widgets |

Compose discovery keeps configured services visible as **Undeployed** (Pending Deployment) when their
containers have been removed. **Start** starts an existing container; **Create and start** creates only
the chosen service. Nothing starts every configured service automatically.

## <img src="https://api.iconify.design/lucide/image.svg?color=%232560ff" height="22" alt="Screenshots"> Screenshots

These previews render the production QML with demonstration records, without exposing a personal host.

![Dockmoid container list in Needs Attention, Running, Stopped and Pending Deployment sections, with the inspector beside it](docs/assets/overview.png)

<details>
<summary><strong>Grid, details, deployment, resources and a narrow tray popup</strong></summary>

| Grid | Details |
| --- | --- |
| ![Grid view with state, usage and actions on each card](docs/assets/grid.png) | ![Container details with overview, usage, container and network sections](docs/assets/detail.png) |
| **Deploy** | **Resources** |
| ![Deploy page with Docker Hub search results](docs/assets/deploy.png) | ![Resources page listing images and what uses them](docs/assets/resources.png) |

<p align="center"><img src="docs/assets/narrow.png" width="300" alt="The same view in a narrow system tray popup"><br><em>The same view in a narrow System Tray popup</em></p>

</details>

## <img src="https://api.iconify.design/lucide/settings.svg?color=%23759bff" height="22" alt="Configure"> Configure

Pick the view and detail level from **View** and **Detail** in the toolbar; Filter and Sort sit beside
them. Select, the inspector's tabs (including Health) and Search sit on the inspector strip, which can
go below the list or beside it; drag the divider to size the inspector, or collapse it. Refresh and
Home are at the two ends of the footer. Sizes, collapsed sections and the inspector tab are saved.
Right-click a container for every action, its links and its Compose project. At narrow widths, toolbar
actions move into **More**.

**Settings** has six pages: General, Appearance (including service icons), Storage, Monitoring,
Connections and Advanced (every engine command). See the [user guide](docs/USER_GUIDE.md) for cleanup choices, logs, connection troubleshooting
and refresh behavior.

> [!NOTE]
> Cleanup preserves stopped containers and volumes by default. Removing stopped containers is an
> explicit choice. Docker access and customized shell commands carry the permissions of your account.

## <img src="https://api.iconify.design/lucide/info.svg?color=%232560ff" height="22" alt="Compatibility"> Compatibility

| Capability | Docker | Podman |
| --- | --- | --- |
| Container list, stats, events, logs, inspect and direct controls | Yes | Yes |
| Image pull | Yes | Yes |
| Image, volume and network inventories | Yes | Read-only |
| Compose discovery and guided deployment | Yes | No |
| Registry digest checks | Yes | No |
| Restart-policy editing | Yes | No |
| Full disk summaries and system-service controls | Yes | No |

> [!TIP]
> Compose discovery skips `_archive`, `_backups`, `startup`, hidden directories, `.git` and
> `node_modules`. It is not a recursive backup or config importer.

<details>
<summary><strong>Remote engines, metrics, search and Doctor limits</strong></summary>

- With a remote engine (SSH or TCP), Compose files are not read or edited locally: their paths name
  files on the remote host.
- Metrics depend on engine output; unavailable metrics are not evidence of zero usage.
- Image search sorts the first 50 returned Docker Hub results. Popular is not a global ranking, and
  Similar searches by repository name. Docker Hub requires an internet connection.
- Doctor uses **Plan only** where the engine has no dry-run operation. A command preview cannot
  guarantee the outcome; inspect the selected actions before execution.
- No low-memory or measured before/after performance guarantee is made. Background statistics are
  optional, expensive reads are gated, and diagnostic/resource pages reuse short-lived cached results.

</details>

## <img src="https://api.iconify.design/lucide/braces.svg?color=%23759bff" height="22" alt="Development"> Development

```text
dockmoid/
├── contents/
│   ├── config/        # Settings schema (main.xml) and the list of settings pages
│   ├── ui/
│   │   ├── backend/     # Engine reads and actions, update checks, deployment, Doctor
│   │   ├── views/       # Pages: home with the inspector, Details, Diagnose, Doctor, Deploy
│   │   ├── components/  # Rows, tables, grid tiles, buttons and dialogs
│   │   └── config/      # Settings pages
│   ├── lib/           # Pure rules with Node tests: actions, status, inspector layout, pages
│   ├── scripts/       # Standard-library Python helpers: Compose discovery, Hub search
│   └── assets/        # Interface icons and service logos, with their licences
├── tests/             # Node, Python and QML runtime checks
├── docs/              # User guide, screenshots and Store listing
├── translate/         # Translation template and extract/build scripts
├── packaging/         # AppStream metadata and release manifest
└── install.sh         # Transactional per-user installer
```

Read [CONTRIBUTING.md](CONTRIBUTING.md) for prerequisites and checks, [SECURITY.md](SECURITY.md)
for reporting guidance, and [RELEASE_CHECKLIST.md](RELEASE_CHECKLIST.md) for packaging and upload steps.
[CHANGELOG.md](CHANGELOG.md) lists changes since the [2.4.0 release notes](docs/RELEASE_NOTES.md).

Bundled artwork licenses and historical attribution are in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

## <a href="https://opensource.org/license/GPL-3.0"><img src="https://api.iconify.design/lucide/scale.svg?color=%232560ff" height="22" alt="GPL-3.0 license website"></a> License

<div align="center">

[**𝗚𝗡𝗨 𝗚𝗣𝗟 𝗟𝗜𝗖𝗘𝗡𝗦𝗘**](LICENSE)

<a href="LICENSE"><img src="docs/assets/license/badge.svg" alt="GPL Badge" width="180"></a>

**𝗖𝗢𝗣𝗬𝗥𝗜𝗚𝗛𝗧 © 𝟮𝟬𝟮𝟲 𝗗𝗘𝗔𝗧𝗛𝗥𝗔𝗦𝗛𝗘𝗗**

</div>
