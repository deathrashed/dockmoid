pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2

import org.kde.kirigami as Kirigami
import org.kde.kquickcontrolsaddons as KQuickControlsAddons
import org.kde.plasma.components as PlasmaComponents

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
            // Only adopt payloads meant for this page: the detail page is also
            // listening for the same signal for its own embedded log view.
            if (root.live && title === root.backend.logsTitle(root.backend.findRecord(root.recordId))) {
                root.content = text
            }
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
                id: wrapToggle
                display: PlasmaComponents.AbstractButton.IconOnly
                icon.name: "text-wrap"
                text: i18n("Wrap lines")
                checkable: true
                checked: true
                PlasmaComponents.ToolTip { text: wrapToggle.text }
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
                id: copyButton
                display: PlasmaComponents.AbstractButton.IconOnly
                icon.name: "edit-copy"
                text: i18n("Copy")
                onClicked: clipboard.content = output.text
                PlasmaComponents.ToolTip { text: copyButton.text }
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

        QQC2.ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            background: null

            /*
             * The TextArea is a direct child, not an assigned `contentItem`.
             * ScrollView supplies (and requires) a Flickable there; handing it a
             * TextArea instead logs "ScrollView only supports Flickable types as
             * its contentItem" and leaves the log view with no scrollable content.
             */
            QQC2.TextArea {
                id: output
                readOnly: true
                selectByMouse: true
                wrapMode: wrapToggle.checked ? TextEdit.WrapAnywhere : TextEdit.NoWrap
                font.family: "monospace"
                font.pointSize: 9
                text: root.content
                background: null
            }
        }
    }

    KQuickControlsAddons.Clipboard {
        id: clipboard
    }
}
