import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

import "../components" as Components

/* Inspector · Logs — the live tail of the container selected in the list. */
Item {
    id: root
    required property var backend
    signal openDetail(string recordId, int tab)

    readonly property var record: { const revision = backend.revision; return backend.findRecord(backend.previewRecordId) }
    property string text: ""
    property string shownId: ""

    function refresh() {
        const rec = root.record
        if (!rec) { root.text = ""; return }
        const id = rec.id
        root.backend.tailLogs(rec, Math.min(500, Number(plasmoid.configuration.logTailLines) || 200), function (out) {
            if (root.record && root.record.id === id) root.text = out
        })
    }
    onRecordChanged: if ((record ? record.id : "") !== shownId) { shownId = record ? record.id : ""; text = ""; refresh() }

    // Follows the log while it is on screen, at the usage sampling pace.
    Timer {
        interval: Math.max(3, plasmoid.configuration.usageInterval) * 1000
        repeat: true
        running: root.visible && !!root.record && root.record.isRunning === true
        onTriggered: root.refresh()
    }

    InspectorEmpty { anchors.fill: parent; visible: !root.record; text: i18n("Select a container to follow its log here.") }

    ColumnLayout {
        anchors.fill: parent
        visible: !!root.record
        spacing: 0
        InspectorHeader {
            Layout.fillWidth: true
            backend: root.backend
            record: root.record
            Components.DockButton {
                glyph: "external-link"
                text: i18n("Full Logs")
                onClicked: root.openDetail(root.record.id, 1)
            }
        }
        Components.LogViewer {
            Layout.fillWidth: true
            Layout.fillHeight: true
            text: root.text
            logMode: true
            emptyText: root.record && root.record.state === "not-created" ? i18n("This service has no container yet.") : i18n("No log output yet.")
        }
    }
}
