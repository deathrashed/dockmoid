pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import "../../lib/parsers.js" as Parsers
import "../../lib/status.js" as Status
import "../../lib/style.js" as Style

/* Compact fixed-height cards: long metadata stays in tooltips or the detail view. */
Item {
    id: root
    required property var backend
    required property var proxy
    required property var dialogs
    property int detailLevel: 1
    signal openDetail(string recordId)
    signal openOutput(string title, string content, bool live, string recordId)

    // Keep overview cards proportional to the selected information level.
    // The verbose height includes room for the optional diagnostics rows.
    readonly property real cardHeight: Kirigami.Units.gridUnit *
        (detailLevel <= 0 ? 5 : detailLevel === 1 ? 8 : detailLevel === 2 ? 15 : 17)

    GridView {
        id: grid
        objectName: "containerGridView"
        anchors.fill: parent
        clip: true
        model: root.proxy
        cellWidth: width / Math.max(1, Math.floor(width / (Kirigami.Units.gridUnit * (root.detailLevel <= 0 ? 11 : 16))))
        cellHeight: root.cardHeight + Kirigami.Units.smallSpacing
        boundsBehavior: Flickable.StopAtBounds
        delegate: Item {
            id: tile
            objectName: "containerGridCard"
            required property int index
            required property string containerKey
            required property string name
            required property string image
            required property string containerState
            required property string status
            required property string health
            required property bool isRunning
            required property string cpu
            required property string mem
            required property real cpuPct
            required property real memPct
            required property string project
            required property string service
            required property string composeFiles
            required property string composeWorkDir
            width: grid.cellWidth - Kirigami.Units.smallSpacing
            height: root.cardHeight
            readonly property var record: root.backend.revision >= 0 ? root.backend.findRecord(tile.containerKey) || ({ id: tile.containerKey, name: tile.name, image: tile.image, state: tile.containerState, status: tile.status, health: tile.health, isRunning: tile.isRunning, project: tile.project, service: tile.service, composeFiles: tile.composeFiles, composeWorkDir: tile.composeWorkDir, pinned: false, restartPolicy: "" }) : null
            property bool verboseExpanded: false
            readonly property var operation: {
                const revision = root.backend.operationsRevision
                return root.backend.operationFor(tile.containerKey)
            }
            readonly property string attention: Status.attentionKind(tile.record)

            Rectangle {
                anchors.fill: parent
                radius: Kirigami.Units.smallSpacing
                color: tileHover.hovered ? Qt.alpha(Kirigami.Theme.highlightColor, Style.ALPHA.tintStrong) : Qt.alpha(Kirigami.Theme.textColor, Style.ALPHA.surface2)
                border.color: tileHover.hovered ? Kirigami.Theme.highlightColor : Qt.alpha(Kirigami.Theme.textColor, Style.ALPHA.borderFaint)
            }
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Kirigami.Units.smallSpacing * 1.5
                spacing: Kirigami.Units.smallSpacing / 2
                RowLayout {
                    Layout.fillWidth: true
                    ServiceIcon { backend: root.backend; record: tile.record; iconSize: Kirigami.Units.iconSizes.medium }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1
                        PlasmaComponents.Label { Layout.fillWidth: true; text: tile.name; font.bold: true; elide: Text.ElideRight; PlasmaComponents.ToolTip.text: tile.name; PlasmaComponents.ToolTip.visible: tileHover.hovered }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Kirigami.Units.smallSpacing / 2
                            ActionIcon {
                                visible: ["failed", "unhealthy", "paused", "restarting"].indexOf(tile.attention) >= 0
                                glyph: tile.attention === "failed" ? "circle-x" : tile.attention === "unhealthy" ? "dialog-warning" : tile.attention === "paused" ? "media-playback-pause" : "view-refresh"
                                implicitWidth: Kirigami.Units.iconSizes.small
                                implicitHeight: implicitWidth
                                color: tile.attention === "failed" || tile.attention === "unhealthy" ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.neutralTextColor
                            }
                            StateDot { containerState: tile.containerState; health: tile.health; showHealth: plasmoid.configuration.showHealth; failed: tile.attention === "failed" }
                            PlasmaComponents.BusyIndicator { visible: tile.operation.busy; running: visible; Layout.preferredWidth: Kirigami.Units.iconSizes.small; Layout.preferredHeight: Layout.preferredWidth }
                            PlasmaComponents.Label {
                                Layout.fillWidth: true
                                text: tile.operation.label || ((tile.attention === "failed" ? i18n("Failed") + " · " : tile.attention === "unhealthy" ? i18n("Unhealthy") + " · " : tile.attention === "paused" ? i18n("Paused") + " · " : tile.attention === "restarting" ? i18n("Restarting") + " · " : "") + Status.compactStatus(tile.status, tile.containerState, tile.record.runningFor || ""))
                                font: Kirigami.Theme.smallFont
                                color: tile.operation.label ? (tile.operation.ok ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.negativeTextColor) : tile.attention === "failed" || tile.attention === "unhealthy" ? Kirigami.Theme.negativeTextColor : tile.attention === "paused" || tile.attention === "restarting" ? Kirigami.Theme.neutralTextColor : tile.isRunning ? Kirigami.Theme.textColor : Kirigami.Theme.disabledTextColor
                                elide: Text.ElideRight
                                PlasmaComponents.ToolTip.text: (tile.status || tile.containerState) + (tile.operation.label ? "\n" + tile.operation.label : "")
                                PlasmaComponents.ToolTip.visible: tileHover.hovered
                            }
                        }
                    }
                }
                PlasmaComponents.Label {
                    visible: root.detailLevel >= 2
                    Layout.fillWidth: true
                    text: tile.record.image || tile.image
                    elide: Text.ElideMiddle
                    font: Kirigami.Theme.smallFont
                    color: Kirigami.Theme.disabledTextColor
                    PlasmaComponents.ToolTip.text: tile.record.image || tile.image
                    PlasmaComponents.ToolTip.visible: tileHover.hovered
                }
                ResourceMeter {
                    visible: root.detailLevel >= 1 && tile.isRunning && tile.cpu !== "" && plasmoid.configuration.showResourceBars
                    Layout.fillWidth: true
                    label: "CPU"
                    value: tile.cpuPct
                    maximum: 5
                    barWidth: Kirigami.Units.gridUnit * 4
                }
                ResourceMeter {
                    visible: root.detailLevel >= 1 && tile.isRunning && tile.mem !== "" && plasmoid.configuration.showResourceBars
                    Layout.fillWidth: true
                    label: "RAM"
                    value: tile.memPct
                    maximum: 5
                    barWidth: Kirigami.Units.gridUnit * 4
                }
                PlasmaComponents.Label {
                    visible: root.detailLevel >= 2 && !!tile.project
                    Layout.fillWidth: true
                    text: i18n("Project · %1", tile.project)
                    elide: Text.ElideRight
                    font: Kirigami.Theme.smallFont
                    PlasmaComponents.ToolTip.text: tile.project
                    PlasmaComponents.ToolTip.visible: tileHover.hovered
                }
                PlasmaComponents.Label {
                    visible: root.detailLevel >= 2 && !!tile.record.ports
                    Layout.fillWidth: true
                    text: i18n("Ports · %1", String(tile.record.ports).split(",").slice(0, 2).join(", ")) + (String(tile.record.ports).split(",").length > 2 ? " …" : "")
                    elide: Text.ElideRight
                    font: Kirigami.Theme.smallFont
                    PlasmaComponents.ToolTip.text: tile.record.ports || ""
                    PlasmaComponents.ToolTip.visible: tileHover.hovered
                }
                PlasmaComponents.Label {
                    visible: root.detailLevel >= 2 && !!tile.record.networks
                    Layout.fillWidth: true
                    text: i18n("Network · %1", String(tile.record.networks).split(",").slice(0, 2).join(", ")) + (String(tile.record.networks).split(",").length > 2 ? " …" : "")
                    elide: Text.ElideRight
                    font: Kirigami.Theme.smallFont
                    PlasmaComponents.ToolTip.text: tile.record.networks || ""
                    PlasmaComponents.ToolTip.visible: tileHover.hovered
                }
                RowLayout {
                    visible: root.detailLevel >= 2 && !!tile.record.mounts
                    Layout.fillWidth: true
                    PlasmaComponents.Label { Layout.fillWidth: true; text: i18np("%1 mount", "%1 mounts", String(tile.record.mounts).split(",").filter(function(x) { return x.trim() !== "" }).length); font: Kirigami.Theme.smallFont; elide: Text.ElideRight }
                    PlasmaComponents.Button { text: i18n("Show paths"); flat: true; onClicked: root.openDetail(tile.containerKey) }
                }
                PlasmaComponents.Label {
                    visible: root.detailLevel >= 3 && tile.verboseExpanded
                    Layout.fillWidth: true
                    text: i18n("ID · %1", String(tile.record.id || tile.containerKey).slice(0, 12))
                    elide: Text.ElideRight
                    font: Kirigami.Theme.smallFont
                    PlasmaComponents.ToolTip.text: String(tile.record.id || tile.containerKey)
                    PlasmaComponents.ToolTip.visible: tileHover.hovered
                }
                PlasmaComponents.Label {
                    visible: root.detailLevel >= 3 && tile.verboseExpanded && !!tile.record.imageId
                    Layout.fillWidth: true
                    text: i18n("Digest · %1", String(tile.record.imageId).slice(0, 19) + "…")
                    elide: Text.ElideRight
                    font: Kirigami.Theme.smallFont
                    PlasmaComponents.ToolTip.text: tile.record.imageId || ""
                    PlasmaComponents.ToolTip.visible: tileHover.hovered
                }
                Item { Layout.fillHeight: true }
                RowLayout {
                    objectName: "containerGridCardFooter"
                    Layout.fillWidth: true
                    spacing: 2
                    ActionToolButton { glyph: "document-view"; text: i18n("Details"); onClicked: root.openDetail(tile.containerKey) }
                    Rectangle { visible: root.detailLevel >= 2; Layout.preferredWidth: 1; Layout.preferredHeight: Kirigami.Units.iconSizes.small; color: Qt.alpha(Kirigami.Theme.textColor, Style.ALPHA.border) }
                    ActionToolButton { glyph: "document-properties"; text: i18n("Inspect"); visible: root.detailLevel >= 2 && tile.width >= Kirigami.Units.gridUnit * 18; enabled: !tile.operation.busy; onClicked: actions.showInspect(tile.record) }
                    ActionToolButton { glyph: "utilities-terminal"; text: i18n("Run command"); visible: root.detailLevel >= 2 && tile.width >= Kirigami.Units.gridUnit * 18; enabled: tile.isRunning && !root.backend.readOnly && !tile.operation.busy; onClicked: root.dialogs.openRun(tile.record) }
                    ActionToolButton { glyph: "document-edit"; text: i18n("Edit Compose file"); visible: root.detailLevel >= 2 && tile.width >= Kirigami.Units.gridUnit * 18 && !!tile.composeFiles && !root.backend.readOnly && root.backend.canUseCompose; enabled: !tile.operation.busy; onClicked: root.backend.editCompose(tile.record) }
                    Rectangle { visible: root.detailLevel >= 2; Layout.preferredWidth: 1; Layout.preferredHeight: Kirigami.Units.iconSizes.small; color: Qt.alpha(Kirigami.Theme.textColor, Style.ALPHA.border) }
                    Item { Layout.fillWidth: true }
                    ActionToolButton { visible: root.detailLevel >= 3; glyph: tile.verboseExpanded ? "chevron-up" : "chevron-down"; text: tile.verboseExpanded ? i18n("Less diagnostics") : i18n("More diagnostics"); onClicked: tile.verboseExpanded = !tile.verboseExpanded }
                    ActionToolButton { glyph: "application-menu"; text: i18n("Other actions"); onClicked: actions.popup(this, 0, height) }
                    ActionToolButton { text: tile.containerState === "not-created" ? i18n("Create and start") : tile.isRunning ? i18n("Stop") : i18n("Start"); glyph: tile.isRunning ? "media-playback-stop" : "media-playback-start"; enabled: !root.backend.readOnly && !tile.operation.busy && (tile.isRunning ? Parsers.canStop(tile.containerState) : Parsers.canStart(tile.containerState)); onClicked: tile.isRunning ? root.backend.stopContainer(tile.record) : root.backend.startContainer(tile.record) }
                }
            }
            HoverHandler { id: tileHover;onHoveredChanged:if(hovered)root.backend.previewContainer(tile.containerKey,false) }
            TapHandler {onTapped:root.backend.previewContainer(tile.containerKey,true)}
            TapHandler { onDoubleTapped: root.openDetail(tile.containerKey) }
            TapHandler { acceptedButtons: Qt.RightButton; onTapped: function(point) { actions.popup(tile, point.position.x, point.position.y) } }
            ContainerActions {
                id: actions
                backend: root.backend
                record: tile.record
                dialogs: root.dialogs
                onOpenDetail: function(recordId) { root.openDetail(recordId) }
                onOpenOutput: function(title, content, live, recordId) { root.openOutput(title, content, live, recordId) }
            }
        }
        Kirigami.PlaceholderMessage {
            anchors.centerIn: parent
            width: parent.width - Kirigami.Units.largeSpacing * 2
            visible: grid.count === 0
            text: !root.backend.engineActive ? i18n("Engine unavailable") : root.backend.total === 0 ? i18n("No containers yet.") : i18n("No containers match the current filters.")
        }
    }
}
