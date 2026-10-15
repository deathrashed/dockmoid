pragma ComponentBehavior: Bound

import QtQuick

import org.kde.kirigami as Kirigami
import "../../lib/style.js" as Style

/*
 * MiniBar — a low-usage-sensitive bar for CPU / memory.
 *
 * A number like "1432.11%" is hard to compare at a glance, and docker reports
 * memory as a percentage of *host* RAM, so the bar is the only thing that makes
 * "this one is hogging the box" obvious in a list of twenty.
 */
Item {
    id: root

    /* Actual percentage; CPU may exceed 100 on multicore hosts. */
    property real value: 0
    property string label: "Usage"
    // Full scale is explicit; numeric labels always retain the real percentage.
    property real maximum: 5
    readonly property real fraction: Math.max(0, Math.min(1, value / maximum))
    property color barColor: Kirigami.Theme.highlightColor
    property bool showTrack: true

    implicitHeight: Math.max(4, Kirigami.Units.smallSpacing / 2)
    implicitWidth: Kirigami.Units.gridUnit * 2

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: showTrack ? Qt.alpha(Kirigami.Theme.textColor, Style.ALPHA.track) : "transparent"
    }

    Tip { text: i18n("%1: %2% · bar scale: 0–%3%", root.label, root.value.toFixed(2), String(root.maximum)) }

    Rectangle {
        height: parent.height
        // Preserve a visible sliver for positive samples without colouring zero.
        width: root.value > 0 ? Math.min(parent.width, Math.max(2, parent.width * root.fraction)) : 0
        radius: height / 2
        color: root.barColor
    }
}
