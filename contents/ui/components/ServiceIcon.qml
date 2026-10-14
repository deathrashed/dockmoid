import QtQuick
import org.kde.kirigami as Kirigami
import "../../lib/style.js" as Style

Item {
    id: root
    required property var backend
    required property var record
    property int iconSize: Kirigami.Units.iconSizes.smallMedium
    /* Sit the artwork on a soft rounded tile; `tileColor` tints it. */
    property bool tile: false
    property color tileColor: Kirigami.Theme.textColor
    readonly property real pad: root.tile ? Math.round(root.iconSize * 0.25) : 0
    readonly property var artwork: backend.iconFor(record)
    implicitWidth: iconSize + pad * 2
    implicitHeight: iconSize + pad * 2
    visible: artwork.hidden !== true
    Rectangle {
        visible: root.tile
        anchors.fill: parent
        radius: Kirigami.Units.smallSpacing * 1.5
        color: Qt.alpha(root.tileColor, Style.ALPHA.tintWeak)
        border.color: Qt.alpha(root.tileColor, Style.ALPHA.borderFaint)
    }
    Image {
        anchors.fill: parent
        anchors.margins: root.pad
        visible: root.artwork.url !== "" && root.artwork.colored === true
        source: visible ? root.artwork.url : ""
        sourceSize: Qt.size(Math.max(1,width*2), Math.max(1,height*2))
        fillMode: Image.PreserveAspectFit
        asynchronous: true
    }
    Kirigami.Icon {
        anchors.fill: parent
        anchors.margins: root.pad
        visible: root.artwork.url !== "" && root.artwork.colored !== true
        source: root.artwork.url
        isMask: !root.artwork.colored
        color: Kirigami.Theme.textColor
    }
    ActionIcon { anchors.fill: parent; anchors.margins: root.pad; visible: root.artwork.url === ""; glyph: "docker" }
}
