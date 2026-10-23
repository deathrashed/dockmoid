import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

import "../components" as Components

/* Inspector · Compose — the selected service's Compose file, read-only, with Edit and Validate. */
Item {
    id: root
    required property var backend

    readonly property var record: { const revision = backend.revision; return backend.findRecord(backend.previewRecordId) }
    readonly property string path: record ? String(record.composeFiles || "").split(",")[0].trim() : ""
    property string text: ""
    property string message: ""
    property bool messageOk: true

    function reload() {
        root.message = ""
        if (root.path === "") { root.text = ""; return }
        const wanted = root.path
        root.backend.readComposeFile(wanted, function (ok, content) {
            if (root.path === wanted) { root.text = ok ? content : ""; if (!ok) { root.message = content; root.messageOk = false } }
        })
    }
    onPathChanged: reload()

    InspectorEmpty {
        anchors.fill: parent
        visible: !root.record || root.path === ""
        text: !root.record ? i18n("Select a container to see its Compose file.") : i18n("This container was not started from a Compose file.")
    }

    ColumnLayout {
        anchors.fill: parent
        visible: !!root.record && root.path !== ""
        spacing: 0
        InspectorHeader {
            Layout.fillWidth: true
            backend: root.backend
            record: root.record
            Components.DockButton {
                glyph: "badge-check"
                text: i18n("Validate")
                visible: root.backend.canUseCompose
                onClicked: root.backend.composeRun(root.record, "config", i18n("Validate Configuration"), function (ok, out) {
                    root.messageOk = ok
                    root.message = String(out || "").trim().split("\n").slice(-3).join("\n")
                })
            }
            Components.DockButton {
                glyph: "document-edit"
                text: i18n("Edit…")
                visible: !root.backend.readOnly
                onClicked: root.backend.editCompose(root.record)
            }
            Components.ActionToolButton { glyph: "view-refresh"; text: i18n("Reload file"); onClicked: root.reload() }
        }
        PlasmaComponents.Label {
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.largeSpacing
            Layout.rightMargin: Kirigami.Units.largeSpacing
            text: root.path
            elide: Text.ElideMiddle
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.disabledTextColor
        }
        Kirigami.InlineMessage {
            Layout.fillWidth: true
            Layout.margins: Kirigami.Units.smallSpacing
            visible: root.message !== ""
            type: root.messageOk ? Kirigami.MessageType.Positive : Kirigami.MessageType.Error
            text: root.message
        }
        Components.LogViewer {
            Layout.fillWidth: true
            Layout.fillHeight: true
            text: root.text
            emptyText: i18n("Loading…")
        }
    }
}
