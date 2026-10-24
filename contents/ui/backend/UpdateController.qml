import QtQuick
import "../../lib/parsers.js" as Parsers

/*
 * Image updates: the slow registry check, its cache and the reviewed
 * pull-and-recreate batch. The cache in cfg.updateCache keeps one state per
 * engine host, so switching hosts never mixes their results.
 */
Item {
    id: root
    required property var backend
    readonly property var cfg: backend.cfg
    visible: false
    property var updateState: ({})
    property var updateQueue: []
    property bool updateRunning: false
    property int updateCount: 0
    property bool batchUpdating: false
    property string batchStatus: ""
    property var batchResults: []

    /* A connection change stops a running batch; its queued steps check the generation. */
    function cancelBatch() {
        if (!batchUpdating) return
        batchUpdating = false
        batchStatus = i18n("Update batch cancelled because the connection changed")
        batchResults = batchResults.concat([batchStatus])
    }

    function reset() {
        updateState = ({}); updateQueue = []; updateRunning = false; updateCount = 0
    }

    function loadUpdateCache() {
        try {
            let data = JSON.parse(String(cfg.updateCache || "{}"))
            updateState = data.__hosts && data.__hosts[backend.engineBinary] ? data.__hosts[backend.engineBinary] : ({})
        } catch (e) { updateState = ({}) }
    }

    function saveUpdateCache() {
        var data
        try { data = JSON.parse(String(cfg.updateCache || "{}")) } catch (e) { data = {} }
        if (!data.__hosts) data = {__hosts: {}}
        data.__hosts[backend.engineBinary] = updateState
        cfg.updateCache = JSON.stringify(data)
    }

    function invalidateImage(image) {
        delete updateState[image]
        updateState.__checked = 0
        saveUpdateCache(); applyUpdates(); backend.syncModel(); backend.revision++
    }

    function updatesDue() {
        if (!cfg.checkImageUpdates || !backend.buildxAvailable || updateRunning) return false
        var every = Math.max(1, cfg.updateCheckHours) * 3600 * 1000
        return Date.now() - (updateState["__checked"] || 0) >= every
    }

    function applyUpdates() {
        var n = 0
        const records = backend.records
        for (let i = 0; i < records.length; i++) {
            let u = updateState[records[i].image]
            records[i].updateAvailable = !!u && u.state === "update"
            records[i].updateState = !Parsers.isCheckableImage(records[i].image) ? "local"
                : updateRunning ? "checking" : u ? u.state : backend.buildxAvailable ? "unchecked" : "unsupported"
            records[i].imagePulled = !!u && u.pulled === true
            records[i].updateCheckedAt = u && u.at ? u.at : 0
            if (records[i].updateAvailable) n++
        }
        updateCount = n
    }

    /* Ask the registry about each distinct image, one at a time, and only on a
       slow schedule: a check is a network round trip per image. */
    function startUpdateCheck(force) {
        if (updateRunning || (!cfg.checkImageUpdates && !force) || !backend.buildxAvailable) return
        var refs = []
        backend.records.forEach(function (r) {
            if (Parsers.isCheckableImage(r.image) && refs.indexOf(r.image) < 0) refs.push(r.image)
        })
        if (refs.length === 0) return
        updateQueue = refs
        updateRunning = true
        applyUpdates(); backend.syncModel(); backend.revision++
        updateState["__before"] = Object.keys(updateState).filter(function (k) { return root.updateState[k] && root.updateState[k].state === "update" }).join("\n")
        nextUpdateCheck()
    }

    function nextUpdateCheck() {
        if (updateQueue.length === 0) { finishUpdateCheck(); return }
        var ref = updateQueue[0]
        updateQueue = updateQueue.slice(1)
        var used = backend.records.find(function (r) { return r.image === ref && r.imageId })
        var template = String(cfg.updateCheckCommand || "")
        var cmd = backend.expand(template, { "image": backend.shellQuote(ref) })
        if (used && template.indexOf("image inspect {image}") >= 0)
            cmd = cmd.replace("image inspect " + backend.shellQuote(ref), "image inspect " + backend.shellQuote(used.imageId))
        backend.run(cmd, "update-check", function (code, out) {
            root.updateState[ref] = { "state": code === 0 ? Parsers.compareDigests(out) : "unknown", "at": Date.now() }
            root.nextUpdateCheck()
        })
    }

    function finishUpdateCheck() {
        var before = String(updateState["__before"] || "").split("\n")
        delete updateState["__before"]
        updateState["__checked"] = Date.now()
        updateRunning = false
        var fresh = Object.keys(updateState).filter(function (k) {
            return k.indexOf("__") !== 0 && root.updateState[k] && root.updateState[k].state === "update" && before.indexOf(k) < 0
        })
        try { saveUpdateCache() } catch (e) { /* cache is optional */ }
        applyUpdates(); backend.syncModel(); backend.revision++
        if (fresh.length > 0 && cfg.useNotifications && cfg.notifyOnUpdate)
            backend.notify(backend.engineName, i18np("A newer image is available: %2", "Newer images are available: %2", fresh.length, fresh.slice(0, 4).join(", ")), "update")
    }

    /* "Update": pull the newer image and recreate the container from it. */
    function updateContainer(rec, done) {
        if (!rec || backend.readOnly) { if (done) done(false, i18n("Read-only mode is enabled")); return }
        backend.muteContainer(rec.id)
        if (rec.project && rec.service && backend.canUseCompose) {
            backend.composeRun(rec, rec.isRunning ? "update-service-running" : "update-service-stopped", rec.name, done)
        } else {
            // A standalone container has no saved Compose recipe from which to
            // recreate it safely. Pulling the image is the only lossless action.
            const message = i18n("Pull and recreate requires an accessible Compose service. Use Pull image only, then recreate with the original deployment configuration.")
            backend.actionDone(rec.name, message, false)
            if (done) done(false, message)
        }
    }

    function updateTargets(allRunning, includeStopped) {
        var seen = {}
        return backend.records.filter(function (r) {
            var key = r.project && r.service ? r.project + "/" + r.service : r.id
            if (r.state === "not-created" || (!r.isRunning && !includeStopped) || (!allRunning && !r.updateAvailable) || seen[key]) return false
            seen[key] = true
            return true
        })
    }

    function updateMany(targets) {
        if (backend.readOnly || batchUpdating || targets.length === 0) return
        batchUpdating = true; batchResults = []
        var queue = targets.slice()
        var count = queue.length
        var epoch = backend.generation
        function next() {
            if (epoch !== root.backend.generation) return
            if (queue.length === 0) {
                root.batchUpdating = false
                root.batchStatus = i18n("Finished %1 selected actions", count)
                root.backend.outputReady(i18n("Update results"), root.batchResults.join("\n\n"))
                root.backend.refresh({force: true, withStats: false})
                return
            }
            var rec = queue.shift()
            const recreate = rec.project && rec.service && root.backend.canUseCompose
            root.batchStatus = i18n("Processing %1 (%2 of %3)", rec.name, count - queue.length, count)
            const perform = recreate ? root.updateContainer : root.backend.pullImage
            perform(rec, function (ok, text) {
                if (epoch !== root.backend.generation) return
                root.batchResults = root.batchResults.concat([(ok ? "✓ " : "✗ ") + rec.name + " — " + (recreate ? i18n("Pull and recreate") : i18n("Pull image only")) + "\n" + text])
                Qt.callLater(next)
            })
        }
        next()
    }
}
