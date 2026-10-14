import QtQuick

import org.kde.kirigami as Kirigami
import "../../lib/actionSvg.js" as SvgData

/*
 * PlasmoidIcon — the panel logo, rendered as an explicitly coloured SVG.
 *
 * `tint` exists so the panel can signal state through colour without needing a
 * separate icon per state: the engine being down and a container being
 * unhealthy both recolour the same glyph instead of swapping assets.
 */
Item {
    id: root

    property bool iconUseCustomColor: plasmoid && plasmoid.configuration ? plasmoid.configuration.iconUseCustomColor : false
    property string iconColor: plasmoid && plasmoid.configuration ? plasmoid.configuration.iconColor : ""

    /* When set, wins over both the custom colour and the theme colour set. */
    property color tint: "transparent"
    property bool hasTint: false

    property var source

    implicitWidth: 16
    implicitHeight: implicitWidth

    Image {
        anchors.fill: parent
        source: SvgData.url(String(root.source || "logo-dockmoid-whale.svg").replace(/\.svg$/, ""), root.hasTint ? root.tint : root.iconUseCustomColor ? root.iconColor : Kirigami.Theme.textColor)
        sourceSize: Qt.size(Math.max(1, width * 2), Math.max(1, height * 2))
        fillMode: Image.PreserveAspectFit
        smooth: true
    }
}
