import QtQuick
import org.kde.notification

import QtCore
import org.kde.kirigami as Kirigami

import "../../lib/parsers.js" as Parsers
import "../../lib/icons.js" as Icons
import "../../lib/engines.js" as Engines
import "../../lib/actions.js" as Actions

/*
 * DockerBackend — everything the UI is allowed to know about Docker.
 *
 * All docker/podman access funnels through here, which keeps the QML views
 * free of command strings and gives us exactly one place where quoting,
 * placeholder expansion and error reporting are handled.
 *
 * Commands are all shell fragments, so they inherit the Plasma session environment and PATH. Terminal shell aliases are
 * not loaded by the noninteractive shell; use executable paths or wrappers. The only
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
    property string previewMode:"off"
    property string previewRecordId:""
    function previewContainer(id,selected) {
        if(previewMode === "hover" || (previewMode === "selection" && selected)) previewRecordId=id
    }


    // ----------------------------------------------------------- state ----
    property bool engineActive: false
    /* false until the very first detection finishes, so the UI can tell
       "not started yet" apart from "the daemon is down". */
    property bool engineKnown: false
    property bool refreshing: false
    property string lastError: ""
    property string actionError: ""
    property bool dataStale: false
    property int generation: 0
    property int pendingActions: 0
    property var operations: ({})
    property int operationsRevision: 0
    function operationFor(id) {
        const rec = findRecord(id)
        return operations[id] || (rec ? operations["name:" + rec.name] : null) || ({busy:false,label:"",ok:true,finishedAt:0})
    }
    function beginOperation(rec, label) {
        if (!rec || operationFor(rec.id).busy) return false
        const state = {busy:true,label:label,ok:true,finishedAt:0}
        const next = Object.assign({}, operations)
        next[rec.id] = state; next["name:" + rec.name] = state
        operations = next; operationsRevision++
        return true
    }
    function finishOperation(rec, ok, label) {
        if (!rec) return
        const state = {busy:false,label:label || (ok ? i18n("Done") : i18n("Failed")),ok:ok,finishedAt:Date.now()}
        const next = Object.assign({}, operations)
        next[rec.id] = state; next["name:" + rec.name] = state
        operations = next; operationsRevision++
    }
    Timer {
        interval: 1000; repeat: true; running: Object.keys(backend.operations).length > 0
        onTriggered: {
            let next = Object.assign({}, backend.operations), changed = false
            Object.keys(next).forEach(function(key) {
                if (!next[key].busy && Date.now() - next[key].finishedAt > 8000) { delete next[key]; changed = true }
            })
            if (changed) { backend.operations = next; backend.operationsRevision++ }
        }
    }
    property bool initialized: false
    property string endpointHost: ""
    readonly property bool remoteEngine: /^(ssh|tcp|http|https):/.test(endpointHost)
    readonly property bool canControlService: !remoteEngine && contextName === "" && !isPodman
        && /^unix:\/\/(?:\/var)?\/run\/docker\.sock$/.test(endpointHost)
    readonly property bool isPodman: /(?:^|\/)podman(?:\s|$)/.test(engineBase)
    /* What to call the engine in text the user reads. */
    readonly property string engineName: isPodman ? i18n("Podman") : i18n("Docker")
    property bool composeAvailable: false
    property bool buildxAvailable: false
    property bool curlAvailable: false
    readonly property bool canUseCompose: composeAvailable && /^unix:/.test(endpointHost) && !isPodman
    readonly property bool readOnly: cfg.readOnly === true
    readonly property string dataDir: decodeURIComponent(String(StandardPaths.writableLocation(StandardPaths.GenericDataLocation)).replace(/^file:\/\//, ""))
    CustomIconStore { id: customStore; cfg: backend.cfg; runner: backend.runner }
    readonly property var customIconStore: customStore
    DeploymentController { id: deploymentController; backend: deploymentController.parent }
    readonly property var deployment: deploymentController
    DoctorController {id:doctorController;backend:doctorController.parent}
    readonly property var doctor: doctorController


    property int running: 0
    property int total: 0
    property int stopped: 0
    property int notCreated: 0
    property var configuredServices: []
    property string discoveryError: ""
    property bool discovering: false
    property double discoveryAt: 0
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
    /* Recent changes, newest first: {time, kind, id, name, text}. Capped at 100. */
    property var activity: []

    property int outputRequestCounter: 0
    property var outputRequestSequences: ({})
    property string activeBatchRequestId: ""
    property var latestOutputRequest: null
    property bool outputRequestPending: false

    /* Ordered list of container records; the ListModel is a mirror of it. */
    property var records: []

    readonly property bool busy: runner ? runner.busy : false

    signal refreshed()
    signal engineStateChanged(bool active)
    /* Emitted when something the user did finished (or failed) so the UI can
       surface a notification. */
    signal actionDone(string title, string message, bool ok)
    /* Legacy signal retained for the live update batch; other output is
       delivered with stable request metadata below. */
    signal outputReady(string title, string content)
    signal correlatedOutputReady(string kind, string recordId, int contextGeneration,
                                 string requestId, int sequence, string title, string content)
    signal recordOutput(string kind, string recordId, int contextGeneration,
                        string requestId, int sequence, string content)

    function newOutputRequest(kind, recordId) {
        outputRequestCounter++
        var requestId = String(generation) + ":" + String(outputRequestCounter)
        latestOutputRequest = {kind: kind, recordId: recordId || "", generation: generation, requestId: requestId}
        outputRequestPending = true
        return requestId
    }

    function consumeOutputRequest(requestId) {
        if (latestOutputRequest && latestOutputRequest.requestId === requestId)
            outputRequestPending = false
    }

    function nextOutputSequence(requestId) {
        var next = Object.assign({}, outputRequestSequences)
        next[requestId] = (next[requestId] || 0) + 1
        outputRequestSequences = next
        return next[requestId]
    }

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
            if (queuedRefresh !== null) {
                const opts = queuedRefresh
                queuedRefresh = null
                Qt.callLater(function () { backend.refresh(opts) })
            }
        }
    }
    /* A refresh asked for while one was running; it runs once that finishes. */
    property var queuedRefresh: null
    function requestRefresh(opts) {
        if (refreshing) queuedRefresh = opts
        else refresh(opts)
    }

    function run(cmd, tag, done, options) {
        if (!runner) return
        var epoch = generation
        var mutation = !runner.isPoll(tag) && !/^(icon-import|update-check|capabilities|validate-compose|diagnostic|lan-ip|tailscale-ip)/.test(tag)
        if (mutation && readOnly) {
            if (done) Qt.callLater(function () { done(126, "", i18n("Read-only mode is enabled")) })
            return
        }
        if (mutation) pendingActions++
        runner.run(cmd, tag, function (code, out, err) {
            if (epoch !== backend.generation) return
            if (mutation) backend.pendingActions = Math.max(0, backend.pendingActions - 1)
            if (done) done(code, out, err)
        }, options || (mutation ? {timeout: 600000} : {}))
    }

    /* Substitute {placeholders} in a command. split/join rather than replace so
       a value containing "$" or "\" can never be re-interpreted. */
    function expand(cmd, vars) {
        if (!cmd) return ""
        var out = Engines.template(cmd, isPodman).split("{engine}").join(engineBinary)
        for (let key in vars) {
            out = out.split("{" + key + "}").join(String(vars[key]))
        }
        return out
    }

    // ============================================================ contexts ====

    property var contexts: []
    property string contextHost: ""

    function fetchContexts() {
        run(isPodman ? engineBase + " system connection list --format '{{.Name}}'" : expand(cfg.contextListCommand, {}), "contexts", function (code, out) {
            if (code !== 0) { contexts = []; return }
            contexts = String(out || "").split("\n").map(function (l) { return l.trim() })
                .filter(function (l) { return Parsers.isSafeToken(l) })
        })
    }

    /* Point everything at another engine and start over from a clean slate. */
    function setContext(name) {
        if (pendingActions > 0) {
            actionDone(i18n("Connection"), i18n("Wait for the current action to finish before switching hosts."), false)
            return
        }
        cfg.activeContext = name
        Qt.callLater(reconnect)
    }

    function reconnect() {
        if (!initialized) return
        generation++
        operations = ({}); operationsRevision++
        if (batchUpdating) {
            batchUpdating = false
            batchStatus = i18n("Update batch cancelled because the connection changed")
            batchResults = batchResults.concat([batchStatus])
        }
        if (runner) runner.cancelAll()
        pendingTasks = 0; pendingActions = 0; refreshing = false
        records = []; lastListOut = ""; syncModel(); revision++
        policyCache = ({}); statsCache = ({}); statsUpdatedMs = 0; statsInFlight=false; history = ({}); alertState = ({})
        configuredServices = []; discoveryAt = 0; discoveryError = ""
        probeState = ({}); updateState = ({}); updateQueue = []; updateRunning = false; updateCount = 0
        lastSnapshot = null; engineInfo = ({}); diskUsage = []; diskUsageKnown = false
        engineKnown = false; engineActive = false; dataStale = false
        lastInfoMs = 0; lastDiskMs = 0; lastUpdatedMs = 0; lastLabelIds = ""; labelCache = ({})
        resourceLists = ({images: [], volumes: [], networks: []}); resourceUpdatedAt=({})
        resourcesBusy = false; lastFullMs = 0; lastEventSec = 0; eventsFailedMs = 0
        dropEventWait(); eventWaitFailedMs = 0
        detectContextHost(); detectCapabilities(); reloadIconLibrary()
        loadUpdateCache()
        refresh({force: true, withStats: true})
    }

    onEngineBinaryChanged: if (initialized) Qt.callLater(reconnect)

    /* A remote engine's own address is what published ports should link to. */
    function detectContextHost() {
        contextHost = ""; endpointHost = ""
        if (isPodman) return
        var query = engineBase + " context inspect " + (contextName || "")
            + " --format '{{.Endpoints.docker.Host}}'"
        var cmd = contextName !== "" ? query : "if [ -n \"$DOCKER_HOST\" ]; then printf '%s' \"$DOCKER_HOST\"; else " + query + "; fi"
        run(cmd, "context-host", function (code, out) {
            backend.endpointHost = code === 0 ? String(out).trim() : ""
            var m = /^(?:ssh|tcp|https?):\/\/(?:[^@\/]+@)?([^:\/]+)/.exec(backend.endpointHost)
            if (m) backend.contextHost = m[1]
        })
    }

    function detectCapabilities() {
        var cmd = "if " + expand(cfg.composeCommand, {}) + " version >/dev/null 2>&1; then echo compose; fi; "
            + "if " + engineBinary + " buildx version >/dev/null 2>&1; then echo buildx; fi; "
            + "if command -v curl >/dev/null 2>&1; then echo curl; fi"
        run(cmd, "capabilities", function (code, out) {
            backend.composeAvailable = /(^|\n)compose(\n|$)/.test(out)
            backend.buildxAvailable = !backend.isPodman && /(^|\n)buildx(\n|$)/.test(out)
            backend.curlAvailable = /(^|\n)curl(\n|$)/.test(out)
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
        for (let i = 0; i < records.length; i++) {
            let r = records[i]
            let pin = pinnedNames.indexOf(r.name)
            r.pinned = pin >= 0
            /* Pinned, then needs-attention, running, stopped, not created; by name inside each. */
            const group = pin >= 0 ? "pinned" : isProblem(r) ? "attention" : r.isRunning ? "running"
                : r.state === "not-created" ? "not-created" : "stopped"
            r.stateGroup = group
            r.sortKey = (pin >= 0 ? "0" + ("000" + pin).slice(-3)
                : group === "attention" ? "1" : group === "running" ? "2" : group === "stopped" ? "3" : "4")
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
    property double statsUpdatedMs: 0
    property double eventsFailedMs: 0
    property int downTicks: 0

    /* Whether the cheap change check works with this engine and these settings. */
    /* A function, not a binding: Date.now() is not tracked, so a binding would
       never notice that the ten minutes have passed. */
    function eventsUsable() {
        return eventsFailedMs === 0 || Date.now() - eventsFailedMs > 10 * 60 * 1000
    }

    /* Set by main.qml: whether the popup or detached window is showing. */
    property bool viewOpen: false
    /* Set by the view: whether per-container usage is on screen. */
    property bool usageDetailShown: true

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
        // While closed and kept current by change events, the safety net can relax.
        var seconds = !viewOpen && eventsUsable()
            ? Math.max(cfg.updateInterval, cfg.idleUpdateInterval) : cfg.updateInterval
        if (Date.now() - lastFullMs >= Math.max(5, seconds) * 1000) {
            // A failed list read re-probes the engine, so no separate check first.
            refresh({ "withStats": false, "skipDetect": true })
            return
        }
        if (eventWaitUsable()) startEventWait()
        else if (eventsUsable()) checkForChanges()
    }

    /*
     * One sleeping helper waits for the first change event instead of a new
     * `events --until` query every few seconds. It ends after a few minutes, on
     * an event or with the widget; a failure falls back to polling for a while.
     */
    property bool eventWaiting: false
    property int eventWaitSerial: 0
    property double eventWaitFailedMs: 0
    function eventWaitUsable() {
        return cfg.waitForEvents === true
            && /\{until\}/.test(String(cfg.eventsCommand || ""))
            && (eventWaitFailedMs === 0 || Date.now() - eventWaitFailedMs > 10 * 60 * 1000)
    }

    function eventWaitCommand() {
        // Docker takes fractional seconds, so an event just before the list
        // read is not replayed; Podman is given whole seconds.
        var now = Date.now() / 1000
        var since = lastEventSec > 0 ? lastEventSec : now
        since = isPodman ? Math.floor(since) : since.toFixed(3)
        var stream = expand(String(cfg.eventsCommand).replace(/\s*--until[= ]\{until\}/, ""), { "since": since })
        const script = decodeURIComponent(String(Qt.resolvedUrl("../../scripts/wait_events.py")).replace(/^file:\/\//, ""))
        // exec: the helper becomes the child of plasmashell, so it notices when that goes.
        return "exec python3 -I " + shellQuote(script) + " 240 " + shellQuote(stream)
    }

    function startEventWait() {
        if (eventWaiting || !runner || !engineActive) return
        eventWaiting = true
        var serial = ++eventWaitSerial
        var epoch = generation
        runner.spawn(eventWaitCommand(), function (code, out, err) {
            if (serial !== backend.eventWaitSerial) return
            backend.eventWaiting = false
            if (epoch !== backend.generation) return
            if (code !== 0) {
                if (backend.cfg.debugCommands) console.log("[backend] event wait failed:", code, err)
                // Poll for a while; if the daemon went away, the re-check says so
                // and its return clears this again.
                backend.eventWaitFailedMs = Date.now()
                backend.refresh({ "force": true, "withStats": false })
                return
            }
            if (String(out || "").trim() !== "") {
                backend.refresh({ "withStats": false, "skipDetect": true })
                // Let the burst settle (compose up starts several at once).
                eventWaitRestart.restart()
            } else if (backend.engineActive) {
                backend.startEventWait()
            }
        })
    }

    onEngineActiveChanged: {
        if (engineActive) eventWaitFailedMs = 0
        else dropEventWait()
    }

    /* Forget a waiter that belongs to an old connection; it exits by itself. */
    function dropEventWait() {
        eventWaitSerial++
        eventWaiting = false
        eventWaitRestart.stop()
    }

    Timer {
        id: eventWaitRestart
        interval: 1500
        onTriggered: if (backend.eventWaitUsable()) backend.startEventWait()
    }

    function poll() { tick() }

    function checkForChanges() {
        var until = Math.floor(Date.now() / 1000)
        var since = lastEventSec > 0 ? Math.floor(lastEventSec) : until
        var cmd = expand(cfg.eventsCommand, { "since": since, "until": until })
        beginTask()
        run(cmd, "events", function (code, out) {
            if (code !== 0) {
                // Old engine, odd wrapper, wrong flags: fall back to plain
                // polling for a while rather than failing every tick.
                backend.eventsFailedMs = Date.now()
                backend.endTask()
                backend.refresh({ "force": true, "withStats": false })
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
        if (opts.force) discoveryAt = 0
        if (engineKnown && !engineActive && !opts.force) return

        beginTask()
        if (opts.skipDetect && engineActive) {
            backend.loadEverything(opts)
            backend.endTask()
            return
        }
        run(expand(cfg.checkActiveCommand, {}), "detect", function (code, out, err) {
            var active = detectActive(code, out)
            if (active !== backend.engineActive) {
                backend.engineActive = active
                backend.engineStateChanged(active)
            }
            backend.engineKnown = true
            backend.dataStale = !active
            backend.engineProblem = active ? "" : backend.classifyProblem(code, out, err)
            if (!active) {
                backend.lastError = err || String(out || "").trim() || i18n("The engine is unreachable")
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

    function probeEngineOnly() {
        run(expand(cfg.checkActiveCommand, {}), "detect", function (code, out, err) {
            var active = backend.detectActive(code, out)
            if (backend.engineActive !== active) backend.engineStateChanged(active)
            backend.engineActive = active; backend.engineKnown = true
            backend.engineProblem = active ? "" : backend.classifyProblem(code, out, err)
            if (!active) backend.dataStale = true
        })
    }

    function loadEverything(opts) {
        lastFullMs = Date.now()
        lastEventSec = Date.now() / 1000
        fetchList()
        fetchInfo()

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
        // Keep the last successful snapshot visible only as explicitly stale data.
        dataStale = true
        engineActive = false
        lastSnapshot = null
    }

    function discoverConfiguredServices(force) {
        if (!canUseCompose || remoteEngine || discovering || (!force && Date.now() - discoveryAt < 60000)) return
        discovering = true
        const script = decodeURIComponent(String(Qt.resolvedUrl("../../scripts/discover_compose.py")).replace(/^file:\/\//,""))
        run("python3 " + shellQuote(script) + " " + shellQuote(deployment.projectRoot), "discovery-compose", function(code,out,err) {
            backend.discovering = false; backend.discoveryAt = Date.now()
            try {
                if (code !== 0) throw Error(i18n("Compose discovery could not run. Check Python and Compose availability."))
                const result = JSON.parse(out)
                backend.configuredServices = result.services || []
                backend.discoveryError = (result.errors || []).join("\n")
                backend.mergeConfiguredServices()
                backend.applySort(); backend.syncModel(); backend.recomputeTotals(); backend.revision++
            } catch(e) { backend.discoveryError = String(e) }
        }, {timeout:120000})
    }
    function mergeConfiguredServices() {
        const existing = records.filter(function(r) { return r.state !== "not-created" })
        const configured = configuredServices.filter(function(service) {
            return !existing.some(function(rec) {
                return (rec.project === service.project && rec.service === service.service) || rec.name === service.name
            })
        }).map(function(service) {
            const rec = Parsers.normalizeContainer({ID:"configured:" + service.project + ":" + service.service,
                Names:service.name, Image:service.image, State:"not-created", Status:i18n("Undeployed")})
            rec.project=service.project;rec.service=service.service;rec.composeFiles=service.composeFiles;rec.composeWorkDir=service.composeWorkDir
            rec.composeProfile=(service.profiles || []).join(",")
            return rec
        })
        records = existing.concat(configured)
    }

    /* The last list output; an identical read skips all re-processing. */
    property string lastListOut: ""

    function fetchList() {
        beginTask()
        run(expand(cfg.listCommand, {}), "list", function (code, out, err) {
            if (code !== 0) {
                lastError = err || String(out || "").trim() || i18n("Could not read containers (exit %1)", code)
                dataStale = true
                backend.probeEngineOnly()
            } else if (!Parsers.isValidRecords(out)) {
                lastError = i18n("The container command did not return valid JSON")
                dataStale = true
            } else if (out === backend.lastListOut) {
                // Nothing changed since the last read: keep the records, the
                // model and every binding on them as they are.
                dataStale = false
                lastError = ""
                lastUpdatedMs = Date.now()
                if (updatesDue()) Qt.callLater(startUpdateCheck)
                discoverConfiguredServices(false)
                refreshRestartPoliciesIfNeeded()
            } else {
                dataStale = false
                lastError = ""
                lastUpdatedMs = Date.now()
                backend.lastListOut = out
                records = Parsers.parseContainers(out)
                enrichLabels()
                mergeConfiguredServices()
                discoverConfiguredServices(false)
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

    property string lastLabelIds: ""
    property var labelCache: ({})

    function enrichLabels() {
        var ids = records.map(function (r) { return Parsers.shortId(r.id) }).filter(function (id) { return /^[a-f0-9]+$/.test(id) })
        var key = ids.slice().sort().join(" ")
        if (key === "") return
        if (key === lastLabelIds) { applyStructuredLabels(); if (updatesDue()) Qt.callLater(startUpdateCheck); return }
        lastLabelIds = key
        var format = "{\"Id\":{{json .Id}},\"Labels\":{{json .Config.Labels}},\"ImageId\":{{json .Image}},\"ImageRef\":{{json .Config.Image}}}"
        beginTask()
        run(engineBinary + " inspect --format " + shellQuote(format) + " " + ids.join(" "), "labels", function (code, out) {
            if (code === 0) {
                backend.labelCache = ({})
                Parsers.jsonRecords(out).forEach(function (r) { backend.labelCache[Parsers.shortId(r.Id)] = r })
                backend.applyStructuredLabels(); backend.syncModel(); backend.revision++
                if (backend.updatesDue()) backend.startUpdateCheck()
            } else { backend.lastLabelIds = ""; backend.lastListOut = "" }
            backend.endTask()
        })
    }

    function applyStructuredLabels() {
        records.forEach(function (r) {
            var data = backend.labelCache[Parsers.shortId(r.id)]
            if (!data) return
            var labels = data.Labels || {}
            r.composeFiles = labels["com.docker.compose.project.config_files"] || r.composeFiles
            r.composeWorkDir = labels["com.docker.compose.project.working_dir"] || r.composeWorkDir
            r.imageId = data.ImageId || ""
            if (data.ImageRef) r.image = data.ImageRef
        })
    }

    // ============================================== restart policies ======

    property var policyCache: ({})
    property double lastPolicyMs: 0

    /* Policies rarely change, so they are re-read on a slow timer — or at once
       when a container shows up that has no entry yet. */
    function refreshRestartPoliciesIfNeeded() {
        var missing = false
        for (let i = 0; i < records.length; i++) {
            if (policyCache[Parsers.shortId(records[i].id)] === undefined) { missing = true; break }
        }
        var due = Date.now() - lastPolicyMs >= Math.max(10, cfg.restartPolicyInterval) * 1000
        if (missing || due) fetchRestartPolicies()
    }

    function fetchRestartPolicies() {
        if (!Engines.supports("restartPolicies", isPodman)) return
        lastPolicyMs = Date.now()
        beginTask()
        run(expand(cfg.restartPolicyCommand, {}), "policies", function (code, out) {
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
        if (!Engines.supports("restartPolicies", isPodman)) return
        if (!rec || Parsers.RESTART_POLICIES.indexOf(policy) < 0) return
        var cmd = expand(cfg.setRestartPolicyCommand, {
            "id": Parsers.shortId(rec.id), "policy": policy,
            "name": shellQuote(rec.name)
        })
        muteContainer(rec.id)
        run(cmd, "restart-policy", function (code, out, err) {
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
    function activityText(ev) {
        switch (ev.kind) {
        case "crashed": return i18n("%1 exited with code %2", ev.name, ev.code)
        case "restarting": return i18n("%1 is restarting", ev.name)
        case "unhealthy": return i18n("%1 became unhealthy", ev.name)
        case "recovered": return i18n("%1 is healthy again", ev.name)
        case "started": return i18n("%1 started", ev.name)
        case "stopped": return i18n("%1 stopped", ev.name)
        default: return ""
        }
    }
    function recordActivity(events) {
        const now = Date.now()
        const added = []
        for (let i = 0; i < events.length; i++) {
            const text = activityText(events[i])
            if (text !== "") added.push({time: now, kind: events[i].kind, id: String(events[i].id || ""), name: events[i].name, text: text})
        }
        if (added.length > 0) activity = added.reverse().concat(activity).slice(0, 100)
    }

    function announceChanges() {
        var snap = Parsers.snapshotStates(records)
        var events = Parsers.diffStates(lastSnapshot, snap)
        lastSnapshot = snap
        if (events.length > 0) recordActivity(events)
        if (events.length === 0 || !cfg.useNotifications) return

        var now = Date.now()
        var enabled = {
            "crashed": cfg.notifyOnCrash, "restarting": cfg.notifyOnRestartLoop,
            "unhealthy": cfg.notifyOnUnhealthy, "recovered": cfg.notifyOnRecovered,
            "started": cfg.notifyOnStartStop, "stopped": cfg.notifyOnStartStop
        }
        var lines = []
        var worst = "event"
        for (let i = 0; i < events.length; i++) {
            let ev = events[i]
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
        for (let id in muted) if (muted[id] <= now) delete muted[id]
        if (lines.length === 0) return
        var title = lines.length === 1 ? engineName : i18np("%2: %1 change", "%2: %1 changes", lines.length, engineName)
        notify(title, lines.slice(0, 6).join("\n") + (lines.length > 6 ? "\n" + i18n("…and %1 more", lines.length - 6) : ""), worst)
    }

    property bool statsInFlight:false
    function fetchStats() {
        if (statsInFlight || !runner) return
        if (running === 0 && records.length > 0) return
        beginTask()
        statsInFlight=true
        run(expand(cfg.usageCommand, {}), "stats", function (code, out, err) {
            backend.statsInFlight=false
            if (code === 0) {
                statsCache = Parsers.parseStats(out)
                statsUpdatedMs = Date.now()
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
        if (!Engines.supports("info", isPodman)) return
        var now = Date.now()
        if (!String(cfg.infoCommand || "").trim()) return
        // Host details are only read while somebody can see them.
        if (now - lastInfoMs < (viewOpen ? 60000 : 600000)) return
        lastInfoMs = now
        beginTask()
        run(expand(cfg.infoCommand, {}), "info", function (code, out, err) {
            if (code === 0) engineInfo = Parsers.parseInfo(out)
            endTask()
        })
    }

    property double lastDiskMs: 0

    function fetchDiskUsage() {
        if (!Engines.supports("systemDf", isPodman)) return
        if (diskUsageKnown && Date.now() - lastDiskMs < 60000) return
        beginTask()
        run(expand(cfg.systemDfCommand, {}), "systemdf", function (code, out, err) {
            if (code === 0) {
                diskUsage = Parsers.parseSystemDf(out)
                diskUsageKnown = true
                lastDiskMs = Date.now()
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
            "stateGroup": rec.stateGroup || "",
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
                   "probe", "probeMs", "updateAvailable", "sortKey", "stateGroup",
                   "groupKey", "searchKey"]

    function rowChanged(existing, row) {
        for (let i = 0; i < rowKeys.length; i++) {
            let k = rowKeys[i]
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
        for (let i = 0; i < records.length; i++) wanted[records[i].id] = true

        // Ids in model order, kept in step with every change below, so finding
        // a row is one native indexOf instead of a model.get() per candidate.
        var order = new Array(model.count)
        for (let k = 0; k < model.count; k++) order[k] = model.get(k).id

        for (let k = order.length - 1; k >= 0; k--) {
            if (!wanted[order[k]]) { model.remove(k); order.splice(k, 1) }
        }

        for (let j = 0; j < records.length; j++) {
            let row = copyRow(records[j])
            let at = order[j] === row.id ? j : order.indexOf(row.id, j)
            if (at === -1) {
                model.insert(j, row)
                order.splice(j, 0, row.id)
            } else {
                if (at !== j) {
                    model.move(at, j, 1)
                    order.splice(at, 1)
                    order.splice(j, 0, row.id)
                }
                if (rowChanged(model.get(j), row)) model.set(j, row)
            }
        }
    }

    /* Whatever needs a look: unhealthy, restarting, dead, paused or exited badly. */
    function isProblem(row) {
        var state = row.containerState !== undefined ? row.containerState : row.state
        var status = row.status || ""
        // Health can remain stale after a container exits; only active unhealthy
        // containers should color the panel status ring red.
        if (row.health === "unhealthy" && (row.isRunning === true || state === "running")) return true
        if (row.probe === "down" && (row.isRunning === true || state === "running")) return true
        if (state === "restarting" || state === "dead" || state === "paused") return true
        if (state === "exited") {
            let code = Parsers.exitCodeFromStatus(status)
            return code !== null && !Parsers.isDeliberateExit(code)
        }
        return false
    }

    property int problemCount: 0

    function recomputeTotals() {
        var n = 0
        for (let p = 0; p < records.length; p++) if (isProblem(records[p])) n++
        problemCount = n
        var agg = Parsers.aggregate(records)
        total = records.length
        running = agg.running
        pausedCount = agg.paused
        unhealthy = agg.unhealthy
        cpuSum = agg.cpuSum
        memSum = agg.memSum
        pids = agg.pids
        notCreated = records.filter(function(r) { return r.state === "not-created" }).length
        stopped = Math.max(0, records.length - running - pausedCount - notCreated)
    }

    /* id -> record, rebuilt only when the records array itself is replaced.
       The cache is a plain object held by a property that never changes, so
       filling it inside a binding does not invalidate that binding. */
    readonly property var recordCache: ({source: null, map: ({})})
    function findRecord(id) {
        const cache = recordCache
        if (cache.source !== records) {
            const map = {}
            for (let i = 0; i < records.length; i++) map[records[i].id] = records[i]
            cache.map = map
            cache.source = records
        }
        return cache.map[id] || null
    }

    // =============================================== presentation helpers ==

    /* Published ports treated as https, parsed once from the config string. */
    readonly property var httpsPorts: {
        var raw = String(cfg.httpsPorts || "").split(",")
        var out = []
        for (let i = 0; i < raw.length; i++) {
            let v = parseInt(raw[i].trim(), 10)
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
        if (configured !== "") {
            const expanded = Icons.expandHome(configured, homeDir)
            const oldDefault = dataDir + "/dockmoid/icons/svg"
            if (expanded === oldDefault)
                return [dataDir + "/dockmoid/dashboard-icons/svg", expanded]
            return [expanded]
        }
        var bundled = decodeURIComponent(String(Qt.resolvedUrl("../../assets/library")).replace(/^file:\/\//, ""))
        return [dataDir + "/dockmoid/dashboard-icons/svg", dataDir + "/dockmoid/icons/selfhst/svg", dataDir + "/dockmoid/icons/svg",
                dataDir + "/dockmoid/icons",
                homeDir + "/Pictures/selfhst", homeDir + "/pictures/selfhst",
                bundled]
    }

    function reloadIconLibrary() {
        var dirs = iconLibraryCandidates().map(shellQuote).join(" ")
        // First line is the folder that won, the rest is its listing.
        var cmd = "for d in " + dirs + "; do [ -d \"$d\" ] || continue; found=; for f in \"$d\"/*.svg \"$d\"/*.png \"$d\"/*.webp; do if [ -f \"$f\" ]; then found=1; break; fi; done; [ -n \"$found\" ] || continue; echo \"$d\"; ls -1 \"$d\"; break; done"
        run(cmd, "icons", function (code, out) {
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
        function onCustomIconsChanged() { backend.iconCache = ({}); backend.iconRevision++ }
        function onCustomIconFilesChanged() { backend.iconCache = ({}); backend.iconRevision++ }

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
        var custom = customStore.urlFor(rec)
        if (custom) return custom
        var key = iconRevision + "|" + rec.name + "|" + rec.image + "|" + rec.service + "|" + rec.project
            + "|" + cfg.iconVariant + "|" + darkTheme + "|" + cfg.coloredServiceIcons + "|" + useIconLibrary
        var hit = iconCache[key]
        if (hit) return hit
        var result = ({ "url": "", "colored": false, "hidden": false })
        if (useIconLibrary) {
            let rule = Icons.ruleMatch(iconRules, rec.name + " " + rec.image + " " + rec.service)
            let name = null
            if (rule === undefined) {
                name = Icons.libraryMatch(iconEntries,
                    Icons.libraryCandidates(rec.name, rec.service, rec.image, rec.project))
            } else if (rule !== null && iconEntries[rule.toLowerCase()]) {
                name = rule.toLowerCase()
            }
            if (rule === null) result.hidden = true
            if (name !== null) {
                let file = Icons.libraryFile(iconEntries, name, cfg.iconVariant, darkTheme)
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
    function browserKey(rec) { return engineBinary + "|" + (rec.project && rec.service ? rec.project + "/" + rec.service : rec.name) }
    function browserSettings(value) { try { return JSON.parse(value || "{}") } catch(e) { return {} } }
    function allLinksFor(rec) {
        if (!rec || !cfg.enableBrowserLinks) return []
        const links = Parsers.buildLinks(rec.ports, {lanHost:lanHost,tailscaleHost:tailscaleHost,
            allowLan:cfg.allowLanLinks,allowTailscale:cfg.allowTailscaleLinks,httpsPorts:httpsPorts})
            .filter(function(link) { return !backend.remoteEngine || ["localhost","127.0.0.1","::1"].indexOf(link.host) < 0 })
        return links.map(function(link) {
            return Object.assign({}, link, {port:String(link.port),url:Parsers.linkUrl(link),
                title:i18n("%1 · %2",link.label,String(link.port))})
        })
    }
    function linksFor(rec) {
        if (!rec) return []
        const key = browserKey(rec)
        const hidden = browserSettings(cfg.hiddenBrowserPorts)[key] || []
        const preferred = browserSettings(cfg.preferredBrowserLinks)[key] || ""
        return allLinksFor(rec).filter(function(link) { return hidden.indexOf(String(link.port)) < 0 })
            .sort(function(a,b) { return Number(b.url === preferred) - Number(a.url === preferred) })
    }
    function preferBrowserLink(rec, link) {
        const next = browserSettings(cfg.preferredBrowserLinks)
        if (link) next[browserKey(rec)] = link.url || Parsers.linkUrl(link)
        else delete next[browserKey(rec)]
        cfg.preferredBrowserLinks = JSON.stringify(next); revision++
    }
    function browserPortVisible(rec, port) { return (browserSettings(cfg.hiddenBrowserPorts)[browserKey(rec)] || []).indexOf(String(port)) < 0 }
    function showBrowserPort(rec, port, visible) {
        const next = browserSettings(cfg.hiddenBrowserPorts), key = browserKey(rec)
        let ports = next[key] || []
        ports = ports.filter(function(value) { return value !== String(port) })
        if (!visible) ports.push(String(port))
        next[key] = ports; cfg.hiddenBrowserPorts = JSON.stringify(next); revision++
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
        for (let k in (extra || {})) vars[k] = extra[k]
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
        const labels = {startOneCommand:i18n("Starting…"),stopOneCommand:i18n("Stopping…"),restartOneCommand:i18n("Restarting…"),killOneCommand:i18n("Stopping…"),pauseOneCommand:i18n("Pausing…"),unpauseOneCommand:i18n("Resuming…"),removeOneCommand:i18n("Removing…")}
        if (!beginOperation(rec, labels[commandKey] || i18n("Working…"))) return
        muteContainer(rec.id)
        run(cmd, commandKey, function (code, out, err) {
            backend.finishOperation(rec, code === 0, code === 0 ? successText : backend.firstLine(err) || i18n("Action failed"))
            backend.reportResult(rec.name, successText, i18n("Command failed"), code, out, err)
            backend.refresh({ "withStats": false })
        })
    }

    /*
     * What this container allows right now (lib/actions.js), with this
     * backend's mode, connection and in-flight operation filled in. Views
     * read it in bindings, so it depends on revision and operationsRevision.
     */
    function actionsFor(rec) {
        void revision; void operationsRevision
        return Actions.allowed(rec, actionContext(rec))
    }
    /* The same, ignoring an action already in flight: what to show (greyed while busy). */
    function stateActionsFor(rec) {
        void revision; void operationsRevision
        return Actions.allowed(rec, Object.assign(actionContext(rec), {busy: false}))
    }
    function primaryActionFor(rec) {
        void revision; void operationsRevision
        return Actions.primary(rec, actionContext(rec))
    }
    function actionContext(rec) {
        return {
            readOnly: readOnly,
            engineActive: engineActive,
            busy: !!rec && operationFor(rec.id).busy === true,
            compose: !!rec && canUseCompose && !!rec.project && !!rec.service
        }
    }

    /* Run a direct action if it is allowed; refused actions do nothing. */
    function runAction(rec, action) {
        if (!rec || actionsFor(rec)[action] !== true) return false
        switch (action) {
        case "create":
        case "start": startContainer(rec); break
        case "stop": stopContainer(rec); break
        case "restart": restartContainer(rec); break
        case "pause": pauseContainer(rec); break
        case "resume": unpauseContainer(rec); break
        case "kill": killContainer(rec); break
        case "forceRestart": forceRestartContainer(rec); break
        default: return false
        }
        return true
    }

    function startContainer(rec) {
        if (rec && rec.state === "not-created") { composeRun(rec, "create-service", rec.name); return }
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
        run(cmd, "rename", function (code, out, err) {
            backend.reportResult(rec.name, i18n("Renamed to %1", newName),
                                 i18n("Could not rename container"), code, out, err)
            backend.refresh({ "withStats": false })
        })
    }

    /* Pull runs long enough that its output is worth watching, so it is
       streamed to the shared output panel instead of being swallowed. */
    function pullImage(rec, done, requestId, requestGeneration) {
        if (!rec) return
        var epoch = requestGeneration === undefined ? generation : requestGeneration
        if (epoch !== generation) return
        requestId = requestId || newOutputRequest("pull", rec.id)
        consumeOutputRequest(requestId)
        var cmd = expand(cfg.pullImageCommand, containerVars(rec))
        var title = i18n("Pulling %1", rec.image)
        if (!beginOperation(rec, i18n("Pulling image…"))) { if (done) done(false, i18n("An action is already running")); return }
        backend.correlatedOutputReady("pull", rec.id, epoch, requestId, 0, title, i18n("Starting…"))
        run(cmd, "pull", function (code, out, err) {
            var text = (out || "") + (err ? (out ? "\n" : "") + err : "")
            backend.correlatedOutputReady("pull", rec.id, epoch, requestId, 0, title, text || i18n("(no output)"))
            backend.finishOperation(rec, code === 0, code === 0 ? i18n("Image pulled only") : backend.firstLine(err) || i18n("Pull failed"))
            backend.actionDone(rec.name, code === 0 ? i18n("Image pulled. Existing containers keep their current image until recreated.")
                : firstLine(err) || i18n("Pull failed (exit %1)", code), code === 0)
            if (code === 0) {
                backend.invalidateImage(rec.image)
                backend.updateState[rec.image] = {state: "unchecked", pulled: true}
                backend.saveUpdateCache()
            }
            if (done) done(code === 0, text)
            backend.refresh({ "withStats": false })
        })
    }

    /*
     * opts.images  — also remove every unused image, not just dangling ones
     * opts.containers — explicitly remove stopped container instances
     * Both default to off. Volumes and networks are never pruned here.
     */
    function cleanupCommand(opts) {
        opts = opts || {}
        // Deliberately avoid system prune: it always removes stopped containers.
        let commands = []
        if (opts.containers === true) commands.push(engineBinary + " container prune -f")
        commands.push(engineBinary + " image prune -f" + (opts.images === true ? " -a" : ""))
        commands.push(engineBinary + " builder prune -f")
        return commands.join(" && ")
    }
    function prune(opts, requestId, requestGeneration) {
        if (isPodman || !Engines.supports("resources", isPodman)) { actionDone(i18n("Clean up"), i18n("Cleanup is unavailable for this engine."), false); return }
        var epoch = requestGeneration === undefined ? generation : requestGeneration
        if (epoch !== generation) return
        requestId = requestId || newOutputRequest("prune", "")
        consumeOutputRequest(requestId)
        opts = opts || {}
        const cmd = cleanupCommand(opts)
        run(cmd, "prune", function (code, out, err) {
            var text = (out || "") + (err ? (out ? "\n" : "") + err : "")
            backend.correlatedOutputReady("prune", "", epoch, requestId, 0,
                                          i18n("Prune"), text || i18n("(no output)"))
            backend.actionDone(engineName, code === 0 ? i18n("Prune finished") : i18n("Prune failed"), code === 0)
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
        run("for b in " + names.join(" ") + "; do command -v \"$b\" >/dev/null 2>&1 && echo \"$b\"; done",
                   "tools", function (code, out) {
            var found = {}
            String(out || "").split("\n").forEach(function (l) { if (l.trim() !== "") found[l.trim()] = true })
            for (let i = 0; i < terminalChoices.length; i++) {
                if (found[terminalChoices[i][0]]) { detectedTerminal = terminalChoices[i][1]; break }
            }
            for (let j = 0; j < editorChoices.length; j++) {
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
        for (let i = 0; i < launchers.length; i++) {
            let bin = launchers[i].binary
            if (/^[A-Za-z0-9._+-]+$/.test(bin) && !seen[bin]) { seen[bin] = true; names.push(bin) }
        }
        if (names.length === 0) { installedBinaries = ({}); return }
        run("for b in " + names.join(" ") + "; do command -v \"$b\" >/dev/null 2>&1 && echo \"$b\"; done",
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
        for (let i = 0; i < launchers.length; i++) {
            let l = launchers[i]
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
        if (readOnly) { actionDone(i18n("Dockmoid"), i18n("Read-only mode is enabled"), false); return }
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
            run(check, "shell-check", function (code) {
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

    function openContainerFolder(rec) {
        if (!rec || remoteEngine) { actionDone(i18n("Open folder"), i18n("Remote folders cannot be opened locally."), false); return }
        let directory = String(rec.composeWorkDir || "")
        if (!directory && rec.composeFiles) {
            const file = Parsers.firstFile(rec.composeFiles)
            directory = file.slice(0, file.lastIndexOf("/"))
        }
        if (directory.charAt(0) === "/" && !/[\x00-\x1f]/.test(directory)) { Qt.openUrlExternally("file://" + directory.split("/").map(encodeURIComponent).join("/")); return }
        const id = Parsers.shortId(rec.id)
        if (!/^[0-9a-fA-F]+$/.test(id)) return
        run(engineBinary + " inspect --format '{{json .Mounts}}' " + id, "inspect-folder", function(code,out,err) {
            if (code === 0) {
                try {
                    const mounts = JSON.parse(out)
                    const bind = mounts.find(function(m) { return m.Type === "bind" && String(m.Source).charAt(0) === "/" })
                    if (bind && !/[\x00-\x1f]/.test(String(bind.Source))) {
                        const source = String(bind.Source)
                        const cmd = "if test -d " + backend.shellQuote(source) + "; then printf '%s' " + backend.shellQuote(source) + "; else dirname -- " + backend.shellQuote(source) + "; fi"
                        backend.run(cmd, "inspect-folder-path", function(pathCode,pathOut) {
                            const folder = String(pathOut).trim()
                            if (pathCode === 0 && folder.charAt(0) === "/") Qt.openUrlExternally("file://" + folder.split("/").map(encodeURIComponent).join("/"))
                            else backend.actionDone(rec.name, i18n("Could not locate the container folder."), false)
                        })
                        return
                    }
                } catch(e) { }
            }
            backend.actionDone(rec.name, i18n("No local project folder or bind mount was found."), false)
        })
    }

    /* Open the compose file that defines a container, if it has one. */
    function editCompose(rec) {
        if (!rec || remoteEngine) { actionDone(i18n("Compose"), i18n("Remote files cannot be opened as local paths."), false); return }
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
        for (let i = 0; i < records.length; i++) {
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
        for (let i = 0; i < records.length; i++) {
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
        for (let i = 0; i < members.length; i++) muteContainer(members[i].id)
        run(cmd, commandKey, function (code, out, err) {
            backend.reportResult(groupKey, successText, i18n("Command failed"), code, out, err)
            backend.refresh({ "withStats": false })
        })
    }

    function startGroup(groupKey) { runOnGroup(groupKey, "groupStartCommand", "startOneCommand", i18n("Group started")) }
    function stopGroup(groupKey) { runOnGroup(groupKey, "groupStopCommand", "stopOneCommand", i18n("Group stopped")) }
    function restartGroup(groupKey) { runOnGroup(groupKey, "groupRestartCommand", "restartOneCommand", i18n("Group restarted")) }

    // ---- engine ----

    function startEngine() {
        if (!canControlService) { actionDone(engineName, i18n("Local service control is unavailable for this connection."), false); return }
        run(expand(cfg.startCommand, {}), "engine-start", function (code, out, err) {
            // The daemon needs a moment before the socket answers; give it a
            // beat, then re-probe rather than reporting a stale failure.
            probeDelay.restart()
            if (code !== 0) {
                backend.actionDone(engineName, firstLine(err) || i18n("Could not start Docker"), false)
            }
        })
    }

    function stopEngine() {
        if (!canControlService) {
            actionDone(engineName, i18n("Service control is only available for the local system engine."), false)
            return
        }
        run(expand(cfg.stopServiceCommand, {}), "engine-stop", function (code, out, err) {
            if (code !== 0) {
                backend.actionDone(engineName, firstLine(err) || i18n("Could not stop Docker"), false)
                backend.refresh({force: true, withStats: false})
                return
            }
            backend.run(expand(cfg.stopSocketCommand, {}), "engine-socket", function (socketCode, socketOut, socketErr) {
                backend.actionDone(engineName, socketCode === 0 ? i18n("Stop requested; checking engine state…")
                    : firstLine(socketErr) || i18n("Could not stop the Docker socket"), socketCode === 0)
                probeDelay.restart()
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
    function fetchLogs(rec, tail, requestId, requestGeneration) {
        if (!rec) return
        var epoch = requestGeneration === undefined ? generation : requestGeneration
        if (epoch !== generation) return
        requestId = requestId || newOutputRequest("logs", rec.id)
        consumeOutputRequest(requestId)
        var sequence = nextOutputSequence(requestId)
        var cmd = expand(cfg.logsCommand, containerVars(rec, { "tail": parseInt(tail, 10) || 200 }))
        run(cmd, "logs", function (code, out, err) {
            if (epoch !== backend.generation || backend.outputRequestSequences[requestId] !== sequence) return
            var text = (out || "")
            if (err) text += (text ? "\n" : "") + err
            var content = text || i18n("(no output)")
            backend.recordOutput("logs", rec.id, epoch, requestId, sequence, content)
            backend.correlatedOutputReady("logs", rec.id, epoch, requestId, sequence,
                                          logsTitle(rec), content)
        })
    }

    /* The title is presentation only; pages correlate logs by request token. */
    function logsTitle(rec) {
        return i18n("Logs — %1", rec ? rec.name : "")
    }

    function fetchInspect(rec, requestId, requestGeneration) {
        if (!rec) return
        var epoch = requestGeneration === undefined ? generation : requestGeneration
        if (epoch !== generation) return
        requestId = requestId || newOutputRequest("inspect", rec.id)
        consumeOutputRequest(requestId)
        var sequence = nextOutputSequence(requestId)
        var cmd = expand(cfg.inspectCommand, containerVars(rec))
        run(cmd, "inspect", function (code, out, err) {
            if (epoch !== backend.generation || backend.outputRequestSequences[requestId] !== sequence) return
            var title = i18n("Inspect — %1", rec.name)
            if (code !== 0) {
                const failure = firstLine(err) || i18n("Could not inspect container")
                backend.recordOutput("inspect", rec.id, epoch, requestId, sequence, failure)
                backend.correlatedOutputReady("inspect", rec.id, epoch, requestId, sequence, title, failure)
                return
            }
            var content = prettyJson(out)
            backend.recordOutput("inspect", rec.id, epoch, requestId, sequence, content)
            backend.correlatedOutputReady("inspect", rec.id, epoch, requestId, sequence, title, content)
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
        for (let i = 0; i < records.length; i++) {
            let r = records[i]
            if (!r.isRunning) continue
            alive[r.id] = true
            let h = history[r.id] || { "cpu": [], "mem": [] }
            h.cpu = Parsers.pushSample(h.cpu, r.cpuPct, max)
            h.mem = Parsers.pushSample(h.mem, r.memPct, max)
            history[r.id] = h
        }
        for (let id in history) if (!alive[id]) delete history[id]
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
        notify(engineName, lines.join("\n"), "resource")
    }

    // ============================================================ probes ====

    property var probeState: ({})
    property var lastProbeUp: ({})
    readonly property var probeRules: Parsers.parseProbeRules(cfg.probes)

    function probeTargets() {
        var out = {}
        for (let i = 0; i < records.length; i++) {
            let r = records[i]
            if (!r.isRunning) continue
            let url = Parsers.probeUrlFor(r, probeRules)
            if (url !== "") out[r.id] = url
        }
        return out
    }

    function applyProbes() {
        for (let i = 0; i < records.length; i++) {
            let r = records[i]
            let url = r.isRunning ? Parsers.probeUrlFor(r, probeRules) : ""
            let res = url !== "" ? probeState[url] : undefined
            r.probe = res ? (res.up ? "up" : "down") : ""
            r.probeMs = res ? res.ms : 0
        }
    }

    property bool probesRunning: false

    function runProbes() {
        if (!engineActive || !curlAvailable || probesRunning) return
        var targets = probeTargets()
        var urls = []
        for (let id in targets) if (urls.indexOf(targets[id]) < 0) urls.push(targets[id])
        if (urls.length === 0) { if (Object.keys(probeState).length > 0) { probeState = ({}); applyProbes(); syncModel() } return }
        probesRunning = true
        var list = urls.map(shellQuote).join(" ")
        var cmd = "n=0; for u in " + list + "; do (r=$(curl -s -o /dev/null -m 5 -w '%{http_code} %{time_total}' \"$u\" 2>/dev/null); printf '%s %s\\n' \"$u\" \"${r:-000 0}\") & n=$((n+1)); if [ $((n%4)) -eq 0 ]; then wait; fi; done; wait"
        run(cmd, "probes", function (code, out) {
            backend.probesRunning = false
            backend.probedAtMs = Date.now()
            var res = Parsers.parseProbeResults(out)
            var before = backend.probeState
            backend.probeState = res
            backend.announceProbeChanges(before, res)
            backend.applyProbes(); backend.syncModel(); backend.recomputeTotals(); backend.revision++
        }, {timeout: Math.max(10000, Math.ceil(urls.length / 4) * 6000)})
    }

    function announceProbeChanges(before, after) {
        if (!cfg.useNotifications || !cfg.notifyOnProbe) return
        var lines = []
        for (let i = 0; i < records.length; i++) {
            let r = records[i]
            let url = Parsers.probeUrlFor(r, probeRules)
            if (url === "" || !before[url] || !after[url]) continue
            if (muted[r.id] && muted[r.id] > Date.now()) continue
            if (before[url].up && !after[url].up) lines.push(i18n("%1 stopped answering at %2", r.name, url))
            else if (!before[url].up && after[url].up) lines.push(i18n("%1 answers again", r.name))
        }
        if (lines.length > 0) notify(engineName, lines.join("\n"), "probe")
    }

    /* Nobody sees probe results while the view is closed unless they notify,
       so the panel colour is then kept current on the slower schedule. */
    readonly property bool probesNotify: cfg.useNotifications === true && cfg.notifyOnProbe === true
    Timer {
        id: probeTimer
        interval: Math.max(15, backend.viewOpen || backend.probesNotify
                               ? backend.cfg.probeInterval
                               : Math.max(backend.cfg.probeInterval, backend.cfg.probeIdleInterval)) * 1000
        repeat: true
        running: backend.engineActive && backend.records.length > 0
        onTriggered: backend.runProbes()
    }
    property double probedAtMs: 0
    onViewOpenChanged: {
        // After a quiet spell the last results can be minutes old.
        if (viewOpen && probeTimer.running
                && Date.now() - probedAtMs > Math.max(15, cfg.probeInterval) * 1000)
            Qt.callLater(runProbes)
    }

    // ===================================================== image updates ====

    property var updateState: ({})
    property var updateQueue: []
    property bool updateRunning: false
    property int updateCount: 0

    function loadUpdateCache() {
        try {
            let data = JSON.parse(String(cfg.updateCache || "{}"))
            updateState = data.__hosts && data.__hosts[engineBinary] ? data.__hosts[engineBinary] : ({})
        } catch (e) { updateState = ({}) }
    }

    function saveUpdateCache() {
        var data
        try { data = JSON.parse(String(cfg.updateCache || "{}")) } catch (e) { data = {} }
        if (!data.__hosts) data = {__hosts: {}}
        data.__hosts[engineBinary] = updateState
        cfg.updateCache = JSON.stringify(data)
    }

    function invalidateImage(image) {
        delete updateState[image]
        updateState.__checked = 0
        saveUpdateCache(); applyUpdates(); syncModel(); revision++
    }

    function updatesDue() {
        if (!cfg.checkImageUpdates || !buildxAvailable || updateRunning) return false
        var every = Math.max(1, cfg.updateCheckHours) * 3600 * 1000
        return Date.now() - (updateState["__checked"] || 0) >= every
    }

    function applyUpdates() {
        var n = 0
        for (let i = 0; i < records.length; i++) {
            let u = updateState[records[i].image]
            records[i].updateAvailable = !!u && u.state === "update"
            records[i].updateState = updateRunning ? "checking" : u ? u.state : buildxAvailable ? "unchecked" : "unsupported"
            records[i].imagePulled = !!u && u.pulled === true
            if (records[i].updateAvailable) n++
        }
        updateCount = n
    }

    /* Ask the registry about each distinct image, one at a time, and only on a
       slow schedule: a check is a network round trip per image. */
    function startUpdateCheck(force) {
        if (updateRunning || (!cfg.checkImageUpdates && !force) || !buildxAvailable) return
        var refs = []
        records.forEach(function (r) {
            if (Parsers.isCheckableImage(r.image) && refs.indexOf(r.image) < 0) refs.push(r.image)
        })
        if (refs.length === 0) return
        updateQueue = refs
        updateRunning = true
        applyUpdates(); syncModel(); revision++
        updateState["__before"] = Object.keys(updateState).filter(function (k) { return updateState[k] && updateState[k].state === "update" }).join("\n")
        nextUpdateCheck()
    }

    function nextUpdateCheck() {
        if (updateQueue.length === 0) { finishUpdateCheck(); return }
        var ref = updateQueue[0]
        updateQueue = updateQueue.slice(1)
        var used = records.find(function (r) { return r.image === ref && r.imageId })
        var template = String(cfg.updateCheckCommand || "")
        var cmd = expand(template, { "image": shellQuote(ref) })
        if (used && template.indexOf("image inspect {image}") >= 0)
            cmd = cmd.replace("image inspect " + shellQuote(ref), "image inspect " + shellQuote(used.imageId))
        run(cmd, "update-check", function (code, out) {
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
            return k.indexOf("__") !== 0 && updateState[k] && updateState[k].state === "update" && before.indexOf(k) < 0
        })
        try { saveUpdateCache() } catch (e) { /* cache is optional */ }
        applyUpdates(); syncModel(); revision++
        if (fresh.length > 0 && cfg.useNotifications && cfg.notifyOnUpdate)
            notify(engineName, i18np("A newer image is available: %2", "Newer images are available: %2", fresh.length, fresh.slice(0, 4).join(", ")), "update")
    }

    /* "Update": pull the newer image and recreate the container from it. */
    function updateContainer(rec, done) {
        if (!rec || readOnly) { if (done) done(false, i18n("Read-only mode is enabled")); return }
        muteContainer(rec.id)
        if (rec.project && rec.service && canUseCompose) {
            composeRun(rec, rec.isRunning ? "update-service-running" : "update-service-stopped", rec.name, done)
        } else {
            // A standalone container has no saved Compose recipe from which to
            // recreate it safely. Pulling the image is the only lossless action.
            const message = i18n("Pull and recreate requires an accessible Compose service. Use Pull image only, then recreate with the original deployment configuration.")
            actionDone(rec.name, message, false)
            if (done) done(false, message)
        }
    }

    property bool batchUpdating: false
    property string batchStatus: ""
    property var batchResults: []

    function updateTargets(allRunning, includeStopped) {
        var seen = {}
        return records.filter(function (r) {
            var key = r.project && r.service ? r.project + "/" + r.service : r.id
            if (r.state === "not-created" || (!r.isRunning && !includeStopped) || (!allRunning && !r.updateAvailable) || seen[key]) return false
            seen[key] = true
            return true
        })
    }

    function updateMany(targets) {
        if (readOnly || batchUpdating || targets.length === 0) return
        batchUpdating = true; batchResults = []
        var queue = targets.slice()
        var count = queue.length
        var epoch = generation
        function next() {
            if (epoch !== backend.generation) return
            if (queue.length === 0) {
                backend.batchUpdating = false
                backend.batchStatus = i18n("Finished %1 selected actions", count)
                backend.outputReady(i18n("Update results"), backend.batchResults.join("\n\n"))
                backend.refresh({force: true, withStats: false})
                return
            }
            var rec = queue.shift()
            const recreate = rec.project && rec.service && backend.canUseCompose
            backend.batchStatus = i18n("Processing %1 (%2 of %3)", rec.name, count - queue.length, count)
            const perform = recreate ? backend.updateContainer : backend.pullImage
            perform(rec, function (ok, text) {
                if (epoch !== backend.generation) return
                backend.batchResults = backend.batchResults.concat([(ok ? "✓ " : "✗ ") + rec.name + " — " + (recreate ? i18n("Pull and recreate") : i18n("Pull image only")) + "\n" + text])
                Qt.callLater(next)
            })
        }
        next()
    }

    // ======================================================== compose ======

    /*
     * Project-level actions through the compose CLI. The project's own files
     * and folder (read from the labels Docker recorded) are passed explicitly,
     * so this works from anywhere and not only inside the project directory.
     */
    function validateCompose(rec, callback) {
        if (!canUseCompose || !rec || !rec.composeFiles) {
            callback(false, remoteEngine ? i18n("Remote Compose files need a verified local project mapping.")
                : i18n("Compose or the project's files are unavailable; use Pull image instead."))
            return
        }
        var files = String(rec.composeFiles).split(",").filter(function (f) { return f.trim() !== "" })
        var checks = files.map(function (f) { return "test -r " + backend.shellQuote(f.trim()) })
        if (rec.composeWorkDir) checks.push("test -d " + shellQuote(rec.composeWorkDir))
        run(checks.join(" && "), "validate-compose", function (code) {
            callback(code === 0, code === 0 ? "" : i18n("Compose file or working directory is not accessible on this computer."))
        })
    }

    /*
     * Read-only looks at one container, shown on the output page: processes,
     * filesystem changes, port mappings, health-check history, recent events
     * and a one-off usage sample. None of them changes anything.
     */
    function diagnosticTitle(what, rec) {
        const name = rec ? rec.name : ""
        return ({top: i18n("Processes — %1", name), diff: i18n("Filesystem Changes — %1", name),
                 port: i18n("Port Mappings — %1", name), health: i18n("Health Checks — %1", name),
                 events: i18n("Recent Events — %1", name), stats: i18n("Usage Snapshot — %1", name)})[what] || name
    }
    /* done(text), when given, receives the result instead of the output page. */
    function diagnose(rec, what, requestId, requestGeneration, done) {
        if (!rec) return
        var epoch = requestGeneration === undefined ? generation : requestGeneration
        if (epoch !== generation) return
        if (!done) {
            requestId = requestId || newOutputRequest("diagnostics", rec.id)
            consumeOutputRequest(requestId)
        }
        const id = Parsers.shortId(rec.id)
        const commands = {
            top: engineBinary + " top " + id,
            diff: engineBinary + " diff " + id,
            port: engineBinary + " port " + id,
            health: engineBinary + " inspect --format '{{json .State.Health}}' " + id,
            events: engineBinary + " events --since 24h --until 0s --filter container=" + id
                + " --format '{{.Time}} {{.Action}}'",
            stats: engineBinary + " stats --no-stream " + id
        }
        const cmd = commands[what]
        if (!cmd || !/^[a-f0-9]+$/.test(id)) return
        const title = diagnosticTitle(what, rec)
        run(cmd, "diagnostics-" + what, function (code, out, err) {
            if (epoch !== backend.generation) return
            var text = String(out || "").trim()
            if (what === "health" && code === 0) text = text === "null" || text === "" ? i18n("This container has no health check.") : backend.prettyJson(text)
            if (what === "events" && code === 0)
                text = text.split("\n").filter(function (l) { return l.trim() !== "" }).map(function (l) {
                    const parts = l.split(" "), when = new Date(Number(parts[0]) * 1000)
                    return (isNaN(when.getTime()) ? parts[0] : when.toLocaleString(Qt.locale(), Locale.ShortFormat)) + "  " + parts.slice(1).join(" ")
                }).join("\n") || i18n("No events in the last 24 hours.")
            if (what === "diff" && code === 0 && text === "") text = i18n("No changes to the container's filesystem.")
            if (code !== 0) text = backend.firstLine(err) || i18n("The command failed (exit %1).", code)
            if (done) done(text || i18n("(no output)"))
            else backend.correlatedOutputReady("diagnostics", rec.id, epoch, requestId, 0, title, text || i18n("(no output)"))
        }, {timeout: 30000})
    }

    /*
     * The facts the detail page shows beyond `ps`: restarts, last exit, start
     * time, addresses, limits and the health check. One small inspect query;
     * environment variables are deliberately left out.
     */
    function fetchFacts(rec, done) {
        if (!rec || rec.state === "not-created") return
        const id = Parsers.shortId(rec.id)
        if (!/^[a-f0-9]+$/.test(id)) return
        const format = '{"restarts":{{json .RestartCount}},"started":{{json .State.StartedAt}},"finished":{{json .State.FinishedAt}},'
            + '"exitCode":{{json .State.ExitCode}},"error":{{json .State.Error}},"oom":{{json .State.OOMKilled}},'
            + '"memory":{{json .HostConfig.Memory}},"nanoCpus":{{json .HostConfig.NanoCpus}},'
            + '"networks":{{json .NetworkSettings.Networks}},"healthcheck":{{json (index .Config "Healthcheck")}},'
            + '"user":{{json .Config.User}},"workdir":{{json .Config.WorkingDir}}}'
        run(engineBinary + " inspect --format " + shellQuote(format) + " " + id, "inspect-facts", function (code, out) {
            if (code !== 0) { done(null); return }
            try { done(Parsers.parseFacts(out)) } catch (e) { done(null) }
        })
    }

    /* The last lines of a container's log, for the inspector under the list. */
    function tailLogs(rec, lines, done) {
        if (!rec || rec.state === "not-created") { done(""); return }
        const epoch = generation
        run(expand(cfg.logsCommand, containerVars(rec, { "tail": Math.max(10, Math.min(5000, Number(lines) || 200)) })), "logs", function (code, out, err) {
            if (epoch !== backend.generation) return
            done((out || "") + (err ? (out ? "\n" : "") + err : ""))
        })
    }

    /* A Compose file's text for the inspector; capped, and only a .yml/.yaml/.json path. */
    /*
     * The file is read on this machine, so a remote engine's label path would
     * name whatever local file happens to share its spelling. Refuse instead.
     */
    function readComposeFile(path, done) {
        path = String(path || "").split(",")[0].trim()
        if (remoteEngine) { done(false, i18n("This Compose file is on the remote host %1 and cannot be read from here.", endpointHost)); return }
        if (!/^\/.+\.(ya?ml|json)$/i.test(path)) { done(false, i18n("No Compose file is recorded for this container.")); return }
        run("head -c 262144 " + shellQuote(path), "diagnostic-compose-file", function (code, out, err) {
            done(code === 0, code === 0 ? String(out || "") : backend.firstLine(err) || i18n("The file could not be read."))
        })
    }

    /* Restart without the usual grace period: a stuck container is stopped at once. */
    function forceRestartContainer(rec) {
        if (!rec || readOnly) return
        const id = Parsers.shortId(rec.id)
        if (!/^[a-f0-9]+$/.test(id) || !beginOperation(rec, i18n("Restarting…"))) return
        muteContainer(rec.id)
        run(engineBinary + " restart -t 0 " + id, "force-restart", function (code, out, err) {
            backend.finishOperation(rec, code === 0, code === 0 ? i18n("Restarted") : backend.firstLine(err) || i18n("Action failed"))
            backend.reportResult(rec.name, i18n("Container restarted"), i18n("Command failed"), code, out, err)
            backend.refresh({ "withStats": false })
        })
    }

    function composeRun(rec, verb, label, done, requestId, requestGeneration) {
        var epoch = requestGeneration === undefined ? generation : requestGeneration
        if (epoch !== generation) return
        var pending = backend.outputRequestPending ? backend.latestOutputRequest : null
        if (!requestId && pending && pending.kind === "compose"
                && pending.recordId === (rec ? rec.id : "") && pending.generation === epoch)
            requestId = pending.requestId
        requestId = requestId || newOutputRequest("compose", rec ? rec.id : "")
        consumeOutputRequest(requestId)
        var title = i18n("Compose %1 — %2", verb, rec && rec.project ? rec.project : (label || i18n("project")))
        if (!rec || !rec.project || !Parsers.isSafeToken(rec.project) || readOnly) {
            const unavailable = i18n("This Compose action is unavailable.")
            correlatedOutputReady("compose", rec ? rec.id : "", epoch, requestId, 0, title, unavailable)
            actionDone(label || i18n("Compose"), unavailable, false)
            if (done) done(false, unavailable)
            return
        }
        const tracked = ["up","stop","restart","recreate","update","update-service-running","update-service-stopped","create-service",
                         "start","pause","unpause","service-restart","service-recreate"].indexOf(verb) >= 0
        if (tracked && !beginOperation(rec, verb.indexOf("update") === 0 ? i18n("Pulling and recreating…") : i18n("Applying Compose action…"))) {
            if (done) done(false, i18n("An action is already running")); return
        }
        validateCompose(rec, function (ok, reason) {
            if (epoch !== backend.generation) return
            if (!ok) {
                if (tracked) backend.finishOperation(rec, false, reason)
                correlatedOutputReady("compose", rec.id, epoch, requestId, 0, title, reason)
                backend.actionDone(label || rec.project, reason, false)
                if (done) done(false, reason)
                return
            }
            var base = backend.expand(backend.cfg.composeCommand, {}) + " -p " + rec.project + " "
                + Parsers.composeFileArgs(rec.composeFiles, backend.shellQuote)
            var steps = {
                "create-service": Parsers.isSafeToken(rec.service) ? base + " up -d --no-deps " + rec.service : "",
                up: base + " up -d", down: base + " down", pull: base + " pull", stop: base + " stop",
                restart: base + " restart", ps: base + " ps -a",
                logs: base + " logs --no-color --tail " + Math.max(1, Math.min(10000, Number(backend.cfg.logTailLines) || 200)),
                recreate: base + " up -d --force-recreate",
                start: base + " start", pause: base + " pause", unpause: base + " unpause",
                images: base + " images", top: base + " top",
                // Validates without printing the resolved file, which can hold secrets.
                config: base + " config --quiet && echo " + backend.shellQuote(i18n("The Compose configuration is valid.")),
                "service-restart": Parsers.isSafeToken(rec.service) ? base + " restart " + rec.service : "",
                "service-recreate": Parsers.isSafeToken(rec.service) ? base + " up -d --no-deps --force-recreate " + rec.service : "",
                "service-pull": Parsers.isSafeToken(rec.service) ? base + " pull " + rec.service : "",
                "service-logs": Parsers.isSafeToken(rec.service)
                    ? base + " logs --no-color --tail " + Math.max(1, Math.min(10000, Number(backend.cfg.logTailLines) || 200)) + " " + rec.service : "",
                update: base + " pull && " + base + " up -d",
                "update-service-running": Parsers.isSafeToken(rec.service)
                    ? base + " pull " + rec.service + " && " + base + " up -d --no-deps --force-recreate " + rec.service : "",
                "update-service-stopped": Parsers.isSafeToken(rec.service)
                    ? base + " pull " + rec.service + " && " + base + " up --no-start --no-deps --force-recreate " + rec.service : ""
            }
            var cmd = steps[verb]
            if (!cmd) {
                const unsupported = i18n("Unsupported action")
                if (tracked) backend.finishOperation(rec, false, unsupported)
                correlatedOutputReady("compose", rec.id, epoch, requestId, 0, title, unsupported)
                if (done) done(false, unsupported)
                return
            }
            if (rec.composeWorkDir) cmd = "cd " + backend.shellQuote(rec.composeWorkDir) + " && " + cmd
            backend.muteContainer(rec.id)
            backend.correlatedOutputReady("compose", rec.id, epoch, requestId, 0, title, i18n("Starting…"))
            backend.run(cmd, "compose-" + verb, function (code, out, err) {
                var text = (out || "") + (err ? (out ? "\n" : "") + err : "")
                backend.correlatedOutputReady("compose", rec.id, epoch, requestId, 0,
                                              title, text || i18n("(no output)"))
                if (tracked) backend.finishOperation(rec, code === 0, code === 0 ? (verb === "update-service-stopped" ? i18n("Updated · left stopped") : i18n("Completed")) : backend.firstLine(err) || i18n("Failed"))
                backend.actionDone(label || rec.project, code === 0 ? i18n("Done") : backend.firstLine(err) || i18n("Failed — see the output"), code === 0)
                if (code === 0) { backend.lastLabelIds = ""; backend.lastListOut = ""; backend.invalidateImage(rec.image) }
                if (done) done(code === 0, text)
                backend.refresh({withStats: false})
            }, {timeout: 15 * 60 * 1000})
        })
    }

    // ===================================================== resources =======

    property var resourceLists: ({ "images": [], "volumes": [], "networks": [] })
    property bool resourcesBusy: false
    property var resourceErrors: ({})
    property var resourceLoading: ({})
    function configuredForImage(item) {
        function canonical(value) {
            let image=String(value||"").replace(/^docker.io\//,"").replace(/^library\//,"")
            if (image.indexOf(":",image.lastIndexOf("/"))<0 && image.indexOf("@")<0) image+=":latest"
            return image
        }
        return configuredServices.filter(function(service){return canonical(service.image)===canonical(item.ref)}).map(function(service){
            return backend.records.find(function(rec){return rec.project===service.project&&rec.service===service.service}) || service
        })
    }
    function containersForResource(kind, item) {
        return records.filter(function(rec) {
            if (rec.state === "not-created") return false
            if (kind === "images") {
                const a = String(rec.imageId || "").replace(/^sha256:/, "")
                const b = String(item.id || "").replace(/^sha256:/, "")
                return (a && b && (a.indexOf(b) === 0 || b.indexOf(a) === 0)) || rec.image === item.ref
            }
            if (kind === "networks") return String(rec.networks || "").split(",").some(function(n) { return n.trim() === item.name })
            return String(rec.mounts || "").split(",").some(function(n) { return n.trim() === item.name })
        })
    }

    property var resourceUpdatedAt: ({})
    function fetchResources(kind, force) {
        if(resourceLoading[kind] || (force===false && Date.now()-Number(resourceUpdatedAt[kind]||0)<30000))return
        if (!Engines.supports("resources", isPodman)) { actionDone(i18n("Resources"), i18n("Resource browsing is not supported by this engine yet."), false); return }
        var key = { "images": "imagesCommand", "volumes": "volumesCommand", "networks": "networksCommand" }[kind]
        if (!key) return
        let loading = Object.assign({}, resourceLoading); loading[kind] = true; resourceLoading = loading
        let errors = Object.assign({}, resourceErrors); errors[kind] = ""; resourceErrors = errors
        resourcesBusy = true
        run(expand(cfg[key], {}), "res-" + kind, function (code, out, err) {
            var list = []
            if (code === 0) {
                const updated=Object.assign({},backend.resourceUpdatedAt);updated[kind]=Date.now();backend.resourceUpdatedAt=updated
                list = kind === "images" ? Parsers.parseImages(out)
                     : (kind === "volumes" ? Parsers.parseVolumes(out) : Parsers.parseNetworks(out))
                backend.lastError = ""
            } else {
                const reason = firstLine(err) || i18n("Could not read %1", kind)
                let errors = Object.assign({}, backend.resourceErrors); errors[kind] = reason; backend.resourceErrors = errors
                backend.actionDone(engineName, reason, false)
            }
            var all = Object.assign({}, backend.resourceLists)
            if (code === 0) all[kind] = list
            backend.resourceLists = ({ "images": all.images, "volumes": all.volumes, "networks": all.networks })
            let loading = Object.assign({}, backend.resourceLoading); loading[kind] = false; backend.resourceLoading = loading
            backend.resourcesBusy = Object.keys(loading).some(function(key) { return loading[key] })
        })
    }

    function removeResource(kind, item) {
        if (isPodman || readOnly) { actionDone(i18n("Resources"), i18n("Removal is unavailable in this engine or mode."), false); return }
        var key = { "images": "removeImageCommand", "volumes": "removeVolumeCommand", "networks": "removeNetworkCommand" }[kind]
        var label = item.name || item.ref || item.id
        var cmd = expand(cfg[key], { "id": item.id || "", "name": shellQuote(item.name || "") })
        if (kind === "images" && !/^(?:sha256:)?[0-9a-f]+$/.test(item.id)) return
        if (kind === "networks" && !/^(?:sha256:)?[0-9a-f]+$/.test(item.id)) return
        run(cmd, "rm-" + kind, function (code, out, err) {
            backend.reportResult(label, i18n("Removed"), i18n("Could not remove"), code, out, err)
            backend.fetchResources(kind)
        })
    }

    /* Inspect or layer history of an image, volume or network, as text. Read-only. */
    function resourceInfo(kind, item, what, done) {
        const id = String(item.id || "")
        const safeId = /^(?:sha256:)?[0-9a-f]+$/.test(id)
        var cmd = ""
        if (kind === "images" && safeId) cmd = what === "history"
            ? engineBinary + " history --format " + shellQuote("table {{.CreatedSince}}\t{{.Size}}\t{{.CreatedBy}}") + " " + id
            : engineBinary + " image inspect " + id
        else if (kind === "volumes" && item.name) cmd = engineBinary + " volume inspect " + shellQuote(item.name)
        else if (kind === "networks" && safeId) cmd = engineBinary + " network inspect " + id
        if (!cmd) { done(i18n("This resource cannot be inspected.")); return }
        run(cmd, "diagnostic-resource-" + what, function (code, out, err) {
            done(code === 0 ? (what === "history" ? String(out || "") : backend.prettyJson(out)) : backend.firstLine(err) || i18n("The command failed (exit %1).", code))
        }, {timeout: 30000})
    }

    /* Pull the newest copy of an image by its reference. */
    function pullImageRef(ref) {
        if (readOnly || !/^[A-Za-z0-9][A-Za-z0-9._\/:@-]*$/.test(String(ref || ""))) return
        actionDone(ref, i18n("Pulling…"), true)
        run(engineBinary + " pull " + shellQuote(ref), "pull-image", function (code, out, err) {
            backend.reportResult(ref, i18n("Image is up to date"), i18n("Pull failed"), code, out, err)
            backend.fetchResources("images", true)
            backend.invalidateImage(ref)
        }, {timeout: 15 * 60 * 1000})
    }

    /* Attach a container to a network, or detach it. */
    function networkConnect(network, rec, connect) {
        if (readOnly || !rec || !network) return
        const id = Parsers.shortId(rec.id)
        if (!/^[a-f0-9]+$/.test(id) || !Parsers.isSafeToken(network.name)) return
        run(engineBinary + " network " + (connect ? "connect " : "disconnect ") + network.name + " " + id, "network-" + (connect ? "connect" : "disconnect"), function (code, out, err) {
            backend.reportResult(rec.name, connect ? i18n("Connected to %1", network.name) : i18n("Disconnected from %1", network.name),
                                 i18n("Network change failed"), code, out, err)
            backend.fetchResources("networks", true)
            backend.refresh({ "withStats": false })
        })
    }

    // ============================================================ extras ====

    /* Restart everything that is running and unhealthy (the middle-click option). */
    function restartUnhealthy() {
        var bad = records.filter(function (r) { return r.isRunning && r.health === "unhealthy" })
        if (bad.length === 0) { actionDone(engineName, i18n("Nothing is unhealthy"), true); return }
        bad.forEach(function (r) { restartContainer(r) })
    }

    /* One-off, non-interactive command inside a running container. */
    function execOnce(rec, command, callback) {
        if (readOnly) { callback(126, i18n("Read-only mode is enabled")); return }
        if (!rec || !rec.isRunning || String(command).trim() === "") { callback(126, i18n("A running container and command are required.")); return }
        var shells = ["/bin/sh", "/bin/bash", "/bin/ash"]
        function tryShell(index) {
            if (index >= shells.length) { callback(127, i18n("This container has no supported shell.")); return }
            var prefix = backend.engineBinary + " exec " + Parsers.shortId(rec.id) + " " + shells[index]
            backend.run(prefix + " -c true", "shell-check", function (code) {
                if (code !== 0) { tryShell(index + 1); return }
                backend.run(prefix + " -c " + backend.shellQuote(command), "exec", function (exitCode, out, err) {
                    callback(exitCode, (out || "") + (err ? (out ? "\n" : "") + err : ""))
                })
            })
        }
        tryShell(0)
    }

    // =================================================== notifications =====

    property string notifTitle: ""
    property string notifText: ""
    property string notifEvent: "event"

    Notification {
        id: notifier
        componentName: "dockmoid"
        eventId: backend.notifEvent
        iconName: "dockmoid"
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
        run("ip -4 route get 1.1.1.1 2>/dev/null | awk '{for (i = 1; i < NF; i++) if ($i == \"src\") {print $(i + 1); exit}}' | grep . || hostname -I 2>/dev/null | awk '{print $1}'",
                   "lan-ip", function (code, out) {
            var ip = String(out || "").trim()
            if (code === 0 && /^[0-9.]+$/.test(ip)) detectedLanHost = ip
        })
        run("tailscale ip -4 2>/dev/null | head -n 1", "tailscale-ip", function (code, out) {
            var ip = String(out || "").trim()
            if (/^[0-9.]+$/.test(ip)) detectedTailscaleHost = ip
        })
    }

    Component.onCompleted: {
        initialized = true
        detectCapabilities()
        reloadIconLibrary()
        loadUpdateCache()
        detectContextHost()
        detectTools()
        detectHosts()
        detectLaunchers()
    }

}
