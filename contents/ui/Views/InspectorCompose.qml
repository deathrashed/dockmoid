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
    /* A project with overrides records every file; show which one is open. */
    readonly property var files: record ? String(record.composeFiles || "").split(",").map(function (f) { return f.trim() }).filter(function (f) { return f !== "" }) : []
    property int fileIndex: 0
    readonly property string path: files.length > 0 ? files[Math.min(fileIndex, files.length - 1)] : ""
    onRecordChanged: if (record && record.id !== shownId) { shownId = record.id; fileIndex = 0 }
    property string shownId: ""
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
            // Restart keeps the old configuration; Apply re-reads the files and recreates
            // only what changed. Preview (Compose 2.17+) shows that without doing it.
            Components.DockButton {
                glyph: "file-search"
                text: i18n("Preview")
                visible: root.backend.composeDryRun && !root.backend.readOnly
                onClicked: root.backend.composeRun(root.record, "service-preview", i18n("Preview Changes"), function (ok, out) {
                    root.messageOk = ok
                    root.message = String(out || "").trim().split("\n").slice(-6).join("\n") || i18n("Nothing would change.")
                })
            }
            Components.DockButton {
                glyph: "file-check"
                text: i18n("Apply")
                visible: root.backend.canUseCompose && !root.backend.readOnly
                blockedReason: root.backend.actionReason(root.record, "recreate")
                onClicked: {
                    const state = String(root.record.state || "")
                    const verb = state === "running" || state === "paused" || state === "restarting" ? "service-apply-running" : "service-apply-stopped"
                    root.backend.composeRun(root.record, verb, i18n("Apply Changes · %1", root.record.name), function (ok, out) {
                        root.messageOk = ok
                        root.message = ok ? i18n("Applied. Compose recreated what the files changed.") : String(out || "").trim().split("\n").slice(-3).join("\n")
                    })
                }
            }
            Components.DockButton {
                glyph: "document-edit"
                text: i18n("Edit…")
                visible: !root.backend.readOnly && !root.backend.remoteEngine
                onClicked: root.backend.editCompose(root.record)
            }
            Components.ActionToolButton { glyph: "view-refresh"; text: i18n("Reload file"); onClicked: root.reload() }
        }
        Components.SizedComboBox {
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.largeSpacing
            Layout.rightMargin: Kirigami.Units.largeSpacing
            visible: root.files.length > 1
            model: root.files
            currentIndex: Math.min(root.fileIndex, root.files.length - 1)
            onActivated: function (index) { root.fileIndex = index }
        }
        PlasmaComponents.Label {
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.largeSpacing
            Layout.rightMargin: Kirigami.Units.largeSpacing
            visible: root.files.length <= 1 || root.backend.remoteEngine
            text: root.backend.remoteEngine ? i18n("%1 on %2", root.path, root.backend.endpointHost) : root.path
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
