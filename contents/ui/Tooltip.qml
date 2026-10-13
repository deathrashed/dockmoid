import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.extras as PlasmaExtras

/*
 * Tooltip — the panel hover card.
 *
 * Answers the three questions someone actually hovers a panel widget to ask:
 * is Docker up, is anything wrong, and what is it using. Engine-wide CPU and
 * memory are the sum across running containers, which is the number that tells
 * you whether the box is in trouble.
 */
ColumnLayout {
    id: root

    required property var backend

    readonly property var cfg: plasmoid.configuration
    readonly property var info: root.backend.engineInfo || ({})

    implicitWidth: Math.max(header.implicitWidth, rows.implicitWidth) + Kirigami.Units.gridUnit

    PlasmaExtras.Heading {
        id: header
        Layout.fillWidth: true
        level: 3
        elide: Text.ElideRight
        text: {
            if (!root.backend.engineKnown) return i18n("Checking Docker…")
            if (!root.backend.engineActive) return i18n("Docker is not running")
            return i18n("Docker is running")
        }
        color: root.backend.engineActive
            ? Kirigami.Theme.textColor
            : Kirigami.Theme.negativeTextColor
    }

    GridLayout {
        id: rows
        Layout.fillWidth: true
        columns: 2
        columnSpacing: Kirigami.Units.largeSpacing
        rowSpacing: 2

        PlasmaComponents.Label {
            text: i18n("Running")
            opacity: 1
        }
        PlasmaComponents.Label {
            text: String(root.backend.running)
            opacity: 0.7
        }

        PlasmaComponents.Label {
            text: i18n("Stopped")
            opacity: 1
        }
        PlasmaComponents.Label {
            text: String(root.backend.stopped)
            opacity: 0.7
        }

        PlasmaComponents.Label {
            text: i18n("Unhealthy")
            opacity: 1
            visible: root.cfg.showHealth
        }
        PlasmaComponents.Label {
            text: String(root.backend.unhealthy)
            opacity: 0.7
            visible: root.cfg.showHealth
            color: root.backend.unhealthy > 0
                ? Kirigami.Theme.negativeTextColor
                : Kirigami.Theme.textColor
        }

        PlasmaComponents.Label {
            text: i18n("Images")
            opacity: 1
            visible: root.info.images !== undefined
        }
        PlasmaComponents.Label {
            text: String(root.info.images || 0)
            opacity: 0.7
            visible: root.info.images !== undefined
        }

        PlasmaComponents.Label {
            text: i18n("CPU")
            opacity: 1
            visible: root.backend.running > 0
        }
        PlasmaComponents.Label {
            text: i18n("%1%", root.backend.cpuSum.toFixed(1))
            opacity: 0.7
            visible: root.backend.running > 0
        }

        PlasmaComponents.Label {
            text: i18n("Memory")
            opacity: 1
            visible: root.backend.running > 0
        }
        PlasmaComponents.Label {
            text: i18n("%1%", root.backend.memSum.toFixed(1))
            opacity: 0.7
            visible: root.backend.running > 0
        }

        PlasmaComponents.Label {
            text: i18n("Engine")
            opacity: 1
            visible: root.info.serverVersion !== undefined
                && root.info.serverVersion !== ""
        }
        PlasmaComponents.Label {
            text: String(root.info.serverVersion || "")
            opacity: 0.7
            visible: root.info.serverVersion !== undefined
                && root.info.serverVersion !== ""
        }
    }
}
