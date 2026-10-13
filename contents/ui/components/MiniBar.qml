pragma ComponentBehavior: Bound

import QtQuick

import org.kde.kirigami as Kirigami

/*
 * MiniBar — a 3px usage bar for CPU / memory.
 *
 * A number like "1432.11%" is hard to compare at a glance, and docker reports
 * memory as a percentage of *host* RAM, so the bar is the only thing that makes
 * "this one is hogging the box" obvious in a list of twenty.
 */
Item {
    id: root

    /* 0..100 */
    property real value: 0
    property color barColor: Kirigami.Theme.highlightColor
    property bool showTrack: true

    implicitHeight: Math.max(3, Kirigami.Units.smallSpacing / 2)
    implicitWidth: Kirigami.Units.gridUnit * 2

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: showTrack ? Qt.alpha(Kirigami.Theme.textColor, 0.12) : "transparent"
    }

    Rectangle {
        height: parent.height
        // Clamped so a container reporting >100% (possible for CPU across many
        // cores) still renders inside the track instead of overflowing it.
        width: parent.width * Math.max(0, Math.min(1, root.value / 100))
        radius: height / 2
        color: root.barColor
        Behavior on width {
            NumberAnimation {
                duration: Kirigami.Units.shortDuration
                easing.type: Easing.OutQuad
            }
        }
    }
}
