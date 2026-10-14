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
            Rectangle { anchors.fill: parent; color: Qt.alpha(Kirigami.Theme.textColor, 0.025) }
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
                    RowLayout {
                        Layout.fillWidth: true; spacing: Kirigami.Units.smallSpacing / 2
                        ActionIcon {
                            glyph: row.operation.busy ? "view-refresh" : row.attention === "failed" ? "circle-x" : row.attention === "unhealthy" ? "dialog-warning" : row.attention === "paused" ? "media-playback-pause" : "view-refresh"
                            color: row.attention === "failed" || row.attention === "unhealthy" ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.neutralTextColor
                            implicitWidth: Kirigami.Units.iconSizes.small; implicitHeight: implicitWidth
                        }
                        PlasmaComponents.BusyIndicator { visible: row.operation.busy; running: visible; Layout.preferredWidth: Kirigami.Units.iconSizes.small; Layout.preferredHeight: Layout.preferredWidth }
                        PlasmaComponents.Label {
                            Layout.fillWidth: true; Layout.minimumWidth: 0
                            text: row.operation.label || row.reason()
                            color: row.operation.label ? (row.operation.ok ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.negativeTextColor) : row.attention === "failed" || row.attention === "unhealthy" ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.neutralTextColor
                            elide: Text.ElideRight; font: Kirigami.Theme.smallFont
                            PlasmaComponents.ToolTip.text: (row.status || row.containerState) + (row.operation.label ? "\n" + row.operation.label : "")
                            PlasmaComponents.ToolTip.visible: rowHover.hovered
                        }
                    }
                }
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
