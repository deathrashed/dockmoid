import QtQuick
import org.kde.plasma.plasma5support as Plasma5Support

/* Every invocation has a unique source. A late result can never satisfy a retry.
 * Cancellation disconnects the local process; an operation already accepted by
 * a remote daemon may still complete. Callers must re-probe to learn its state. */
Item {
    id: runner
    visible: false
    width: 0
    height: 0
    property int maxConcurrent: 2
    property int timeout: 60000
    property bool debug: false
    property var queue: []
    property var active: ({})
    property var detached: []
    property int activeCount: 0
    property int serial: 0
    readonly property bool busy: activeCount > 0 || queue.length > 0
    readonly property int pending: queue.length
    signal commandStarted(string cmd, string tag)
    signal commandFinished(string cmd, string tag, int exitCode, string stdout, string stderr)

    function isPoll(tag) {
        return /^(discovery|detect|events|list|labels|stats|info|systemdf|policies|icons|tools|launchers|logs|inspect|probes|contexts|context-host|res-)/.test(tag || "")
    }

    function run(cmd, tag, onDone, options) {
        if (!cmd || !String(cmd).trim()) {
            if (onDone) Qt.callLater(function () { onDone(127, "", i18n("No command configured")) })
            return
        }
        // Coalesce reads only. Two explicit mutations must remain two actions.
        if (isPoll(tag)) {
            for (let source in active) {
                if (active[source].cmd === cmd) {
                    if (onDone) active[source].callbacks.push(onDone)
                    return
                }
            }
            for (let i = 0; i < queue.length; i++) {
                if (queue[i].cmd === cmd) {
                    if (onDone) queue[i].callbacks.push(onDone)
                    return
                }
            }
        }
        serial++
        queue.push({cmd: cmd, tag: tag || "", callbacks: onDone ? [onDone] : [],
                    source: String(cmd) + "\n# dockmoid-job-" + Date.now() + "-" + serial,
                    startedAt: 0, timeout: options && options.timeout ? options.timeout : timeout})
        Qt.callLater(pump)
    }

    function spawn(cmd, onDone) {
        if (!cmd) return
        serial++
        var source = String(cmd) + "\n# dockmoid-launch-" + Date.now() + "-" + serial
        detached.push({cmd: cmd, source: source, startedAt: Date.now(), onDone: onDone || null})
        if (debug) console.log("[runner] launch:", cmd)
        commandSource.connectSource(source)
    }

    function pump() {
        while (activeCount < maxConcurrent && queue.length > 0) {
            let entry = queue.shift()
            entry.startedAt = Date.now()
            active[entry.source] = entry
            activeCount++
            if (debug) console.log("[runner] start:", entry.tag)
            commandStarted(entry.cmd, entry.tag)
            commandSource.connectSource(entry.source)
        }
    }

    function reap() {
        var now = Date.now()
        var expired = Object.keys(active).filter(function (source) {
            return now - active[source].startedAt > active[source].timeout
        })
        expired.forEach(function (source) {
            runner.finish(source, -1, "", i18n("Command timed out; an operation already accepted by the engine may still complete."))
        })
        // Editors/terminals are detached deliberately; do not kill them after a minute.
    }

    function finish(source, code, out, err) {
        var entry = active[source]
        commandSource.disconnectSource(source)
        if (!entry) return
        delete active[source]
        activeCount = Math.max(0, activeCount - 1)
        if (debug) console.log("[runner] done:", entry.tag, "code=" + code)
        commandFinished(entry.cmd, entry.tag, code, out, err)
        for (let i = 0; i < entry.callbacks.length; i++) {
            try { entry.callbacks[i](code, out, err) }
            catch (e) { console.error("[runner] callback failed:", entry.tag, e) }
        }
        Qt.callLater(pump)
    }

    function cancelAll() {
        var queued = queue
        queue = []
        for (let source of Object.keys(active)) {
            finish(source, -2, "", i18n("Cancelled; an operation already accepted by the engine may still complete."))
        }
        for (let entry of queued) {
            for (let done of entry.callbacks) done(-2, "", i18n("Cancelled"))
        }
        // Launched editors/terminals belong to the user and outlive a refresh.
    }

    Plasma5Support.DataSource {
        id: commandSource
        engine: "executable"
        connectedSources: []
        interval: 0
        onNewData: function (source, data) {
            // Some engines publish a placeholder before completion.
            if (data["exit code"] === undefined) return
            var code = parseInt(data["exit code"], 10)
            if (isNaN(code)) code = -1
            var index = runner.detached.findIndex(function (job) { return job.source === source })
            if (index >= 0) {
                let job = runner.detached.splice(index, 1)[0]
                commandSource.disconnectSource(source)
                if (job.onDone) job.onDone(code, data["stdout"] || "", data["stderr"] || "")
                return
            }
            runner.finish(source, code, data["stdout"] || "", data["stderr"] || "")
        }
    }
    Timer {
        interval: 1000
        running: runner.activeCount > 0
        repeat: true
        onTriggered: runner.reap()
    }
}
