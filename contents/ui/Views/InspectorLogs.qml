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

    // The tail of the selected container, followed while this tab is on screen.
    Components.LogSession {
        id: session
        backend: root.backend
        recordId: root.record ? root.record.id : ""
        active: root.visible
        tail: Math.min(500, Number(root.backend.cfg.logTailLines) || 200)
        interval: Math.max(3, Number(root.backend.cfg.usageInterval) || 5) * 1000
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
            text: session.text
            logMode: true
            emptyText: root.record && root.record.state === "not-created" ? i18n("This service has no container yet.") : i18n("No log output yet.")
        }
    }
}
