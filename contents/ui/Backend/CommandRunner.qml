import QtQuick
import org.kde.plasma.plasma5support as Plasma5Support

/*
 * CommandRunner — a small, serialized, correlated job runner around
 * Plasma5Support.DataSource.
 *
 * Why this exists instead of calling connectSource() directly from the UI:
 *
 *   1. DataSource identifies a job by its source name, which for the
 *      "executable" engine *is* the command line. connectSource() on a command
 *      that is already connected is a no-op, so two overlapping refreshes used
 *      to silently drop one of the requests and leave the model half updated.
 *   2. Because the command is the only correlation handle, we must guarantee at
 *      most one in-flight copy of any given command. The queue below does that,
 *      and it also stops us from launching six docker processes at once.
 *   3. Re-issuing the *same* poll command before it completed (very common:
 *      the user mashes refresh) is coalesced into the pending job instead of
 *      piling up.
 *
 * Every run() takes a callback instead of relying on global signals, so the
 * caller always knows which request it is answering.
 */
Item {
    id: runner

    // An Item rather than a QtObject purely so it can *own* the DataSource and
    // the watchdog Timer: a QtObject has no default property, so declaring
    // child objects in it is a hard QML error.
    visible: false
    width: 0
    height: 0

    /* How many docker processes may run at once. Two keeps the UI responsive
       (a slow `docker stats` never blocks a fast `docker ps`) without turning
       the plasmoid into a fork bomb on a Raspberry Pi. */
    property int maxConcurrent: 2

    /* A job still running after this is treated as failed and its slot freed. */
    property int timeout: 60000

    property bool debug: false

    /* Jobs queued but not started, as {cmd, tag, callbacks, startedAt}. */
    property var queue: []
    /* Jobs currently executing, keyed by command (== DataSource source name). */
    property var active: ({})

    property int activeCount: 0
    /* Fire-and-forget jobs (terminal launches). They never occupy a slot but are
       still tracked so they can be reaped if the terminal never returns. */
    property var detached: []

    readonly property bool busy: activeCount > 0 || queue.length > 0
    readonly property int pending: queue.length

    signal commandStarted(string cmd, string tag)
    signal commandFinished(string cmd, string tag, int exitCode, string stdout, string stderr)

    /*
     * Queue `cmd`. `onDone(exitCode, stdout, stderr)` runs when it finishes.
     * Identical commands that are still queued are merged onto one job.
     */
    function run(cmd, tag, onDone) {
        if (!cmd) return
        for (var i = 0; i < queue.length; i++) {
            if (queue[i].cmd === cmd) {
                if (onDone) queue[i].callbacks.push(onDone)
                return
            }
        }
        queue.push({
            "cmd": cmd,
            "tag": tag || "",
            "callbacks": onDone ? [onDone] : [],
            "startedAt": 0
        })
        pump()
    }

    /*
     * Run something whose output nobody cares about and which may outlive us
     * (a terminal emulator, an editor). Not queued, not counted against
     * maxConcurrent, but still disconnected once it returns.
     */
    function spawn(cmd, onDone) {
        if (!cmd) return
        detached.push({ "cmd": cmd, "startedAt": Date.now(), "onDone": onDone || null })
        if (debug) console.log("[runner] spawn:", cmd)
        try {
            sources.connectSource(cmd)
        } catch (e) {
            console.warn("[runner] spawn failed:", cmd, e)
            if (onDone) onDone(-1, "", String(e))
        }
    }

    /* Start as many queued jobs as concurrency allows. */
    function pump() {
        while (activeCount < maxConcurrent && queue.length > 0) {
            var entry = queue.shift()
            if (active[entry.cmd]) {
                // Defensive: should be impossible because run() coalesces, but
                // never connect a command that is already in flight.
                queue.unshift(entry)
                break
            }
            entry.startedAt = Date.now()
            active[entry.cmd] = entry
            activeCount++
            if (debug) console.log("[runner] start:", entry.tag || entry.cmd)
            sources.connectSource(entry.cmd)
        }
    }

    function reap() {
        var now = Date.now()
        for (var cmd in active) {
            if (now - active[cmd].startedAt <= timeout) continue
            finish(cmd, -1, "", i18n("Command timed out"))
        }
        for (var i = detached.length - 1; i >= 0; i--) {
            if (now - detached[i].startedAt <= timeout) continue
            try {
                sources.disconnectSource(detached[i].cmd)
            } catch (e) { /* already gone */ }
            detached.splice(i, 1)
        }
        pump()
    }

    /* Retire a job and hand its result to everyone waiting on it. */
    function finish(cmd, exitCode, stdout, stderr) {
        var entry = active[cmd]
        if (!entry) return
        delete active[cmd]
        activeCount = Math.max(0, activeCount - 1)
        if (debug) {
            console.log("[runner] done:", entry.tag || cmd, "code=" + exitCode)
        }
        commandFinished(cmd, entry.tag, exitCode, stdout, stderr)
        // Callbacks may queue more work; do it after the slot is freed.
        for (var i = 0; i < entry.callbacks.length; i++) {
            try {
                entry.callbacks[i](exitCode, stdout, stderr)
            } catch (e) {
                console.error("[runner] callback failed for", cmd, e)
            }
        }
        pump()
    }

    /* Drop everything. Used when the engine goes away so a burst of pending
       refreshes does not keep hitting a socket that is not there. */
    function cancelAll() {
        queue = []
        for (var cmd in active) {
            try {
                sources.disconnectSource(cmd)
            } catch (e) { /* already gone */ }
            delete active[cmd]
        }
        activeCount = 0
        for (var i = 0; i < detached.length; i++) {
            try {
                sources.disconnectSource(detached[i].cmd)
            } catch (e) { /* already gone */ }
        }
        detached = []
    }

    Plasma5Support.DataSource {
        id: sources
        engine: "executable"
        connectedSources: []
        // interval 0 => each source runs exactly once. All repetition is driven
        // by our own timers, so we never get a surprise background poll.
        interval: 0

        onNewData: function (sourceName, data) {
            var i = runner.detached.findIndex(function (d) { return d.cmd === sourceName })
            if (i >= 0) {
                var job = runner.detached[i]
                runner.detached.splice(i, 1)
                var detachedCode = parseInt(data["exit code"], 10)
                if (isNaN(detachedCode)) detachedCode = -1
                if (job.onDone) job.onDone(detachedCode,
                    data["stdout"] || "", data["stderr"] || "")
                try {
                    sources.disconnectSource(sourceName)
                } catch (e) { /* already gone */ }
                return
            }
            var code = parseInt(data["exit code"], 10)
            if (isNaN(code)) code = -1
            var out = data["stdout"] || ""
            var err = data["stderr"] || ""
            if (!runner.active[sourceName]) {
                // A job we no longer track (cancelled). Just let it go.
                try {
                    sources.disconnectSource(sourceName)
                } catch (e) { /* already gone */ }
                return
            }
            try {
                sources.disconnectSource(sourceName)
            } catch (e) { /* already gone */ }
            runner.finish(sourceName, code, out, err)
        }
    }

    Timer {
        interval: 5000
        repeat: true
        running: runner.activeCount > 0 || runner.detached.length > 0
        onTriggered: runner.reap()
    }
}
