import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

/*
 * StatusBar — the engine-wide footer.
 *
 * A homelab question is rarely "what is this one container doing" but "is
 * anything wrong at all", so the footer carries the totals: how many are up,
 * how much CPU and memory the stack is using, and (optionally) how much disk
 * the images and volumes are eating.
 */
Item {
    id: root

    required property var backend

    readonly property var cfg: plasmoid.configuration
    readonly property var info: root.backend.engineInfo || ({})
    readonly property bool showDisk: root.cfg.showDiskUsage && root.backend.diskUsage.length > 0

    implicitHeight: mainRow.implicitHeight + (root.showDisk ? diskRow.implicitHeight : 0)
        + Kirigami.Units.smallSpacing

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: Kirigami.Units.smallSpacing
        anchors.rightMargin: Kirigami.Units.smallSpacing
        spacing: 0

        RowLayout {
            id: mainRow
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing * 1.5

            PlasmaComponents.Label {
                text: i18np("%1 running", "%1 running", root.backend.running)
                color: Kirigami.Theme.positiveTextColor
                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                elide: Text.ElideRight
            }

            PlasmaComponents.Label {
                text: i18np("%1 stopped", "%1 stopped", root.backend.stopped)
                visible: root.backend.stopped > 0
                color: Kirigami.Theme.disabledTextColor
                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                elide: Text.ElideRight
            }

            PlasmaComponents.Label {
                text: i18np("%1 paused", "%1 paused", root.backend.pausedCount)
                visible: root.backend.pausedCount > 0
                color: Kirigami.Theme.highlightColor
                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                elide: Text.ElideRight
            }

            PlasmaComponents.Label {
                text: i18np("%1 unhealthy", "%1 unhealthy", root.backend.unhealthy)
                visible: root.backend.unhealthy > 0 && root.cfg.showHealth
                color: Kirigami.Theme.negativeTextColor
                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                elide: Text.ElideRight
            }

            Item { Layout.fillWidth: true }

            PlasmaComponents.Label {
                text: i18n("CPU %1%", root.backend.cpuSum.toFixed(1))
                visible: root.backend.running > 0
                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                color: Kirigami.Theme.textColor
            }

            PlasmaComponents.Label {
                text: i18n("MEM %1%", root.backend.memSum.toFixed(1))
                visible: root.backend.running > 0
                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                color: Kirigami.Theme.textColor
            }

            PlasmaComponents.Label {
                text: i18n("Images: %1", root.info.images || 0)
                visible: root.info.images !== undefined && root.info.images > 0
                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                color: Kirigami.Theme.disabledTextColor
            }

            PlasmaComponents.Label {
                text: i18n("Engine %1", root.info.serverVersion)
                visible: root.info.serverVersion !== undefined && root.info.serverVersion !== ""
                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                color: Kirigami.Theme.disabledTextColor
                elide: Text.ElideRight
            }
        }

        RowLayout {
            id: diskRow
            Layout.fillWidth: true
            visible: root.showDisk
            spacing: Kirigami.Units.smallSpacing * 1.5

            Repeater {
                model: root.backend.diskUsage

                delegate: PlasmaComponents.Label {
                    required property var modelData
                    text: i18n("%1 %2", modelData.type, modelData.size)
                    font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                    color: Kirigami.Theme.disabledTextColor
                    elide: Text.ElideRight
                }
            }
        }
    }
}
