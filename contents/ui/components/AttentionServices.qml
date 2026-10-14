pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import "../../lib/status.js" as Status

Item {
    id: root
    required property var backend
    required property var proxy
    required property var dialogs
    signal openDetail(string recordId)
    signal openOutput(string title, string content, bool live, string recordId)

    ListView {
        id: rows
        anchors.fill: parent
        clip: true
        model: root.proxy
        currentIndex: -1
        reuseItems: true
        boundsBehavior: Flickable.StopAtBounds
        delegate: Item {
            id: row
            required property int index
            required property string containerKey
            required property string name
            required property string image
            required property string containerState
            required property string status
            required property string health
            required property bool isRunning
            required property string project
            required property string service
            required property string composeFiles
            required property string composeWorkDir
            width: rows.width
            height: Kirigami.Units.gridUnit * 3.5
            readonly property var record: root.backend.findRecord(row.containerKey) || ({id:row.containerKey,name:row.name,image:row.image,state:row.containerState,status:row.status,health:row.health,isRunning:row.isRunning,project:row.project,service:row.service,composeFiles:row.composeFiles,composeWorkDir:row.composeWorkDir,pinned:false,restartPolicy:""})
            readonly property var operation: { const revision=root.backend.operationsRevision; return root.backend.operationFor(row.containerKey) }
            readonly property string attention: Status.attentionKind(row.record)
            function reason() {
                if (row.attention === "unhealthy") return row.record.probe === "down" ? i18n("Health probe failed") : i18n("Health check is unhealthy")
                if (row.attention === "restarting") return (String(row.status).match(/^Restarting(?:\s*\([^)]*\))?/i) || [i18n("Restarting")])[0]
                if (row.attention === "paused") return i18n("Paused")
                const code = String(row.status).match(/Exited\s*\((\d+)\)/i)
                if (code) return i18n("Exited with code %1", code[1])
                return row.attention === "failed" ? i18n("Container failed") : String(row.status || row.containerState)
            }
            Card { anchors.fill: parent; anchors.margins: 1; tone: Status.accentTone(row.attention) === "" ? "warn" : Status.accentTone(row.attention) }
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Kirigami.Units.smallSpacing
                anchors.rightMargin: Kirigami.Units.smallSpacing
                spacing: Kirigami.Units.smallSpacing
                StateDot { containerState: row.containerState; health: row.health; failed: row.attention === "failed" }
                ServiceIcon { backend: root.backend; record: row.record; iconSize: Kirigami.Units.iconSizes.smallMedium }
                ColumnLayout {
                    Layout.fillWidth: true; Layout.minimumWidth: 0; spacing: 0
                    PlasmaComponents.Label { Layout.fillWidth: true; text: row.name; font.bold: true; elide: Text.ElideRight; PlasmaComponents.ToolTip.text: row.name; PlasmaComponents.ToolTip.visible: rowHover.hovered }
                        StatusLine {
                            Layout.fillWidth: true
                            status: row.status; containerState: row.containerState; isRunning: row.isRunning; attention: row.attention
                            operationLabel: row.operation.label; operationOk: row.operation.ok; operationBusy: row.operation.busy
                            glyphMode: "always"; showBusy: true; labelOverride: row.reason()
                        }
                }
                ActionToolButton { glyph: "view-refresh"; text: i18n("Restart"); visible: actions.canPerform("restart"); onClicked: actions.perform("restart") }
                ActionToolButton { glyph: "text-x-generic"; text: i18n("Logs"); visible: actions.canPerform("logs"); onClicked: actions.perform("logs") }
                ActionToolButton { glyph: "document-view"; text: i18n("Details"); onClicked: root.openDetail(row.containerKey) }
                ActionToolButton { glyph: "application-menu"; text: i18n("Other actions"); onClicked: actions.popup(this,0,height) }
            }
            HoverHandler { id: rowHover;onHoveredChanged:if(hovered)root.backend.previewContainer(row.containerKey,false) }
            TapHandler {onTapped:root.backend.previewContainer(row.containerKey,true)}
            TapHandler { onDoubleTapped: root.openDetail(row.containerKey) }
            ContainerActions {
                id: actions
                backend: root.backend; record: row.record; dialogs: root.dialogs
                onOpenDetail: function(recordId) { root.openDetail(recordId) }
                onOpenOutput: function(title, content, live, recordId) { root.openOutput(title, content, live, recordId) }
            }
        }
    }
}
