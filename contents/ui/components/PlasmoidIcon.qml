import QtQuick

import org.kde.kirigami as Kirigami

/*
 * PlasmoidIcon — the panel logo, rendered as a themed mask.
 *
 * `tint` exists so the panel can signal state through colour without needing a
 * separate icon per state: the engine being down and a container being
 * unhealthy both recolour the same glyph instead of swapping assets.
 */
Item {
    id: root

    property bool iconUseCustomColor: plasmoid.configuration.iconUseCustomColor
    property string iconColor: plasmoid.configuration.iconColor

    /* When set, wins over both the custom colour and the theme colour set. */
    property color tint: "transparent"
    property bool hasTint: false

    property var source

    implicitWidth: 16
    implicitHeight: implicitWidth

    Kirigami.Icon {
        id: svgItem
        width: root.width
        height: root.height
        anchors.centerIn: parent
        smooth: true
        isMask: true
        source: Qt.resolvedUrl("../../assets/" + root.source)
        color: {
            if (root.hasTint) return root.tint
            if (root.iconUseCustomColor) return root.iconColor
            return Kirigami.Theme.colorSet
        }

        Behavior on color {
            ColorAnimation {
                duration: Kirigami.Units.shortDuration
            }
        }
    }
}
