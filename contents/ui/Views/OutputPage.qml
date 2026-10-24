pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts


import "../components" as Components

/*
 * OutputPage — full-height viewer for command output: container logs, inspect
 * JSON, a pull in progress, prune results.
 *
 * For log output it keeps polling and appends the latest tail, which is the
 * same information `docker logs -f` would give without needing a terminal.
 */
Item {
    id: root

    required property var navigator
    required property var backend
    required property string pageTitle
    property string content: ""
    /* When true the page re-runs the command on a timer and replaces the text
       (tails are snapshots, not streams, so the whole tail is re-read). */
    property bool live: false
    property string recordId: ""
    property string requestKind: ""
    property string requestId: ""
    property int requestGeneration: -1

    /* Lets PopupView recognise an already-open output page and update it in
       place instead of pushing a second copy. */
    readonly property bool isOutputPage: true

    function setContent(title, text, isLive, id, kind, token, generation) {
        pageTitle = title
        content = text
        live = isLive
        recordId = id || ""
        requestKind = kind || ""
        requestId = token || ""
        requestGeneration = generation
    }

    /* A live log is one LogSession; every other kind arrives once, by request token. */
    Components.LogSession {
        id: liveLogs
        backend: root.backend
        recordId: root.live && root.requestKind === "logs" && root.requestGeneration === root.backend.generation ? root.recordId : ""
        active: root.visible && root.navigator.currentItem === root
        onTextChanged: if (text !== "") root.content = text
    }
    function refresh() { liveLogs.refresh() }

    Connections {
        target: root.backend
        function onCorrelatedOutputReady(kind, id, contextGeneration, token, sequence, title, text) {
            if (kind !== root.requestKind || id !== root.recordId
                    || contextGeneration !== root.requestGeneration
                    || contextGeneration !== root.backend.generation || token !== root.requestId) return
            if (kind === "logs") return  // the LogSession above owns these
            root.content = text
        }
        function onOutputReady(_title, text) {
            // The update batch still emits its legacy signal. The page is tied
            // to the batch token and generation set by PopupView, never a title.
            if (root.requestKind === "batch"
                    && root.requestGeneration === root.backend.generation
                    && root.backend.activeBatchRequestId === root.requestId) root.content = text
        }
    }


    // ============================================================ view =====

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Components.PageHeader {
            title: root.pageTitle
            badges: Components.Pill {
                visible: root.live && root.requestGeneration === root.backend.generation
                text: i18n("Following")
                tone: "ok"
                statusDot: true
                pulse: true
            }
            Components.ActionToolButton {
                visible: root.live && root.requestGeneration === root.backend.generation
                glyph: "view-refresh"
                text: i18n("Refresh now")
                onClicked: root.refresh()
            }
            Components.ActionToolButton {
                visible: root.live && root.requestGeneration === root.backend.generation
                glyph: "utilities-terminal"
                text: i18n("Follow in terminal")
                onClicked: {
                    if (root.requestGeneration !== root.backend.generation) return
                    var rec = root.backend.findRecord(root.recordId)
                    if (rec) root.backend.followLogs(rec)
                }
            }
        }

        Loader {
            Layout.fillWidth: true
            Layout.fillHeight: true
            sourceComponent: root.requestKind === "inspect" ? inspectOutput : textOutput
        }

        Component {
            id: textOutput
            Components.LogViewer {
                text: root.content
                logMode: root.live
            }
        }
        Component {
            id: inspectOutput
            Components.InspectTree { text: root.content }
        }
    }
}
