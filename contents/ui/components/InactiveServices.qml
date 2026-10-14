pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import "../../lib/parsers.js" as Parsers
import "../../lib/style.js" as Style

Item {
    id: root
    required property var backend
    required property var proxy
    required property var dialogs
    property bool compact: false
    property string displayMode:"cards"
    signal openDetail(string recordId)
    signal openOutput(string title, string content, bool live, string recordId)

    GridView {
        id: cards
        objectName: "inactiveServicesGrid"
        anchors.fill: parent
        anchors.margins: Kirigami.Units.smallSpacing
        clip: true
        model: root.proxy
        cellWidth: root.displayMode==="list" ? width : root.displayMode==="icons" ? width/Math.max(1,Math.floor(width/110)) : Math.min(width,Math.max(210, Math.floor(width / Math.max(1, Math.floor(width / (root.compact ? 205 : 250))))))
        cellHeight: root.displayMode==="icons" ? 78 : root.displayMode==="list" ? 62 : root.compact ? 70 : 88
        boundsBehavior: Flickable.StopAtBounds
        delegate: Item {
            id: card
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
            width: cards.cellWidth - Kirigami.Units.smallSpacing
            height: cards.cellHeight - Kirigami.Units.smallSpacing
            readonly property var record: root.backend.findRecord(card.containerKey) || ({id:card.containerKey,name:card.name,image:card.image,state:card.containerState,isRunning:card.isRunning,project:card.project,service:card.service,composeFiles:card.composeFiles,composeWorkDir:card.composeWorkDir,pinned:false,restartPolicy:""})
            readonly property var operation: { const revision=root.backend.operationsRevision; return root.backend.operationFor(card.containerKey) }
            Rectangle { anchors.fill: parent; radius: Kirigami.Units.smallSpacing; color: Qt.alpha(Kirigami.Theme.textColor, hover.hovered ? Style.ALPHA.hover : Style.ALPHA.surface2); border.color: Qt.alpha(Kirigami.Theme.textColor,Style.ALPHA.borderFaint) }
            RowLayout {
                anchors.fill: parent
                anchors.margins: Kirigami.Units.smallSpacing
                spacing: Kirigami.Units.smallSpacing / 2
                ServiceIcon { backend: root.backend; record: card.record; iconSize: Kirigami.Units.iconSizes.medium }
                ColumnLayout {
                    visible:root.displayMode!=="icons"
                    Layout.fillWidth: true; Layout.minimumWidth: 0; spacing: 1
                    PlasmaComponents.Label { Layout.fillWidth: true; text: card.name; font.bold: true; elide: Text.ElideRight; PlasmaComponents.ToolTip.text: card.name; PlasmaComponents.ToolTip.visible: hover.hovered }
                    PlasmaComponents.Label {
                        Layout.fillWidth: true
                        text: card.operation.label || (card.containerState === "not-created" ? i18n("Not created") : i18n("Stopped"))
                        color: card.operation.label ? (card.operation.ok ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.negativeTextColor) : Kirigami.Theme.disabledTextColor
                        font: Kirigami.Theme.smallFont; elide: Text.ElideRight
                        PlasmaComponents.ToolTip.text: (card.status || card.containerState) + (card.operation.label ? "\n" + card.operation.label : "")
                        PlasmaComponents.ToolTip.visible: hover.hovered
                    }
                }
                PlasmaComponents.BusyIndicator { visible: card.operation.busy; running: visible; Layout.preferredWidth: Kirigami.Units.iconSizes.small; Layout.preferredHeight: Layout.preferredWidth }
                ActionToolButton { glyph: "media-playback-start"; text: card.containerState === "not-created" ? i18n("Create and start") : i18n("Start existing container"); enabled: !root.backend.readOnly && !card.operation.busy && Parsers.canStart(card.containerState); onClicked: root.backend.startContainer(card.record) }
                ActionToolButton { glyph: "application-menu"; text: i18n("Other actions"); onClicked: actions.popup(this,0,height) }
            }
            HoverHandler { id: hover;onHoveredChanged:if(hovered)root.backend.previewContainer(card.containerKey,false) }
            PlasmaComponents.ToolTip {visible:hover.hovered;text:card.name+" · "+(card.containerState==="not-created"?i18n("Not created"):i18n("Stopped"))}
            TapHandler {onTapped:root.backend.previewContainer(card.containerKey,true)}
            TapHandler { onDoubleTapped: root.openDetail(card.containerKey) }
            ContainerActions {
                id: actions
                backend: root.backend; record: card.record; dialogs: root.dialogs
                onOpenDetail: function(recordId) { root.openDetail(recordId) }
                onOpenOutput: function(title, content, live, recordId) { root.openOutput(title, content, live, recordId) }
            }
        }
    }
}
