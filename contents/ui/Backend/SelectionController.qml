import QtQuick

/*
 * SelectionController — act on several containers at once, deliberately.
 *
 * Selection mode is opt-in. Picked containers stay picked while filters change
 * (the bar says how many are hidden). Before anything runs, plan() splits the
 * picks into those the shared action rules allow and those they skip, with the
 * reason, so the review shows exactly what will happen. run() then does one
 * container at a time, waiting for each to finish, and reports every result.
 * Removal is deliberately not offered here.
 */
Item {
    id: root
    required property var backend

    property bool active: false
    property var picked: ({})
    readonly property var pickedIds: Object.keys(root.picked)
    property bool running: false
    property var results: []
    property string currentAction: ""
    property var queue: []
    property string waitingFor: ""
    property double waitingSince: 0

    onActiveChanged: if (!active && !running) picked = ({})

    function toggle(id) {
        const next = Object.assign({}, root.picked)
        if (next[id]) delete next[id]; else next[id] = true
        root.picked = next
    }
    function isPicked(id) { return root.picked[id] === true }
    function clear() { root.picked = ({}) }
    /* Picks hidden by the list's filters (proxyRowOf < 0 for each). */
    function hiddenCount(isShown) { return root.pickedIds.filter(function (id) { return !isShown(id) }).length }

    /* {targets: [records], skipped: [{name, reason}]} for `action`. */
    function plan(action) {
        void root.backend.revision; void root.backend.operationsRevision
        const targets = [], skipped = []
        root.pickedIds.forEach(function (id) {
            const rec = root.backend.findRecord(id)
            if (!rec) { skipped.push({name: id.slice(0, 12), reason: i18n("no longer listed")}); return }
            if (action === "update" && rec.updateAvailable !== true) { skipped.push({name: rec.name, reason: i18n("no newer image known")}); return }
            if (action === "update" && !(rec.project && rec.service && root.backend.canUseCompose)) { skipped.push({name: rec.name, reason: i18n("not a Compose service, so it cannot be recreated safely")}); return }
            const why = root.backend.actionReason(rec, action)
            if (why === "") targets.push(rec); else skipped.push({name: rec.name, reason: why})
        })
        return {targets: targets, skipped: skipped}
    }

    signal finished(string action, var results)

    function run(action) {
        if (root.running) return
        const p = root.plan(action)
        root.results = p.skipped.map(function (s) { return {name: s.name, ok: null, text: s.reason} })
        root.queue = p.targets.map(function (r) { return r.id })
        root.currentAction = action
        root.running = true
        root.next()
    }

    function next() {
        if (root.queue.length === 0) {
            root.running = false; root.waitingFor = ""
            root.finished(root.currentAction, root.results)
            return
        }
        const id = root.queue[0]
        root.queue = root.queue.slice(1)
        const rec = root.backend.findRecord(id)
        // Re-check at the moment of running: the state may have changed since review.
        if (!rec || root.backend.actionReason(rec, root.currentAction) !== "") {
            root.results = root.results.concat([{name: rec ? rec.name : id, ok: null, text: rec ? root.backend.actionReason(rec, root.currentAction) : i18n("no longer listed")}])
            Qt.callLater(root.next); return
        }
        root.waitingFor = id
        root.waitingSince = Date.now()
        let started = true
        if (root.currentAction === "update") root.backend.updates.updateContainer(rec)
        else started = root.backend.runAction(rec, root.currentAction)
        if (!started) {
            root.results = root.results.concat([{name: rec.name, ok: false, text: i18n("refused")}])
            root.waitingFor = ""
            Qt.callLater(root.next); return
        }
        watchdog.restart()
    }

    function settle() {
        if (root.waitingFor === "") return
        const op = root.backend.operationFor(root.waitingFor)
        if (op.busy || op.finishedAt < root.waitingSince) return
        const rec = root.backend.findRecord(root.waitingFor)
        root.results = root.results.concat([{name: rec ? rec.name : root.waitingFor, ok: op.ok, text: op.label}])
        root.waitingFor = ""
        watchdog.stop()
        Qt.callLater(root.next)
    }
    Connections { target: root.backend; function onOperationsRevisionChanged() { root.settle() } }
    // A target that never reports back (refused before starting) does not stall the rest.
    Timer {
        id: watchdog
        interval: root.currentAction === "update" ? 15 * 60 * 1000 : 3 * 60 * 1000
        onTriggered: {
            if (root.waitingFor === "") return
            const rec = root.backend.findRecord(root.waitingFor)
            root.results = root.results.concat([{name: rec ? rec.name : root.waitingFor, ok: false, text: i18n("no result reported")}])
            root.waitingFor = ""
            root.next()
        }
    }
    Connections { target: root.backend; function onGenerationChanged() { root.queue = []; root.waitingFor = ""; root.running = false; root.picked = ({}); root.active = false } }
}
