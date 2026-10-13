import QtQuick
import org.kde.notification

import QtCore

import "../../lib/parsers.js" as Parsers
import "../../lib/icons.js" as Icons
import "../../lib/selfhst.js" as SelfHst

/*
 * DockerBackend — everything the UI is allowed to know about Docker.
 *
 * All docker/podman access funnels through here, which keeps the QML views
 * free of command strings and gives us exactly one place where quoting,
 * placeholder expansion and error reporting are handled.
 *
 * Commands are all shell fragments, so they honour $DOCKER_HOST, contexts,
 * podman aliases and the user's PATH exactly like a terminal would. The only
 * rule is: never interpolate raw container data into a shell string.
 */
Item {
    id: backend

    // See CommandRunner: an Item is needed to own the ListModel child.
    visible: false
    width: 0
    height: 0

    /* Set by main.qml — the serialized job runner shared by the whole plasmoid. */
    property var runner: null

    property var cfg: plasmoid.configuration

    // ----------------------------------------------------------- state ----
    property bool engineActive: false
    /* false until the very first detection finishes, so the UI can tell
       "not started yet" apart from "the daemon is down". */
    property bool engineKnown: false
    property bool refreshing: false
    property string lastError: ""
    property string actionError: ""

    property int running: 0
    property int total: 0
    property int stopped: 0
    property int pausedCount: 0
    property int unhealthy: 0
    property double cpuSum: 0
    property double memSum: 0
    property int pids: 0

    property var engineInfo: ({})
    property var diskUsage: []
    property bool diskUsageKnown: false

    /* Bumped whenever the container data changes, so detail views can bind to
       it and re-resolve their record instead of holding a stale snapshot. */
    property int revision: 0

    /* Title of the most recent output payload; lets a page decide whether an
       outputReady() was meant for it. */
    property string lastOutputTitle: ""

    /* Ordered list of container records; the ListModel is a mirror of it. */
    property var records: []

    readonly property bool busy: runner ? runner.busy : false

    signal refreshed()
    signal engineStateChanged(bool active)
    /* Emitted when something the user did finished (or failed) so the UI can
       surface a notification. */
    signal actionDone(string title, string message, bool ok)
    signal outputReady(string title, string content)

    onActionDone: function (title, message, ok) {
        actionError = ok ? "" : title + ": " + message
        notify(title, message)
    }

    ListModel {
        id: model
    }
    property alias containerModel: model

    // ------------------------------------------------------- internals ----
    property int pendingTasks: 0
    property bool wantDiskUsage: false

    function beginTask() {
        pendingTasks++
        refreshing = true
    }

    function endTask() {
        pendingTasks = Math.max(0, pendingTasks - 1)
        if (pendingTasks === 0) {
            refreshing = false
            refreshed()
        }
    }

    /* Substitute {placeholders} in a command. split/join rather than replace so
       a value containing "$" or "\" can never be re-interpreted. */
    function expand(cmd, vars) {
        if (!cmd) return ""
        var out = String(cmd)
        for (var key in vars) {
            out = out.split("{" + key + "}").join(String(vars[key]))
        }
        return out
    }

    // =================================================== refresh cycle ====

    /* Timer-driven poll. Skips while a previous cycle is still in flight so a
       slow `docker stats` cannot pile up cycles behind it. */
    function poll() {
        if (refreshing) return
        refresh({ "withStats": false })
    }

    /*
     * opts.withStats — also refresh the expensive per-container stats.
     * opts.withDisk  — also refresh `docker system df` (slow, opt-in).
     * opts.force     — run even if the engine was previously down.
     */
    function refresh(opts) {
        opts = opts || {}
        if (!runner) return
        if (refreshing) return
        if (engineKnown && !engineActive && !opts.force) return

        beginTask()
        runner.run(cfg.checkActiveCommand, "detect", function (code, out, err) {
            var active = detectActive(code, out)
            if (active !== backend.engineActive) {
                backend.engineActive = active
                backend.engineStateChanged(active)
            }
            backend.engineKnown = true
            if (!active) {
                backend.onEngineDown()
                backend.endTask()
                return
            }
            backend.fetchList()
            backend.fetchInfo()
            if (opts.withStats !== false) backend.fetchStats()
            if (opts.withDisk) backend.fetchDiskUsage()
            backend.endTask()
        })
    }

    /*
     * The configured check command decides how the daemon is probed, so the
     * success test has to work for more than one flavour:
     *   - `docker info --format …`   -> exit 0 means healthy
     *   - `systemctl is-active docker` -> exit 0 AND "active" on stdout
     * Exit status is the primary signal; the stdout test only demotes a
     * result, so a command that prints nothing useful still works.
     */
    function detectActive(code, out) {
        if (code !== 0) return false
        var text = String(out || "").trim()
        if (text === "") return true
        if (/^(inactive|failed|deactivating|activating|unknown)$/i.test(text)) return false
        return true
    }

    function onEngineDown() {
        records = []
        syncModel()
        engineInfo = {}
        diskUsage = []
        diskUsageKnown = false
        running = 0
        total = 0
        stopped = 0
        pausedCount = 0
        unhealthy = 0
        cpuSum = 0
        memSum = 0
        pids = 0
        lastError = ""
        if (runner) runner.cancelAll()
    }

    function fetchList() {
        beginTask()
        runner.run(cfg.listCommand, "list", function (code, out, err) {
            if (code !== 0) {
                lastError = err || String(out || "").trim()
            } else {
                lastError = ""
                records = Parsers.parseContainers(out)
                // Running containers float to the top, everything else is
                // alphabetical. Views may re-sort on top of this.
                for (var i = 0; i < records.length; i++) {
                    records[i].sortKey = (records[i].isRunning ? "0" : "1")
                        + records[i].name.toLowerCase()
                }
                records.sort(function (a, b) {
                    return a.sortKey < b.sortKey ? -1 : (a.sortKey > b.sortKey ? 1 : 0)
                })
                applyStatsToRecords()
                syncModel()
                recomputeTotals()
                revision++
            }
            endTask()
        })
    }

    function fetchStats() {
        beginTask()
        runner.run(cfg.usageCommand, "stats", function (code, out, err) {
            if (code === 0) {
                statsCache = Parsers.parseStats(out)
                applyStatsToRecords()
                syncModel()
                recomputeTotals()
                revision++
            }
            endTask()
        })
    }

    /* `docker info` walks the whole store and is by far the most expensive
       read we do, so it is throttled independently of the list poll. */
    property double lastInfoMs: 0

    function fetchInfo() {
        var now = Date.now()
        if (now - lastInfoMs < 30000) return
        lastInfoMs = now
        beginTask()
        runner.run(cfg.infoCommand, "info", function (code, out, err) {
            if (code === 0) engineInfo = Parsers.parseInfo(out)
            endTask()
        })
    }

    function fetchDiskUsage() {
        if (diskUsageKnown) return
        beginTask()
        runner.run(cfg.systemDfCommand, "systemdf", function (code, out, err) {
            if (code === 0) {
                diskUsage = Parsers.parseSystemDf(out)
                diskUsageKnown = true
            }
            endTask()
        })
    }

    property var statsCache: ({})

    function applyStatsToRecords() {
        Parsers.applyStats(records, statsCache)
    }

    /* Fields whose value can change without the container list changing. */
    function copyRow(rec) {
        // searchKey is pre-joined so one regex matches name, image, project,
        // ports and id at once, and the view never has to scan a list of
        // candidate fields on every keystroke.
        var search = (rec.name + " " + rec.image + " " + rec.project + " "
            + rec.ports + " " + rec.id).toLowerCase()
        return {
            "id": rec.id,
            // `id` is a reserved word in QML, so delegates that need the
            // container id as a declared role use this duplicate instead.
            "containerKey": rec.id,
            "name": rec.name, "image": rec.image,
            "command": rec.command, "createdAt": rec.createdAt,
            "runningFor": rec.runningFor, "containerState": rec.state,
            "status": rec.status, "health": rec.health,
            "isRunning": rec.isRunning, "localVolumes": rec.localVolumes,
            "networks": rec.networks, "mounts": rec.mounts, "ports": rec.ports,
            "size": rec.size, "platform": rec.platform,
            "project": rec.project, "service": rec.service,
            "composeFiles": rec.composeFiles, "composeWorkDir": rec.composeWorkDir,
            "composeProfile": rec.composeProfile,
            "cpu": rec.cpu, "mem": rec.mem, "memU": rec.memU,
            "blockio": rec.blockio, "netio": rec.netio, "pids": rec.pids,
            "cpuPct": rec.cpuPct, "memPct": rec.memPct,
            "sortKey": rec.sortKey,
            // Groups a compose project together; a container that belongs to
            // no project is its own group, so the section view still works for
            // plain `docker run` containers. Must match groupKeyOf().
            "groupKey": groupKeyOf(rec),
            "searchKey": search
        }
    }

    property var rowKeys: ["id", "containerKey", "name", "image", "command", "createdAt",
                   "runningFor", "containerState", "status", "health", "isRunning",
                   "localVolumes", "networks", "mounts", "ports", "size",
                   "platform", "project", "service", "composeFiles",
                   "composeWorkDir", "composeProfile", "cpu", "mem", "memU",
                   "blockio", "netio", "pids", "cpuPct", "memPct", "sortKey",
                   "groupKey", "searchKey"]

    function rowChanged(existing, row) {
        for (var i = 0; i < rowKeys.length; i++) {
            var k = rowKeys[i]
            if (existing[k] !== row[k]) return true
        }
        return false
    }

    /*
     * Mirror `records` into the ListModel by id.
     *
     * The original implementation re-inserted and re-moved rows on every
     * tick, which was both O(n^2) and prone to shuffling delegates out from
     * under the user. Here the model is only touched where it actually differs,
     * so an expanded row or a selection survives a refresh.
     */
    function syncModel() {
        var wanted = {}
        for (var i = 0; i < records.length; i++) wanted[records[i].id] = true

        for (var k = model.count - 1; k >= 0; k--) {
            if (!wanted[model.get(k).id]) model.remove(k)
        }

        for (var j = 0; j < records.length; j++) {
            var row = copyRow(records[j])
            var at = -1
            for (var m = 0; m < model.count; m++) {
                if (model.get(m).id === row.id) { at = m; break }
            }
            if (at === -1) {
                model.insert(j, row)
            } else if (at !== j) {
                model.move(at, j, 1)
                if (rowChanged(model.get(j), row)) model.set(j, row)
            } else if (rowChanged(model.get(j), row)) {
                model.set(j, row)
            }
        }
    }

    function recomputeTotals() {
        var agg = Parsers.aggregate(records)
        total = records.length
        running = agg.running
        pausedCount = agg.paused
        unhealthy = agg.unhealthy
        cpuSum = agg.cpuSum
        memSum = agg.memSum
        pids = agg.pids
        stopped = Math.max(0, records.length - running - pausedCount)
    }

    function findRecord(id) {
        for (var i = 0; i < records.length; i++) {
            if (records[i].id === id) return records[i]
        }
        return null
    }

    // =============================================== presentation helpers ==

    /* Published ports treated as https, parsed once from the config string. */
    readonly property var httpsPorts: {
        var raw = String(cfg.httpsPorts || "").split(",")
        var out = []
        for (var i = 0; i < raw.length; i++) {
            var v = parseInt(raw[i].trim(), 10)
            if (!isNaN(v)) out.push(v)
        }
        return out
    }

    /* User overrides first, bundled rules after, so an override always wins. */
    readonly property var iconMap: Icons.build(cfg.customIcons)

    /*
     * Optional user icon library (the provider artwork, e.g. ~/pictures/selfhst).
     *
     * QML cannot list a directory, so the *names* are baked into
     * lib/selfhst.js while the artwork stays on disk. A file whose name equals
     * the image's basename always wins over the substring rules, because the
     * user's own artwork for the service they actually run is the most specific
     * match available.
     */
    readonly property bool useIconLibrary: cfg.serviceIconDirectory !== ""
        && cfg.coloredServiceIcons

    readonly property string iconLibraryDir: Icons.expandHome(
        cfg.serviceIconDirectory, homeDir)

    /*
     * QML has no environment access, so the home directory comes from Qt.
     *
     * StandardPaths returns a *URL* ("file:///home/rd"), not a path. Stripped
     * back to a path here because the library directory is concatenated with
     * plain "/" and handed to the image provider, which wants a real path.
     */
    readonly property string homeDir: String(
        StandardPaths.writableLocation(StandardPaths.HomeLocation))
        .replace(/^file:\/\//, "")

    readonly property var libraryNames: useIconLibrary ? SelfHst.nameSet() : {}

    /* Basename of an image ref: "lscr.io/linuxserver/plex:latest" -> "plex". */
    function imageBasename(image) {
        if (!image) return ""
        var s = String(image)
        var slash = s.lastIndexOf("/")
        if (slash >= 0) s = s.slice(slash + 1)
        // Drop a tag or digest, but keep a registry host that had no slash.
        var colon = s.indexOf(":")
        if (colon >= 0) s = s.slice(0, colon)
        return s.toLowerCase()
    }

    /* Full path of the user's artwork for this image, or "" when there is none. */
    function libraryIconPath(image, containerName) {
        if (!useIconLibrary) return ""
        var ownName = String(containerName || "").toLowerCase()
        if (libraryNames[ownName]) return iconLibraryDir + "/" + ownName + ".svg"
        var base = imageBasename(image)
        if (base === "") return ""
        if (!libraryNames[base] && base === "pihole" && libraryNames["pi-hole"])
            base = "pi-hole"
        if (!libraryNames[base]) return ""
        return iconLibraryDir + "/" + base + ".svg"
    }

    function serviceIconName(image) {
        return Icons.match(iconMap, image)
    }

    /*
     * Returns an *absolute* URL, not a relative path.
     *
     * The path was previously "../../assets/services/<name>.svg", which is wrong:
     * a bare relative string handed to a url-typed property is resolved against
     * the directory of the QML file that *assigns* it — ContainerRow.qml in
     * ui/components/ — not against the file that produced the string. From
     * there "../../" lands outside contents/ entirely, so no glyph ever loaded
     * and every row fell back to a bare state dot.
     *
     * Qt.resolvedUrl() is anchored to this file's own location, so the URL is
     * correct wherever it is consumed.
     */
    function serviceIconUrl(image, containerName) {
        var own = libraryIconPath(image, containerName)
        if (own !== "") return "file://" + own
        var name = serviceIconName(image)
        if (name === "") return ""
        return Qt.resolvedUrl("../../assets/services/" + name + ".svg")
    }

    /*
     * Whether this image should be drawn in full colour. The user's own
     * artwork carries real brand colours and is shown as-is; the bundled glyphs
     * are flat silhouettes meant to be used as themed masks.
     */
    function serviceIconIsColored(image, containerName) {
        return libraryIconPath(image, containerName) !== ""
    }

    /* Centralised so every view builds identical links for the same container. */
    function linksFor(rec) {
        if (!rec || !cfg.enableBrowserLinks) return []
        return Parsers.buildLinks(rec.ports, {
            "lanHost": cfg.lanHost,
            "tailscaleHost": cfg.tailscaleHost,
            "allowLan": cfg.allowLanLinks,
            "allowTailscale": cfg.allowTailscaleLinks,
            "httpsPorts": httpsPorts
        })
    }

    function openLink(link) {
        if (link) Qt.openUrlExternally(Parsers.linkUrl(link))
    }

    // ======================================================== actions ======

    /*
     * A one-shot container operation. `commandKey` is a config entry name,
     * `successText` is what the notification says when it works.
     */
    function runOnContainer(rec, commandKey, successText) {
        if (!rec) return
        var template = String(cfg[commandKey] || "")
        var cmd = expand(template, {
            "id": shellQuote(Parsers.shortId(rec.id)), "name": shellQuote(rec.name)
        })
        if (template.indexOf("{id}") === -1 && template.indexOf("{name}") === -1)
            cmd += " " + shellQuote(Parsers.shortId(rec.id))
        if (!cmd) return
        var label = rec.name
        runner.run(cmd, commandKey, function (code, out, err) {
            if (code === 0) {
                backend.actionDone(label, successText, true)
            } else {
                var msg = firstLine(err) || firstLine(out)
                backend.actionDone(label, msg || i18n("Command failed"), false)
            }
            backend.refresh({ "withStats": false })
        })
    }

    function startContainer(rec) {
        runOnContainer(rec, "startOneCommand", i18n("Container started"))
    }

    function stopContainer(rec) {
        runOnContainer(rec, "stopOneCommand", i18n("Container stopped"))
    }

    function restartContainer(rec) {
        runOnContainer(rec, "restartOneCommand", i18n("Container restarted"))
    }

    function killContainer(rec) {
        runOnContainer(rec, "killOneCommand", i18n("Container killed"))
    }

    function pauseContainer(rec) {
        runOnContainer(rec, "pauseOneCommand", i18n("Container paused"))
    }

    function unpauseContainer(rec) {
        runOnContainer(rec, "unpauseOneCommand", i18n("Container unpaused"))
    }

    function removeContainer(rec) {
        if (!rec) return
        var template = String(cfg.removeOneCommand || "")
        var cmd = expand(template, {
            "id": shellQuote(Parsers.shortId(rec.id)), "name": shellQuote(rec.name)
        })
        if (template.indexOf("{id}") === -1 && template.indexOf("{name}") === -1)
            cmd += " " + shellQuote(Parsers.shortId(rec.id))
        runner.run(cmd, "remove", function (code, out, err) {
            if (code === 0) {
                backend.actionDone(rec.name, i18n("Container removed"), true)
            } else {
                backend.actionDone(rec.name, firstLine(err) || i18n("Could not remove container"), false)
            }
            backend.refresh({ "withStats": false })
        })
    }

    function renameContainer(rec, newName) {
        if (!rec || !newName) return
        var cmd = expand(cfg.renameOneCommand, {
            "id": Parsers.shortId(rec.id),
            "name": newName
        })
        runner.run(cmd, "rename", function (code, out, err) {
            if (code === 0) {
                backend.actionDone(rec.name, i18n("Renamed to %1", newName), true)
            } else {
                backend.actionDone(rec.name, firstLine(err) || i18n("Could not rename container"), false)
            }
            backend.refresh({ "withStats": false })
        })
    }

    /* Pull runs long enough that its output is worth watching, so it is
       streamed to the shared output panel instead of being swallowed. */
    function pullImage(rec) {
        if (!rec) return
        var cmd = expand(cfg.pullImageCommand, { "image": rec.image })
        backend.outputReady(i18n("Pulling %1", rec.image), i18n("Starting…"))
        runner.run(cmd, "pull", function (code, out, err) {
            var text = (out || "") + (err ? (out ? "\n" : "") + err : "")
            backend.outputReady(i18n("Pulling %1", rec.image), text || i18n("(no output)"))
            backend.actionDone(rec.name, code === 0 ? i18n("Image pulled") : i18n("Pull failed"), code === 0)
            backend.refresh({ "withStats": false })
        })
    }

    function prune() {
        runner.run(cfg.pruneCommand, "prune", function (code, out, err) {
            var text = (out || "") + (err ? (out ? "\n" : "") + err : "")
            backend.outputReady(i18n("Prune"), text || i18n("(no output)"))
            backend.actionDone(i18n("Docker"), code === 0 ? i18n("Prune finished") : i18n("Prune failed"), code === 0)
            backend.diskUsageKnown = false
            backend.refresh({ "withStats": false, "withDisk": true })
        })
    }

    /* ---- terminal / editor integration ---- */

    function execShell(rec, shell) {
        if (!rec) return
        var inner = expand(cfg.shellCommand, {
            "id": Parsers.shortId(rec.id),
            "name": rec.name,
            "shell": shell
        })
        // The terminal emulator is launched detached: it outlives the plasmoid
        // and must never occupy a command slot.
        runner.spawn(terminalLaunch(inner), function (code, out, err) {
            if (code !== 0) backend.actionDone(rec.name,
                firstLine(err) || firstLine(out) || i18n("Could not open terminal"), false)
        })
    }

    function shellQuote(value) {
        return "'" + String(value).replace(/'/g, "'\\''") + "'"
    }

    function terminalLaunch(inner) {
        var template = String(cfg.terminalCommand || "")
        return template.indexOf("{command}") >= 0
            ? expand(template, { "command": inner })
            : template + " " + inner
    }

    /* The choices use installed launchers. Folder-based tools are only offered
       for containers with a Compose working directory. */
    function openIn(rec, app) {
        if (!rec || !runner) return
        var dir = String(rec.composeWorkDir || "")
        var cmd = ""
        if (app === "konsole" || app === "ghostty" || app === "yakuake") {
            if (!rec.isRunning) {
                actionDone(rec.name, i18n("Start the container before opening a shell"), false)
                return
            }
            var shells = ["/bin/sh", "/bin/bash", "/bin/ash"]
            function tryShell(index) {
                if (index >= shells.length) {
                    backend.actionDone(rec.name, i18n("This container has no supported shell"), false)
                    return
                }
                var check = "docker exec " + shellQuote(Parsers.shortId(rec.id))
                    + " " + shells[index] + " -c true"
                backend.runner.run(check, "shell-check", function (code) {
                    if (code !== 0) { tryShell(index + 1); return }
                    var inner = "docker exec -it " + shellQuote(Parsers.shortId(rec.id))
                        + " " + shells[index]
                    if (app === "konsole") cmd = "konsole -e " + inner
                    else if (app === "ghostty") cmd = "ghostty -e " + inner
                    else cmd = "yakuake >/dev/null 2>&1 & sleep 0.5; qdbus6 org.kde.yakuake /yakuake/sessions org.kde.yakuake.addSession"
                        + " && qdbus6 org.kde.yakuake /yakuake/sessions org.kde.yakuake.runCommand "
                        + shellQuote(inner)
                    backend.runner.spawn(cmd, function (exitCode, out, err) {
                        if (exitCode !== 0) backend.actionDone(rec.name,
                            firstLine(err) || firstLine(out) || i18n("Could not open terminal"), false)
                    })
                })
            }
            tryShell(0)
            return
        }
        if (dir !== "") {
            if (app === "vscode") cmd = "visual-studio-code-electron " + shellQuote(dir)
            else if (app === "chatgpt") cmd = "cd " + shellQuote(dir) + " && chatgpt"
            else if (app === "claude") cmd = "konsole --workdir " + shellQuote(dir) + " -e claude"
        }
        if (cmd !== "") runner.spawn(cmd, function (code, out, err) {
            if (code !== 0) backend.actionDone(rec.name,
                firstLine(err) || firstLine(out) || i18n("Could not open %1", app), false)
        })
    }

    function followLogs(rec) {
        if (!rec) return
        var inner = expand(cfg.logsFollowCommand, {
            "id": Parsers.shortId(rec.id),
            "name": rec.name
        })
        runner.spawn(terminalLaunch(inner), function (code, out, err) {
            if (code !== 0) backend.actionDone(rec.name,
                firstLine(err) || firstLine(out) || i18n("Could not open terminal"), false)
        })
    }

    /* Open the compose file that defines a container, if it has one. */
    function editCompose(rec) {
        if (!rec) return
        var file = Parsers.firstFile(rec.composeFiles)
        if (file === "") {
            actionDone(rec.name, i18n("This container has no compose file"), false)
            return
        }
        runner.spawn(expand(cfg.editorCommand, { "file": file, "dir": rec.composeWorkDir || file }))
    }

    // ---- compose project groups ----

    /*
     * Containers that belong to the same compose project act as a unit. A
     * standalone container is its own group, so the same UI works for both.
     *
     * The key here is the same value the `groupKey` role carries, so what a
     * group header displays and what a group action operates on can never
     * drift apart.
     */
    function groupKeyOf(rec) {
        return rec.project !== "" ? rec.project : rec.name
    }

    function findGroupRecord(groupKey) {
        for (var i = 0; i < records.length; i++) {
            if (groupKeyOf(records[i]) === groupKey) return records[i]
        }
        return null
    }

    function groupIsProject(groupKey) {
        var rec = findGroupRecord(groupKey)
        return !!rec && rec.project !== ""
    }

    function groupMembers(groupKey) {
        var out = []
        for (var i = 0; i < records.length; i++) {
            if (groupKeyOf(records[i]) === groupKey) out.push(records[i])
        }
        return out
    }

    function runOnGroup(groupKey, commandKey, successText) {
        var rec = findGroupRecord(groupKey)
        if (!rec) return
        if (rec.project === "") {
            // Not a project: the group is a single container.
            runOnContainer(rec, commandKey, successText)
            return
        }
        var cmd = expand(cfg[commandKey], { "project": rec.project })
        runner.run(cmd, commandKey, function (code, out, err) {
            if (code === 0) {
                backend.actionDone(groupKey, successText, true)
            } else {
                backend.actionDone(groupKey, firstLine(err) || i18n("Command failed"), false)
            }
            backend.refresh({ "withStats": false })
        })
    }

    function startGroup(groupKey) { runOnGroup(groupKey, "groupStartCommand", i18n("Group started")) }
    function stopGroup(groupKey) { runOnGroup(groupKey, "groupStopCommand", i18n("Group stopped")) }
    function restartGroup(groupKey) { runOnGroup(groupKey, "groupRestartCommand", i18n("Group restarted")) }

    // ---- engine ----

    function startEngine() {
        runner.run(cfg.startCommand, "engine-start", function (code, out, err) {
            // The daemon needs a moment before the socket answers; give it a
            // beat, then re-probe rather than reporting a stale failure.
            probeDelay.restart()
            if (code !== 0) {
                backend.actionDone(i18n("Docker"), firstLine(err) || i18n("Could not start Docker"), false)
            }
        })
    }

    function stopEngine() {
        runner.run(cfg.stopServiceCommand, "engine-stop", function (code, out, err) {
            runner.run(cfg.stopSocketCommand, "engine-socket", function () {
                backend.onEngineDown()
                backend.engineActive = false
                backend.engineStateChanged(false)
                backend.actionDone(i18n("Docker"), i18n("Docker stopped"), code === 0)
            })
        })
    }

    Timer {
        id: probeDelay
        interval: 2500
        repeat: false
        onTriggered: backend.refresh({ "force": true, "withStats": false })
    }

    // ======================================================== output ======

    /* Log tail for the inline output panel. */
    function fetchLogs(rec, tail) {
        if (!rec) return
        var cmd = expand(cfg.logsCommand, {
            "id": Parsers.shortId(rec.id),
            "name": rec.name,
            "tail": tail
        })
        runner.run(cmd, "logs", function (code, out, err) {
            var text = (out || "")
            if (err) text += (text ? "\n" : "") + err
            backend.outputReady(logsTitle(rec), text || i18n("(no output)"))
        })
    }

    /* The single title format used for log payloads, so every page that shows
       logs can recognise an outputReady() meant for it. */
    function logsTitle(rec) {
        return i18n("Logs — %1", rec ? rec.name : "")
    }

    function fetchInspect(rec) {
        if (!rec) return
        var cmd = expand(cfg.inspectCommand, {
            "id": Parsers.shortId(rec.id),
            "name": rec.name
        })
        runner.run(cmd, "inspect", function (code, out, err) {
            if (code !== 0) {
                backend.outputReady(i18n("Inspect"), firstLine(err) || i18n("Could not inspect container"))
                return
            }
            backend.outputReady(i18n("Inspect — %1", rec.name), prettyJson(out))
        })
    }

    function prettyJson(text) {
        try {
            return JSON.stringify(JSON.parse(String(text)), null, 2)
        } catch (e) {
            return String(text)
        }
    }

    function firstLine(text) {
        if (!text) return ""
        var lines = String(text).trim().split("\n")
        return lines[0] ? lines[0].trim() : ""
    }

    // =================================================== notifications =====

    property string notifTitle: ""
    property string notifText: ""

    Notification {
        id: notifier
        componentName: "dockercompanion"
        eventId: "event"
        title: backend.notifTitle
        text: backend.notifText
    }

    function notify(title, message) {
        if (!cfg.useNotifications) return
        notifTitle = title
        notifText = message
        notifier.sendEvent()
    }

}
