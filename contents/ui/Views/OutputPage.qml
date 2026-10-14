pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

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

    /* Lets PopupView recognise an already-open output page and update it in
       place instead of pushing a second copy. */
    readonly property bool isOutputPage: true

    function setContent(title, text, isLive) {
        pageTitle = title
        content = text
        live = isLive
    }

    Component.onCompleted: {
        if (live) refresh()
    }

    function refresh() {
        if (recordId === "") return
        var rec = backend.findRecord(recordId)
        if (rec) backend.fetchLogs(rec, plasmoid.configuration.logTailLines)
    }

    Connections {
        target: root.backend
        function onOutputReady(title, text) {
            // A page adopts text carrying its own title, which covers pulls and
            // compose runs that finish after the page opened, and — for logs —
            // the title format the log fetch uses (the detail page is listening
            // for the same signal for its embedded log tab).
            var isLogs = root.live && title === root.backend.logsTitle(root.backend.findRecord(root.recordId))
            if (isLogs || title === root.pageTitle) root.content = text
        }
    }

    Timer {
        interval: Math.max(2, plasmoid.configuration.usageInterval) * 1000
        repeat: true
        running: root.live && root.recordId !== ""
        onTriggered: root.refresh()
    }

    // ============================================================ view =====

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            Layout.margins: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.smallSpacing

            PlasmaComponents.ToolButton {
                id: backButton
                display: PlasmaComponents.AbstractButton.IconOnly
                icon.name: "go-previous"
                text: i18n("Back")
                onClicked: root.navigator.pop()
                PlasmaComponents.ToolTip { text: backButton.text }
            }

            PlasmaComponents.Label {
                Layout.fillWidth: true
                text: root.pageTitle
                font.bold: true
                elide: Text.ElideRight
            }

            PlasmaComponents.Label {
                visible: root.live
                text: i18n("following")
                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                color: Kirigami.Theme.positiveTextColor
            }

            PlasmaComponents.ToolButton {
                id: refreshButton
                display: PlasmaComponents.AbstractButton.IconOnly
                visible: root.live
                icon.name: "view-refresh"
                text: i18n("Refresh now")
                onClicked: root.refresh()
                PlasmaComponents.ToolTip { text: refreshButton.text }
            }

            PlasmaComponents.ToolButton {
                id: followButton
                display: PlasmaComponents.AbstractButton.IconOnly
                visible: root.live
                icon.name: "utilities-terminal"
                text: i18n("Follow in terminal")
                onClicked: {
                    var rec = root.backend.findRecord(root.recordId)
                    if (rec) root.backend.followLogs(rec)
                }
                PlasmaComponents.ToolTip { text: followButton.text }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Qt.alpha(Kirigami.Theme.textColor, 0.2)
        }

        Components.LogViewer {
            Layout.fillWidth: true
            Layout.fillHeight: true
            text: root.content
            logMode: root.live
        }
    }
}
