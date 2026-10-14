pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import "../../lib/status.js" as Status
import "../../lib/style.js" as Style

/* Minimal view: compact horizontal cards wrap to fill the available width. */
Item {
    id: root
    required property var backend
    required property var proxy
    required property var dialogs
    signal openDetail(string recordId)
    signal openOutput(string title, string content, bool live, string recordId)

    PlasmaComponents.ScrollView {
        PlasmaComponents.ScrollBar.vertical.policy: PlasmaComponents.ScrollBar.AlwaysOn
        anchors.fill: parent
        background: null
        contentItem: GridView {
            id: view
            model: root.proxy
            clip: true
            cellWidth: width / Math.max(1, Math.floor(width / (Kirigami.Units.gridUnit * 12)))
            cellHeight: Kirigami.Units.gridUnit * 3.5
            boundsBehavior: Flickable.StopAtBounds
            delegate: PlasmaComponents.ItemDelegate {
                id: card
                required property int index
                required property string containerKey
                required property string name
                required property string image
                required property string containerState
                required property string status
                required property string runningFor
                required property string health
                required property bool isRunning
                required property string project
                required property string service
                required property string composeFiles
                required property string composeWorkDir
                readonly property var record: root.backend.revision >= 0 ? root.backend.findRecord(containerKey) || ({id:containerKey, name:name, image:image, state:containerState, status:status, health:health, isRunning:isRunning, project:project, service:service, composeFiles:composeFiles, composeWorkDir:composeWorkDir, pinned:false, restartPolicy:""}) : null
                readonly property var operation: {
                    const revision = root.backend.operationsRevision
                    return root.backend.operationFor(card.containerKey)
                }
                readonly property string attention: Status.attentionKind(card.record)
                width: view.cellWidth - Kirigami.Units.smallSpacing
                height: view.cellHeight - Kirigami.Units.smallSpacing
                onDoubleClicked: root.openDetail(card.containerKey)
                background: Rectangle {
                    radius: Kirigami.Units.smallSpacing
                    color: card.hovered ? Qt.alpha(Kirigami.Theme.highlightColor, Style.ALPHA.tintStrong) : Qt.alpha(Kirigami.Theme.textColor, Style.ALPHA.surface1)
                    border.color: card.hovered ? Kirigami.Theme.highlightColor : Qt.alpha(Kirigami.Theme.textColor, Style.ALPHA.borderFaint)
                }
                contentItem: RowLayout {
                    spacing: Kirigami.Units.smallSpacing
                    ServiceIcon { backend: root.backend; record: card.record; iconSize: Kirigami.Units.iconSizes.smallMedium }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1
                        PlasmaComponents.Label { Layout.fillWidth: true; text: card.name; font.bold: true; elide: Text.ElideRight }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Kirigami.Units.smallSpacing
                            StateDot { containerState: card.containerState; health: card.health; showHealth: plasmoid.configuration.showHealth; failed: card.attention === "failed" }
                            StatusLine {
                                Layout.fillWidth: true
                                status: card.status; containerState: card.containerState; runningFor: card.runningFor
                                isRunning: card.isRunning; attention: card.attention
                                operationLabel: card.operation.label; operationOk: card.operation.ok; operationBusy: card.operation.busy
                                glyphMode: "attention"; showBusy: true
                            }
                        }
                    }
                    ActionToolButton { glyph: "application-menu"; text: i18n("Actions for %1", card.name); onClicked: actions.popup(this, 0, height) }
                }
                TapHandler {
                    acceptedButtons: Qt.RightButton
                    onTapped: function(point) { actions.popup(card, point.position.x, point.position.y) }
                }
                ContainerActions {
                    id: actions
                    backend: root.backend
                    record: card.record
                    dialogs: root.dialogs
                    onOpenDetail: function(recordId) { root.openDetail(recordId) }
                    onOpenOutput: function(title, content, live, recordId) { root.openOutput(title, content, live, recordId) }
                }
                onHoveredChanged:if(hovered)root.backend.previewContainer(card.containerKey,false)
                onClicked:root.backend.previewContainer(card.containerKey,true)
                PlasmaComponents.ToolTip { visible: card.hovered; text: card.name + "\n" + (card.status || card.containerState) + (card.operation.label ? "\n" + card.operation.label : "") + "\n" + card.image + "\n" + card.containerKey; delay: 700 }
            }
            Kirigami.PlaceholderMessage {
                anchors.centerIn: parent
                width: parent.width - Kirigami.Units.largeSpacing * 2
                visible: view.count === 0
                text: !root.backend.engineActive ? i18n("Engine unavailable") : root.backend.total === 0 ? i18n("No containers yet.") : i18n("No containers match the current filters.")
            }
        }
    }
}
