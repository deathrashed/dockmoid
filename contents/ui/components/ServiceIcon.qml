import QtQuick
import org.kde.kirigami as Kirigami

Item {
    id: icon
    required property var backend
    required property var record
    property int iconSize: Kirigami.Units.iconSizes.smallMedium
    readonly property var artwork: backend.iconFor(record)
    implicitWidth: iconSize
    implicitHeight: iconSize
    visible: artwork.hidden !== true
    Image {
        anchors.fill: parent
        visible: icon.artwork.url !== "" && icon.artwork.colored === true
        source: visible ? icon.artwork.url : ""
        sourceSize: Qt.size(Math.max(1,width*2), Math.max(1,height*2))
        fillMode: Image.PreserveAspectFit
        asynchronous: true
    }
    Kirigami.Icon {
        anchors.fill: parent
        visible: icon.artwork.url !== "" && icon.artwork.colored !== true
        source: icon.artwork.url
        isMask: !icon.artwork.colored
        color: Kirigami.Theme.textColor
    }
    ActionIcon { anchors.fill: parent; visible: icon.artwork.url === ""; glyph: "docker" }
}
