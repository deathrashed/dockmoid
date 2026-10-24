import QtQuick

/*
 * LogSession — one container's live log tail, owned in one place.
 *
 * The inspector, the detail page and the output page each show a log; this
 * keeps what they would otherwise each re-implement: which container, the
 * request identity and connection generation results must match, accepting
 * only newer results (an older poll answering late never replaces a newer
 * one), and following the tail while the view is shown. Views set `recordId`,
 * `active` and `tail`, and read `text`.
 */
Item {
    id: root
    visible: false
    width: 0
    height: 0

    required property var backend
    property string recordId: ""
    /* Follow the tail (the view is on screen); false stops the polling, not the text. */
    property bool active: false
    property int tail: Number(root.backend.cfg.logTailLines) || 200
    property int interval: Math.max(2, Number(root.backend.cfg.usageInterval) || 5) * 1000

    property string text: ""
    property bool loading: false
    property string requestId: ""
    property int generation: -1
    property int sequence: 0

    readonly property var record: { const revision = root.backend.revision; return root.recordId !== "" ? root.backend.findRecord(root.recordId) : null }

    /* A new session: new identity, nothing accepted yet. */
    function restart() {
        root.text = ""
        root.sequence = 0
        root.generation = root.backend.generation
        root.requestId = root.recordId !== "" ? root.backend.newOutputRequest("logs", root.recordId) : ""
        root.refresh()
    }
    function refresh() {
        const rec = root.record
        if (!rec || rec.state === "not-created" || root.requestId === "") { root.loading = false; return }
        if (root.generation !== root.backend.generation) { root.restart(); return }
        root.loading = true
        root.backend.fetchLogs(rec, root.tail, root.requestId, root.generation)
    }

    onRecordIdChanged: restart()
    onActiveChanged: if (active) refresh()
    Component.onCompleted: if (recordId !== "") restart()

    Connections {
        target: root.backend
        function onRecordOutput(kind, id, contextGeneration, requestId, sequence, content) {
            if (kind !== "logs" || id !== root.recordId || requestId !== root.requestId
                    || contextGeneration !== root.generation || contextGeneration !== root.backend.generation
                    || sequence <= root.sequence) return
            root.sequence = sequence
            root.text = content
            root.loading = false
        }
        function onGenerationChanged() { root.text = ""; root.requestId = ""; root.loading = false }
    }

    // Only a running container's log grows; a stopped one is read once.
    Timer {
        interval: root.interval
        repeat: true
        running: root.active && !!root.record && root.record.isRunning === true
        onTriggered: root.refresh()
    }
}
