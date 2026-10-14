import QtQuick
import org.kde.notification

import QtCore
import org.kde.kirigami as Kirigami

import "../../lib/parsers.js" as Parsers
import "../../lib/icons.js" as Icons

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

    /* Addresses used to build browser links when the user left them empty. */
    property string detectedLanHost: ""
    property string detectedTailscaleHost: ""
    readonly property string lanHost: contextHost !== "" ? contextHost
        : (String(cfg.lanHost || "").trim() !== ""
           ? String(cfg.lanHost).trim()
           : (cfg.autoDetectHosts ? detectedLanHost : ""))
    readonly property string tailscaleHost: contextHost !== "" ? ""
        : (String(cfg.tailscaleHost || "").trim() !== ""
           ? String(cfg.tailscaleHost).trim()
           : (cfg.autoDetectHosts ? detectedTailscaleHost : ""))

    /* The container CLI every default command starts with, aimed at the chosen
       Docker context (or Podman connection) when there is one. */
    readonly property string engineBase: String(cfg.engineCommand || "").trim() !== ""
        ? String(cfg.engineCommand).trim() : "docker"
    readonly property string contextName: Parsers.isSafeToken(cfg.activeContext) ? String(cfg.activeContext) : ""
    readonly property string engineBinary: contextName === "" ? engineBase
        : engineBase + (/podman$/.test(engineBase) ? " --connection " : " --context ") + contextName

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
        var out = String(cmd).split("{engine}").join(engineBinary)
        for (var key in vars) {
            out = out.split("{" + key + "}").join(String(vars[key]))
        }
        return out
    }

    // ============================================================ contexts ====

    property var contexts: []
    property string contextHost: ""

    function fetchContexts() {
        runner.run(expand(cfg.contextListCommand, {}), "contexts", function (code, out) {
            if (code !== 0) { contexts = []; return }
            contexts = String(out || "").split("\n").map(function (l) { return l.trim() })
                .filter(function (l) { return Parsers.isSafeToken(l) })
        })
    }

    /* Point everything at another engine and start over from a clean slate. */
    function setContext(name) {
        cfg.activeContext = name
        records = []; syncModel()
        policyCache = ({}); statsCache = ({}); history = ({}); alertState = ({})
        probeState = ({}); updateState = ({}); lastSnapshot = null
        engineKnown = false; engineActive = false
        resources = ({ "images": [], "volumes": [], "networks": [] })
        lastFullMs = 0; lastEventSec = 0
        detectContextHost()
        refresh({ "force": true, "withStats": true })
    }

    /* A remote engine's own address is what published ports should link to. */
    function detectContextHost() {
        contextHost = ""
        if (contextName === "") return
        runner.run(engineBase + " context inspect " + contextName
                   + " --format '{{.Endpoints.docker.Host}}'", "context-host", function (code, out) {
            var m = /^(?:ssh|tcp):\/\/(?:[^@\/]+@)?([^:\/]+)/.exec(String(out || "").trim())
            if (code === 0 && m) contextHost = m[1]
        })
    }

    // ========================================================= pinning ====

    readonly property var pinnedNames: String(cfg.pinned || "").split(",")
        .map(function (n) { return n.trim() }).filter(function (n) { return n !== "" })

    function isPinned(name) { return pinnedNames.indexOf(name) >= 0 }

    function togglePin(rec) {
        var list = pinnedNames.slice()
        var at = list.indexOf(rec.name)
        if (at >= 0) list.splice(at, 1); else list.push(rec.name)
        cfg.pinned = list.join(",")
        // Re-sort now rather than waiting for the next poll.
        applySort(); syncModel(); revision++
    }

    function movePin(rec, delta) {
        var list = pinnedNames.slice()
        var at = list.indexOf(rec.name)
        var to = at + delta
        if (at < 0 || to < 0 || to >= list.length) return
        list.splice(at, 1); list.splice(to, 0, rec.name)
        cfg.pinned = list.join(",")
        applySort(); syncModel(); revision++
    }

    /* Pinned first (in the order you gave), then running, then the rest. */
    function applySort() {
        for (var i = 0; i < records.length; i++) {
            var r = records[i]
            var pin = pinnedNames.indexOf(r.name)
            r.pinned = pin >= 0
            r.sortKey = (pin >= 0 ? "0" + ("000" + pin).slice(-3) : (r.isRunning ? "1" : "2"))
                + r.name.toLowerCase()
        }
        records.sort(function (a, b) { return a.sortKey < b.sortKey ? -1 : (a.sortKey > b.sortKey ? 1 : 0) })
    }

    // =================================================== refresh cycle ====

    // Three tiers keep this both detailed and cheap:
    //   1. a change check every few seconds — one `events` query that prints
    //      nothing when nothing happened, so it costs next to nothing;
    //   2. a list refresh the moment that check reports a change, or on the
    //      slower heartbeat in case an event was missed;
    //   3. stats, which sample for a second or two, only while somebody looks.

    property double lastFullMs: 0
    property double lastEventSec: 0
    property double lastUpdatedMs: 0
    property double eventsFailedMs: 0
    property int downTicks: 0

    /* Whether the cheap change check works with this engine and these settings. */
    readonly property bool eventsUsable: eventsFailedMs === 0
        || Date.now() - eventsFailedMs > 10 * 60 * 1000

    /* Timer-driven tick. Does at most one small thing, and nothing at all while
       a previous cycle is still in flight. */
    function tick() {
        if (!runner || refreshing) return
        if (!engineKnown) return
        if (!engineActive) {
            // Docker may have been started from a terminal; look again now and
            // then instead of waiting for the user to click refresh.
            downTicks++
            if (downTicks % 4 === 0) refresh({ "force": true, "withStats": false })
            return
        }
        downTicks = 0
        var heartbeat = Math.max(5, cfg.updateInterval) * 1000
        if (!eventsUsable || Date.now() - lastFullMs >= heartbeat) {
            refresh({ "withStats": false, "skipDetect": true })
            return
        }
        checkForChanges()
    }

    function poll() { tick() }

    function checkForChanges() {
        var until = Math.floor(Date.now() / 1000)
        var since = lastEventSec > 0 ? lastEventSec : until
        var cmd = expand(cfg.eventsCommand, { "since": since, "until": until })
        beginTask()
        runner.run(cmd, "events", function (code, out) {
            if (code !== 0) {
                // Old engine, odd wrapper, wrong flags: fall back to plain
                // polling for a while rather than failing every tick.
                backend.eventsFailedMs = Date.now()
                backend.endTask()
                backend.refresh({ "withStats": false, "skipDetect": true })
                return
            }
            backend.eventsFailedMs = 0
            backend.lastEventSec = until
            backend.endTask()
            if (String(out || "").trim() !== "")
                backend.refresh({ "withStats": false, "skipDetect": true })
        })
    }

    /*
     * opts.withStats  — also refresh the expensive per-container stats.
     * opts.withDisk   — also refresh `docker system df` (slow, opt-in).
     * opts.force      — run even if the engine was previously down.
     * opts.skipDetect — the engine is known to be up; go straight to the list.
     */
    function refresh(opts) {
        opts = opts || {}
        if (!runner) return
        if (refreshing) return
        if (engineKnown && !engineActive && !opts.force) return

        beginTask()
        if (opts.skipDetect && engineActive) {
            backend.loadEverything(opts)
            backend.endTask()
            return
        }
        runner.run(expand(cfg.checkActiveCommand, {}), "detect", function (code, out, err) {
            var active = detectActive(code, out)
            if (active !== backend.engineActive) {
                backend.engineActive = active
                backend.engineStateChanged(active)
            }
            backend.engineKnown = true
            backend.engineProblem = active ? "" : backend.classifyProblem(code, out, err)
            if (!active) {
                backend.onEngineDown()
                backend.endTask()
                return
            }
            backend.loadEverything(opts)
            backend.endTask()
        })
    }

    /* "missing" (no CLI), "permission" (socket access) or "down" (daemon). */
    property string engineProblem: ""

    function classifyProblem(code, out, err) {
        var text = (String(err || "") + " " + String(out || "")).toLowerCase()
        if (code === 127 || /command not found|no such file or directory.*(docker|podman)|not found/.test(text)) return "missing"
        if (/permission denied/.test(text)) return "permission"
        return "down"
    }

    function loadEverything(opts) {
        lastFullMs = Date.now()
        lastEventSec = Math.floor(Date.now() / 1000)
        fetchList()
        fetchInfo()
        if (updatesDue()) startUpdateCheck()
        if (opts.withStats !== false) fetchStats()
        if (opts.withDisk) fetchDiskUsage()
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
        lastSnapshot = null
        if (runner) runner.cancelAll()
    }

    function fetchList() {
        beginTask()
        runner.run(expand(cfg.listCommand, {}), "list", function (code, out, err) {
            if (code !== 0) {
                lastError = err || String(out || "").trim()
            } else {
                lastError = ""
                lastUpdatedMs = Date.now()
                records = Parsers.parseContainers(out)
                Parsers.applyRestartPolicies(records, policyCache)
                // Pinned first, then running, then alphabetical. Views may
                // re-sort on top of this.
                applyProbes(); applyUpdates(); applySort()
                applyStatsToRecords()
                syncModel()
                recomputeTotals()
                revision++
                announceChanges()
                refreshRestartPoliciesIfNeeded()
            }
            endTask()
        })
    }

    // ============================================== restart policies ======

    property var policyCache: ({})
    property double lastPolicyMs: 0

    /* Policies rarely change, so they are re-read on a slow timer — or at once
       when a container shows up that has no entry yet. */
    function refreshRestartPoliciesIfNeeded() {
        var missing = false
        for (var i = 0; i < records.length; i++) {
            if (policyCache[Parsers.shortId(records[i].id)] === undefined) { missing = true; break }
        }
        var due = Date.now() - lastPolicyMs >= Math.max(10, cfg.restartPolicyInterval) * 1000
        if (missing || due) fetchRestartPolicies()
    }

    function fetchRestartPolicies() {
        lastPolicyMs = Date.now()
        beginTask()
        runner.run(expand(cfg.restartPolicyCommand, {}), "policies", function (code, out) {
            if (code === 0) {
                policyCache = Parsers.parseRestartPolicies(out)
                Parsers.applyRestartPolicies(records, policyCache)
                syncModel()
                revision++
            }
            endTask()
        })
    }

    function setRestartPolicy(rec, policy) {
        if (!rec || Parsers.RESTART_POLICIES.indexOf(policy) < 0) return
        var cmd = expand(cfg.setRestartPolicyCommand, {
            "id": Parsers.shortId(rec.id), "policy": policy,
            "name": shellQuote(rec.name)
        })
        muteContainer(rec.id)
        runner.run(cmd, "restart-policy", function (code, out, err) {
            if (code === 0) {
                backend.actionDone(rec.name, i18n("Restart policy set to %1", policy), true)
                backend.fetchRestartPolicies()
            } else {
                backend.actionDone(rec.name, firstLine(err) || i18n("Could not change the restart policy"), false)
            }
        })
    }

    function startsAutomatically(policy) {
        return Parsers.startsAutomatically(policy)
    }

    function policyLabel(policy) {
        switch (policy) {
        case "no": return i18n("Manual start")
        case "on-failure": return i18n("Restart on failure")
        case "unless-stopped": return i18n("Start automatically")
        case "always": return i18n("Always restart")
        default: return policy
        }
    }

    // ============================================== change detection ======

    property var lastSnapshot: null
    /* container id -> time until which its events are not announced */
    property var muted: ({})

    function muteContainer(id) {
        muted[id] = Date.now() + Math.max(0, cfg.notifyMuteAfterAction) * 1000
    }

    /* Announce what changed since the previous poll: a crash, a restart loop, a
       container turning unhealthy or recovering. Things the user just did from
       this widget are muted, so pressing Stop never raises a notification about
       the stop. */
    function announceChanges() {
        var snap = Parsers.snapshotStates(records)
        var events = Parsers.diffStates(lastSnapshot, snap)
        lastSnapshot = snap
        if (events.length === 0 || !cfg.useNotifications) return

        var now = Date.now()
        var enabled = {
            "crashed": cfg.notifyOnCrash, "restarting": cfg.notifyOnRestartLoop,
            "unhealthy": cfg.notifyOnUnhealthy, "recovered": cfg.notifyOnRecovered,
            "started": cfg.notifyOnStartStop, "stopped": cfg.notifyOnStartStop
        }
        var lines = []
        var worst = "event"
        for (var i = 0; i < events.length; i++) {
            var ev = events[i]
            if (!enabled[ev.kind]) continue
            if (muted[ev.id] && muted[ev.id] > now) continue
            switch (ev.kind) {
            case "crashed": lines.push(i18n("%1 exited with code %2", ev.name, ev.code)); worst = "crash"; break
            case "restarting": lines.push(i18n("%1 is restarting", ev.name)); if (worst === "event") worst = "crash"; break
            case "unhealthy": lines.push(i18n("%1 became unhealthy", ev.name)); if (worst === "event") worst = "unhealthy"; break
            case "recovered": lines.push(i18n("%1 is healthy again", ev.name)); break
            case "started": lines.push(i18n("%1 started", ev.name)); break
            case "stopped": lines.push(i18n("%1 stopped", ev.name)); break
            }
        }
        for (var id in muted) if (muted[id] <= now) delete muted[id]
        if (lines.length === 0) return
        var title = lines.length === 1 ? i18n("Docker") : i18np("Docker: %1 change", "Docker: %1 changes", lines.length)
        notify(title, lines.slice(0, 6).join("\n") + (lines.length > 6 ? "\n" + i18n("…and %1 more", lines.length - 6) : ""), worst)
    }

    function fetchStats() {
        if (running === 0 && records.length > 0) return
        beginTask()
        runner.run(expand(cfg.usageCommand, {}), "stats", function (code, out, err) {
            if (code === 0) {
                statsCache = Parsers.parseStats(out)
                applyStatsToRecords()
                recordSamples()
                checkResourceAlerts()
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
        if (!String(cfg.infoCommand || "").trim()) return
        if (now - lastInfoMs < 60000) return
        lastInfoMs = now
        beginTask()
        runner.run(expand(cfg.infoCommand, {}), "info", function (code, out, err) {
            if (code === 0) engineInfo = Parsers.parseInfo(out)
            endTask()
        })
    }

    function fetchDiskUsage() {
        if (diskUsageKnown) return
        beginTask()
        runner.run(expand(cfg.systemDfCommand, {}), "systemdf", function (code, out, err) {
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
            "restartPolicy": rec.restartPolicy || "",
            "pinned": rec.pinned === true,
            "probe": rec.probe || "", "probeMs": rec.probeMs || 0,
            "updateAvailable": rec.updateAvailable === true,
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
                   "blockio", "netio", "pids", "cpuPct", "memPct", "restartPolicy", "pinned",
                   "probe", "probeMs", "updateAvailable", "sortKey",
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

    /* Whatever needs a look: unhealthy, restarting, dead, paused or exited badly. */
    function isProblem(row) {
        var state = row.containerState !== undefined ? row.containerState : row.state
        var status = row.status || ""
        if (row.health === "unhealthy") return true
        if (row.probe === "down" && (row.isRunning === true || state === "running")) return true
        if (state === "restarting" || state === "dead" || state === "paused") return true
        if (state === "exited") {
            var code = Parsers.exitCodeFromStatus(status)
            return code !== null && !Parsers.isDeliberateExit(code)
        }
        return false
    }

    property int problemCount: 0

    function recomputeTotals() {
        var n = 0
        for (var p = 0; p < records.length; p++) if (isProblem(records[p])) n++
        problemCount = n
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

    /* The user's own "text=icon" rules; they are tried before the name match. */
    readonly property var iconRules: Icons.parseOverrides(cfg.customIcons)

    /*
     * The icon library: a folder of per-service images in the selfh.st layout.
     *
     * QML cannot list a directory, so a one-shot `ls` reads it and icons.js
     * indexes the result. The folder is the one set in the settings; when that
     * is empty, the first of: the folder the Icons page downloads into,
     * ~/Pictures/selfhst, and the small set bundled with the widget, so there
     * are real logos before anything is configured or downloaded.
     */
    property var iconEntries: ({})
    property string iconLibraryDir: ""
    property int iconCount: 0
    property int iconRevision: 0

    readonly property bool useIconLibrary: iconCount > 0

    /* QML has no environment access, so the home directory comes from Qt. */
    readonly property string homeDir: String(
        StandardPaths.writableLocation(StandardPaths.HomeLocation))
        .replace(/^file:\/\//, "")

    readonly property bool darkTheme: Kirigami.Theme.textColor.hslLightness > 0.5

    function iconLibraryCandidates() {
        var configured = String(cfg.serviceIconDirectory || "").trim()
        if (configured !== "") return [Icons.expandHome(configured, homeDir)]
        var bundled = String(Qt.resolvedUrl("../../assets/library")).replace(/^file:\/\//, "")
        return [homeDir + "/.local/share/dockmoid/icons/svg",
                homeDir + "/.local/share/dockmoid/icons",
                homeDir + "/Pictures/selfhst", homeDir + "/pictures/selfhst",
                bundled]
    }

    function reloadIconLibrary() {
        var dirs = iconLibraryCandidates().map(shellQuote).join(" ")
        // First line is the folder that won, the rest is its listing.
        var cmd = "for d in " + dirs + "; do if [ -d \"$d\" ]; then echo \"$d\"; ls -1 \"$d\"; break; fi; done"
        runner.run(cmd, "icons", function (code, out) {
            var lines = String(out || "").split("\n")
            var dir = code === 0 ? lines.shift().trim() : ""
            iconLibraryDir = dir
            iconEntries = dir !== "" ? Icons.parseLibrary(lines.join("\n")) : ({})
            iconCount = Icons.libraryCount(iconEntries)
            iconCache = ({})
            iconRevision++
        })
    }

    Connections {
        target: backend.cfg
        function onServiceIconDirectoryChanged() { backend.reloadIconLibrary() }
    }

    property var iconCache: ({})

    /*
     * Everything the views need to draw one container's icon:
     *   url      absolute URL, or "" when nothing matches
     *   colored  true for library artwork (shown as-is), false for the bundled
     *            silhouettes (drawn as a themed mask)
     *
     * Library artwork wins over the bundled glyphs; the container's own name
     * and compose service are tried before its image, which is what makes
     * containers created from an untagged image id (shown as a bare hex id by
     * docker) still find their icon.
     */
    function iconFor(rec) {
        if (!rec) return ({ "url": "", "colored": false })
        var key = rec.name + "|" + rec.image + "|" + rec.service + "|" + rec.project
            + "|" + cfg.iconVariant + "|" + darkTheme + "|" + cfg.coloredServiceIcons + "|" + useIconLibrary
        var hit = iconCache[key]
        if (hit) return hit
        var result = ({ "url": "", "colored": false })
        if (useIconLibrary) {
            var rule = Icons.ruleMatch(iconRules, rec.name + " " + rec.image + " " + rec.service)
            var name = null
            if (rule === undefined) {
                name = Icons.libraryMatch(iconEntries,
                    Icons.libraryCandidates(rec.name, rec.service, rec.image, rec.project))
            } else if (rule !== null && iconEntries[rule.toLowerCase()]) {
                name = rule.toLowerCase()
            }
            if (name !== null) {
                var file = Icons.libraryFile(iconEntries, name, cfg.iconVariant, darkTheme)
                if (file !== "")
                    result = ({ "url": "file://" + iconLibraryDir + "/" + file,
                                "colored": cfg.coloredServiceIcons })
            }
        }
        iconCache[key] = result
        return result
    }

    function serviceIconUrl(image, containerName) {
        return iconFor({ "name": containerName, "image": image, "service": "", "project": "" }).url
    }

    function serviceIconIsColored(image, containerName) {
        return iconFor({ "name": containerName, "image": image, "service": "", "project": "" }).colored
    }

    /* Centralised so every view builds identical links for the same container. */
    function linksFor(rec) {
        if (!rec || !cfg.enableBrowserLinks) return []
        return Parsers.buildLinks(rec.ports, {
            "lanHost": lanHost,
            "tailscaleHost": tailscaleHost,
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
     * Placeholder values for one container. Everything that can hold arbitrary
     * text is quoted here, once, so no command template ever sees a raw value.
     * The id is a plain hex token and is left bare.
     */
    function containerVars(rec, extra) {
        var vars = {
            "id": Parsers.shortId(rec.id),
            "name": shellQuote(rec.name),
            "image": shellQuote(rec.image)
        }
        for (var k in (extra || {})) vars[k] = extra[k]
        return vars
    }

    /* Expand a per-container template; a template with no placeholder at all
       gets the id appended, so a bare `docker start` still works. */
    function containerCommand(template, rec, extra) {
        template = String(template || "")
        var cmd = expand(template, containerVars(rec, extra))
        if (template.indexOf("{id}") === -1 && template.indexOf("{name}") === -1)
            cmd += " " + Parsers.shortId(rec.id)
        return cmd
    }

    function reportResult(label, okText, failText, code, out, err) {
        if (code === 0) {
            backend.actionDone(label, okText, true)
        } else {
            backend.actionDone(label, firstLine(err) || firstLine(out) || failText, false)
        }
    }

    /*
     * A one-shot container operation. `commandKey` is a config entry name,
     * `successText` is what the notification says when it works.
     */
    function runOnContainer(rec, commandKey, successText) {
        if (!rec) return
        var cmd = containerCommand(cfg[commandKey], rec)
        if (!cmd) return
        muteContainer(rec.id)
        runner.run(cmd, commandKey, function (code, out, err) {
            backend.reportResult(rec.name, successText, i18n("Command failed"), code, out, err)
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
        runOnContainer(rec, "removeOneCommand", i18n("Container removed"))
    }

    function renameContainer(rec, newName) {
        if (!rec || !Parsers.isSafeToken(newName)) return
        var cmd = expand(cfg.renameOneCommand, {
            "id": Parsers.shortId(rec.id),
            "name": shellQuote(newName)
        })
        muteContainer(rec.id)
        runner.run(cmd, "rename", function (code, out, err) {
            backend.reportResult(rec.name, i18n("Renamed to %1", newName),
                                 i18n("Could not rename container"), code, out, err)
            backend.refresh({ "withStats": false })
        })
    }

    /* Pull runs long enough that its output is worth watching, so it is
       streamed to the shared output panel instead of being swallowed. */
    function pullImage(rec) {
        if (!rec) return
        var cmd = expand(cfg.pullImageCommand, containerVars(rec))
        backend.outputReady(i18n("Pulling %1", rec.image), i18n("Starting…"))
        runner.run(cmd, "pull", function (code, out, err) {
            var text = (out || "") + (err ? (out ? "\n" : "") + err : "")
            backend.outputReady(i18n("Pulling %1", rec.image), text || i18n("(no output)"))
            backend.actionDone(rec.name, code === 0 ? i18n("Image pulled") : i18n("Pull failed"), code === 0)
            backend.refresh({ "withStats": false })
        })
    }

    /*
     * opts.images  — also remove every unused image, not just dangling ones
     * opts.volumes — also remove unused volumes (this can delete data)
     * Both default to off; the flags are appended to the configured command.
     */
    function prune(opts) {
        opts = opts || {}
        var cmd = String(cfg.pruneCommand || "")
        if (opts.images) cmd += " -a"
        if (opts.volumes) cmd += " --volumes"
        runner.run(cmd, "prune", function (code, out, err) {
            var text = (out || "") + (err ? (out ? "\n" : "") + err : "")
            backend.outputReady(i18n("Prune"), text || i18n("(no output)"))
            backend.actionDone(i18n("Docker"), code === 0 ? i18n("Prune finished") : i18n("Prune failed"), code === 0)
            backend.diskUsageKnown = false
            backend.refresh({ "withStats": false, "withDisk": true })
        })
    }

    /* Re-read `docker system df` on demand (the prune dialog's size estimate). */
    function refreshDiskUsage() {
        diskUsageKnown = false
        fetchDiskUsage()
    }

    /* ---- terminal / editor integration ---- */

    function shellQuote(value) {
        return "'" + String(value).replace(/'/g, "'\\''") + "'"
    }

    /*
     * Terminal and editor default to "whatever is installed". Probing happens
     * once, in one shell call, so a fresh install on GNOME-flavoured or tiling
     * setups works without opening the settings.
     */
    property string detectedTerminal: ""
    property string detectedEditor: ""

    readonly property var terminalChoices: [
        ["konsole", "konsole -e {command}"],
        ["gnome-terminal", "gnome-terminal -- {command}"],
        ["kitty", "kitty {command}"],
        ["alacritty", "alacritty -e {command}"],
        ["foot", "foot {command}"],
        ["wezterm", "wezterm start -- {command}"],
        ["ghostty", "ghostty -e {command}"],
        ["xfce4-terminal", "xfce4-terminal -x {command}"],
        ["lxterminal", "lxterminal -e {command}"],
        ["xterm", "xterm -e {command}"]
    ]
    readonly property var editorChoices: [
        ["kate", "kate {file}"], ["gedit", "gedit {file}"], ["code", "code {file}"],
        ["xdg-open", "xdg-open {file}"]
    ]

    function detectTools() {
        var names = []
        terminalChoices.forEach(function (c) { names.push(c[0]) })
        editorChoices.forEach(function (c) { if (names.indexOf(c[0]) < 0) names.push(c[0]) })
        runner.run("for b in " + names.join(" ") + "; do command -v \"$b\" >/dev/null 2>&1 && echo \"$b\"; done",
                   "tools", function (code, out) {
            var found = {}
            String(out || "").split("\n").forEach(function (l) { if (l.trim() !== "") found[l.trim()] = true })
            for (var i = 0; i < terminalChoices.length; i++) {
                if (found[terminalChoices[i][0]]) { detectedTerminal = terminalChoices[i][1]; break }
            }
            for (var j = 0; j < editorChoices.length; j++) {
                if (found[editorChoices[j][0]]) { detectedEditor = editorChoices[j][1]; break }
            }
        })
    }

    function terminalLaunch(inner) {
        var configured = String(cfg.terminalCommand || "").trim()
        var template = configured !== "" ? configured : (detectedTerminal !== "" ? detectedTerminal : "xterm -e {command}")
        return template.indexOf("{command}") >= 0
            ? expand(template, { "command": inner })
            : template + " " + inner
    }

    // ----------------------------------------------------- launchers ------

    readonly property var launchers: Parsers.parseLaunchers(cfg.launchers)

    /* binary name -> true, for launchers whose program is actually installed. */
    property var installedBinaries: ({})

    function detectLaunchers() {
        var seen = {}
        var names = []
        for (var i = 0; i < launchers.length; i++) {
            var bin = launchers[i].binary
            if (/^[A-Za-z0-9._+-]+$/.test(bin) && !seen[bin]) { seen[bin] = true; names.push(bin) }
        }
        if (names.length === 0) { installedBinaries = ({}); return }
        runner.run("for b in " + names.join(" ") + "; do command -v \"$b\" >/dev/null 2>&1 && echo \"$b\"; done",
                   "launchers", function (code, out) {
            var found = {}
            String(out || "").split("\n").forEach(function (l) { if (l.trim() !== "") found[l.trim()] = true })
            installedBinaries = found
        })
    }

    onLaunchersChanged: detectLaunchers()

    /* The launchers that apply to this record and can actually run. */
    function launchersFor(rec) {
        var out = []
        if (!rec) return out
        for (var i = 0; i < launchers.length; i++) {
            var l = launchers[i]
            if (!installedBinaries[l.binary]) continue
            if (l.scope === "container" && !rec.isRunning) continue
            if (l.scope === "project" && !rec.composeWorkDir) continue
            out.push(l)
        }
        return out
    }

    /*
     * Run a launcher against a container. Container launchers need a shell that
     * exists inside the image, so each candidate is probed in turn first.
     * {dir} is quoted; {id} and {shell} are fixed safe tokens.
     */
    function launch(rec, launcher) {
        if (!rec || !launcher) return
        function fail(text) { backend.actionDone(rec.name, text, false) }
        function run(shell) {
            var cmd = expand(launcher.command, {
                "id": Parsers.shortId(rec.id),
                "shell": shell,
                "dir": shellQuote(rec.composeWorkDir || "")
            })
            runner.spawn(cmd, function (code, out, err) {
                if (code !== 0) fail(firstLine(err) || firstLine(out)
                                     || i18n("Could not open %1", launcher.label))
            })
        }
        if (launcher.scope === "project") {
            if (!rec.composeWorkDir) { fail(i18n("This container has no compose project folder")); return }
            run("")
            return
        }
        if (!rec.isRunning) { fail(i18n("Start the container before opening a shell")); return }
        var shells = ["/bin/bash", "/bin/sh", "/bin/ash"]
        function tryShell(index) {
            if (index >= shells.length) { fail(i18n("This container has no supported shell")); return }
            var check = engineBinary + " exec " + Parsers.shortId(rec.id) + " " + shells[index] + " -c true"
            runner.run(check, "shell-check", function (code) {
                if (code !== 0) tryShell(index + 1)
                else run(shells[index])
            })
        }
        tryShell(0)
    }

    function followLogs(rec) {
        if (!rec) return
        var inner = expand(cfg.logsFollowCommand, containerVars(rec))
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
        var editor = String(cfg.editorCommand || "").trim()
        if (editor === "") editor = detectedEditor !== "" ? detectedEditor : "xdg-open {file}"
        runner.spawn(expand(editor, {
            "file": shellQuote(file),
            "dir": shellQuote(rec.composeWorkDir || file)
        }))
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

    function runOnGroup(groupKey, commandKey, oneKey, successText) {
        var rec = findGroupRecord(groupKey)
        if (!rec) return
        if (rec.project === "") {
            // Not a project: the group is a single container.
            runOnContainer(rec, oneKey, successText)
            return
        }
        // The project name goes inside a quoted filter in the template, so it
        // has to be a plain token — never anything a shell could interpret.
        if (!Parsers.isSafeToken(rec.project)) {
            backend.actionDone(groupKey, i18n("Unsupported project name"), false)
            return
        }
        var cmd = expand(cfg[commandKey], { "project": rec.project })
        var members = groupMembers(groupKey)
        for (var i = 0; i < members.length; i++) muteContainer(members[i].id)
        runner.run(cmd, commandKey, function (code, out, err) {
            backend.reportResult(groupKey, successText, i18n("Command failed"), code, out, err)
            backend.refresh({ "withStats": false })
        })
    }

    function startGroup(groupKey) { runOnGroup(groupKey, "groupStartCommand", "startOneCommand", i18n("Group started")) }
    function stopGroup(groupKey) { runOnGroup(groupKey, "groupStopCommand", "stopOneCommand", i18n("Group stopped")) }
    function restartGroup(groupKey) { runOnGroup(groupKey, "groupRestartCommand", "restartOneCommand", i18n("Group restarted")) }

    // ---- engine ----

    function startEngine() {
        runner.run(expand(cfg.startCommand, {}), "engine-start", function (code, out, err) {
            // The daemon needs a moment before the socket answers; give it a
            // beat, then re-probe rather than reporting a stale failure.
            probeDelay.restart()
            if (code !== 0) {
                backend.actionDone(i18n("Docker"), firstLine(err) || i18n("Could not start Docker"), false)
            }
        })
    }

    function stopEngine() {
        runner.run(expand(cfg.stopServiceCommand, {}), "engine-stop", function (code, out, err) {
            runner.run(expand(cfg.stopSocketCommand, {}), "engine-socket", function () {
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
        var cmd = expand(cfg.logsCommand, containerVars(rec, { "tail": parseInt(tail, 10) || 200 }))
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
        var cmd = expand(cfg.inspectCommand, containerVars(rec))
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

    // =========================================================== history ====

    property var history: ({})

    /* CPU and memory samples per container, newest last, for the small graphs. */
    function recordSamples() {
        var max = Math.max(10, cfg.historySamples)
        var alive = {}
        for (var i = 0; i < records.length; i++) {
            var r = records[i]
            if (!r.isRunning) continue
            alive[r.id] = true
            var h = history[r.id] || { "cpu": [], "mem": [] }
            h.cpu = Parsers.pushSample(h.cpu, r.cpuPct, max)
            h.mem = Parsers.pushSample(h.mem, r.memPct, max)
            history[r.id] = h
        }
        for (var id in history) if (!alive[id]) delete history[id]
    }

    function historyFor(id) {
        return history[id] || { "cpu": [], "mem": [] }
    }

    // ============================================================= alerts ====

    property var alertState: ({})

    function checkResourceAlerts() {
        if (!cfg.useNotifications || (cfg.alertCpu <= 0 && cfg.alertMem <= 0)) return
        var events = Parsers.trackThresholds(alertState, records, Date.now(),
            { "cpu": cfg.alertCpu, "mem": cfg.alertMem, "seconds": Math.max(10, cfg.alertSeconds) })
        if (events.length === 0) return
        var lines = events.map(function (e) {
            return e.what === "cpu" ? i18n("%1 has used %2% CPU for a while", e.name, e.value.toFixed(0))
                                    : i18n("%1 is using %2% of its memory", e.name, e.value.toFixed(0))
        })
        notify(i18n("Docker"), lines.join("\n"), "resource")
    }

    // ============================================================ probes ====

    property var probeState: ({})
    property var lastProbeUp: ({})
    readonly property var probeRules: Parsers.parseProbeRules(cfg.probes)

    function probeTargets() {
        var out = {}
        for (var i = 0; i < records.length; i++) {
            var r = records[i]
            if (!r.isRunning) continue
            var url = Parsers.probeUrlFor(r, probeRules)
            if (url !== "") out[r.id] = url
        }
        return out
    }

    function applyProbes() {
        for (var i = 0; i < records.length; i++) {
            var r = records[i]
            var url = r.isRunning ? Parsers.probeUrlFor(r, probeRules) : ""
            var res = url !== "" ? probeState[url] : undefined
            r.probe = res ? (res.up ? "up" : "down") : ""
            r.probeMs = res ? res.ms : 0
        }
    }

    function runProbes() {
        if (!engineActive) return
        var targets = probeTargets()
        var urls = []
        for (var id in targets) if (urls.indexOf(targets[id]) < 0) urls.push(targets[id])
        if (urls.length === 0) { if (Object.keys(probeState).length > 0) { probeState = ({}); applyProbes(); syncModel() } return }
        var list = urls.map(shellQuote).join(" ")
        var cmd = "for u in " + list + "; do r=$(curl -sk -o /dev/null -m 5 -w '%{http_code} %{time_total}' \"$u\" 2>/dev/null); echo \"$u ${r:-000 0}\"; done"
        runner.run(cmd, "probes", function (code, out) {
            var res = Parsers.parseProbeResults(out)
            var before = backend.probeState
            backend.probeState = res
            backend.announceProbeChanges(before, res)
            backend.applyProbes(); backend.syncModel(); backend.recomputeTotals(); backend.revision++
        })
    }

    function announceProbeChanges(before, after) {
        if (!cfg.useNotifications || !cfg.notifyOnProbe) return
        var lines = []
        for (var i = 0; i < records.length; i++) {
            var r = records[i]
            var url = Parsers.probeUrlFor(r, probeRules)
            if (url === "" || !before[url] || !after[url]) continue
            if (muted[r.id] && muted[r.id] > Date.now()) continue
            if (before[url].up && !after[url].up) lines.push(i18n("%1 stopped answering at %2", r.name, url))
            else if (!before[url].up && after[url].up) lines.push(i18n("%1 answers again", r.name))
        }
        if (lines.length > 0) notify(i18n("Docker"), lines.join("\n"), "probe")
    }

    Timer {
        interval: Math.max(15, backend.cfg.probeInterval) * 1000
        repeat: true
        running: backend.engineActive && backend.records.length > 0
        onTriggered: backend.runProbes()
    }

    // ===================================================== image updates ====

    property var updateState: ({})
    property var updateQueue: []
    property bool updateRunning: false
    property int updateCount: 0

    function loadUpdateCache() {
        try {
            var data = JSON.parse(String(cfg.updateCache || "{}"))
            updateState = (data && typeof data === "object") ? data : ({})
        } catch (e) { updateState = ({}) }
    }

    function updatesDue() {
        if (!cfg.checkImageUpdates || updateRunning) return false
        var every = Math.max(1, cfg.updateCheckHours) * 3600 * 1000
        return Date.now() - (updateState["__checked"] || 0) >= every
    }

    function applyUpdates() {
        var n = 0
        for (var i = 0; i < records.length; i++) {
            var u = updateState[records[i].image]
            records[i].updateAvailable = !!u && u.state === "update"
            if (records[i].updateAvailable) n++
        }
        updateCount = n
    }

    /* Ask the registry about each distinct image, one at a time, and only on a
       slow schedule: a check is a network round trip per image. */
    function startUpdateCheck() {
        if (updateRunning || !cfg.checkImageUpdates) return
        var refs = []
        records.forEach(function (r) {
            if (Parsers.isCheckableImage(r.image) && refs.indexOf(r.image) < 0) refs.push(r.image)
        })
        if (refs.length === 0) return
        updateQueue = refs
        updateRunning = true
        updateState["__before"] = Object.keys(updateState).filter(function (k) { return updateState[k].state === "update" }).join("\n")
        nextUpdateCheck()
    }

    function nextUpdateCheck() {
        if (updateQueue.length === 0) { finishUpdateCheck(); return }
        var ref = updateQueue[0]
        updateQueue = updateQueue.slice(1)
        var cmd = expand(cfg.updateCheckCommand, { "image": shellQuote(ref) })
        runner.run(cmd, "update-check", function (code, out) {
            updateState[ref] = { "state": code === 0 ? Parsers.compareDigests(out) : "unknown" }
            backend.nextUpdateCheck()
        })
    }

    function finishUpdateCheck() {
        var before = String(updateState["__before"] || "").split("\n")
        delete updateState["__before"]
        updateState["__checked"] = Date.now()
        updateRunning = false
        var fresh = Object.keys(updateState).filter(function (k) {
            return k.indexOf("__") !== 0 && updateState[k].state === "update" && before.indexOf(k) < 0
        })
        try { cfg.updateCache = JSON.stringify(updateState) } catch (e) { /* cache is optional */ }
        applyUpdates(); syncModel(); revision++
        if (fresh.length > 0 && cfg.useNotifications && cfg.notifyOnUpdate)
            notify(i18n("Docker"), i18np("A newer image is available: %2", "Newer images are available: %2", fresh.length, fresh.slice(0, 4).join(", ")), "update")
    }

    /* "Update": pull the newer image and recreate the container from it. */
    function updateContainer(rec) {
        if (!rec) return
        muteContainer(rec.id)
        if (rec.project !== "" && Parsers.isSafeToken(rec.project) && Parsers.isSafeToken(rec.service)) {
            composeRun(rec, "update-service", rec.name)
            return
        }
        // A plain `docker run` container cannot be recreated for you (its run
        // options are not stored), so only the pull is possible.
        pullImage(rec)
    }

    // ======================================================== compose ======

    /*
     * Project-level actions through the compose CLI. The project's own files
     * and folder (read from the labels Docker recorded) are passed explicitly,
     * so this works from anywhere and not only inside the project directory.
     */
    function composeRun(rec, verb, label) {
        if (!rec || rec.project === "" || !Parsers.isSafeToken(rec.project)) {
            backend.actionDone(label || rec.name, i18n("This container is not part of a Compose project"), false)
            return
        }
        var base = expand(cfg.composeCommand, {}) + " -p " + rec.project + " "
            + Parsers.composeFileArgs(rec.composeFiles, shellQuote)
        var steps = {
            "up": base + " up -d",
            "down": base + " down",
            "pull": base + " pull",
            "recreate": base + " up -d --force-recreate",
            "update": base + " pull && " + base + " up -d",
            "update-service": Parsers.isSafeToken(rec.service)
                ? base + " pull " + rec.service + " && " + base + " up -d " + rec.service : ""
        }
        var cmd = steps[verb]
        if (!cmd) return
        if (rec.composeWorkDir) cmd = "cd " + shellQuote(rec.composeWorkDir) + " && " + cmd
        var title = i18n("Compose %1 — %2", verb.replace("-service", ""), rec.project)
        var members = groupMembers(groupKeyOf(rec))
        for (var i = 0; i < members.length; i++) muteContainer(members[i].id)
        backend.outputReady(title, i18n("Starting…"))
        runner.run(cmd, "compose-" + verb, function (code, out, err) {
            var text = (out || "") + (err ? (out ? "\n" : "") + err : "")
            backend.outputReady(title, text || i18n("(no output)"))
            backend.actionDone(label || rec.project, code === 0 ? i18n("Done") : i18n("Failed — see the output"), code === 0)
            backend.refresh({ "withStats": false })
        })
    }

    // ===================================================== resources =======

    property var resources: ({ "images": [], "volumes": [], "networks": [] })
    property bool resourcesBusy: false

    function fetchResources(kind) {
        var key = { "images": "imagesCommand", "volumes": "volumesCommand", "networks": "networksCommand" }[kind]
        if (!key) return
        resourcesBusy = true
        runner.run(expand(cfg[key], {}), "res-" + kind, function (code, out, err) {
            var list = []
            if (code === 0) {
                list = kind === "images" ? Parsers.parseImages(out)
                     : (kind === "volumes" ? Parsers.parseVolumes(out) : Parsers.parseNetworks(out))
                backend.lastError = ""
            } else {
                backend.actionDone(i18n("Docker"), firstLine(err) || i18n("Could not read %1", kind), false)
            }
            var all = backend.resources
            all[kind] = list
            backend.resources = ({ "images": all.images, "volumes": all.volumes, "networks": all.networks })
            backend.resourcesBusy = false
        })
    }

    function removeResource(kind, item) {
        var key = { "images": "removeImageCommand", "volumes": "removeVolumeCommand", "networks": "removeNetworkCommand" }[kind]
        var label = item.name || item.ref || item.id
        var cmd = expand(cfg[key], { "id": item.id || "", "name": shellQuote(item.name || "") })
        if (kind === "images" && !/^[0-9a-f]+$/.test(item.id)) return
        if (kind === "networks" && !/^[0-9a-f]+$/.test(item.id)) return
        runner.run(cmd, "rm-" + kind, function (code, out, err) {
            backend.reportResult(label, i18n("Removed"), i18n("Could not remove"), code, out, err)
            backend.fetchResources(kind)
        })
    }

    // ============================================================ extras ====

    /* Restart everything that is running and unhealthy (the middle-click option). */
    function restartUnhealthy() {
        var bad = records.filter(function (r) { return r.isRunning && r.health === "unhealthy" })
        if (bad.length === 0) { actionDone(i18n("Docker"), i18n("Nothing is unhealthy"), true); return }
        bad.forEach(function (r) { restartContainer(r) })
    }

    /* One-off, non-interactive command inside a running container. */
    function execOnce(rec, command, callback) {
        if (!rec || !rec.isRunning || String(command).trim() === "") return
        var cmd = engineBinary + " exec " + Parsers.shortId(rec.id) + " sh -c " + shellQuote(command)
        runner.run(cmd, "exec", function (code, out, err) {
            callback(code, (out || "") + (err ? (out ? "\n" : "") + err : ""))
        })
    }

    // =================================================== notifications =====

    property string notifTitle: ""
    property string notifText: ""
    property string notifEvent: "event"

    Notification {
        id: notifier
        componentName: "dockmoid"
        eventId: backend.notifEvent
        title: backend.notifTitle
        text: backend.notifText
    }

    /* kind picks the event in dockmoid.notifyrc — event, crash, unhealthy — so
       each can be given its own sound or popup behaviour in System Settings. */
    function notify(title, message, kind) {
        if (!cfg.useNotifications) return
        notifTitle = title
        notifText = message
        notifEvent = kind || "event"
        notifier.sendEvent()
    }

    // ===================================================== host detection ==

    /* LAN address of the interface that routes to the internet, and the
       Tailscale address if tailscale is installed and up. Only ever used when
       the settings leave the corresponding field empty. */
    function detectHosts() {
        if (!cfg.autoDetectHosts) return
        runner.run("ip -4 route get 1.1.1.1 2>/dev/null | awk '{for (i = 1; i < NF; i++) if ($i == \"src\") {print $(i + 1); exit}}' | grep . || hostname -I 2>/dev/null | awk '{print $1}'",
                   "lan-ip", function (code, out) {
            var ip = String(out || "").trim()
            if (code === 0 && /^[0-9.]+$/.test(ip)) detectedLanHost = ip
        })
        runner.run("tailscale ip -4 2>/dev/null | head -n 1", "tailscale-ip", function (code, out) {
            var ip = String(out || "").trim()
            if (/^[0-9.]+$/.test(ip)) detectedTailscaleHost = ip
        })
    }

    Component.onCompleted: {
        reloadIconLibrary()
        loadUpdateCache()
        detectContextHost()
        detectTools()
        detectHosts()
        detectLaunchers()
    }

}
