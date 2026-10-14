import QtQuick
import org.kde.kirigami as Kirigami
import "../../lib/actionIcons.js" as ActionIcons
import "../../lib/actionSvg.js" as SvgData

/* SVG colour is explicit: no theme lookup or GPU masking is needed. */
Item {
    id: icon
    property string glyph: "document-view"
    property string assetName: ""
    property color color: Kirigami.Theme.textColor
    implicitWidth: Kirigami.Units.iconSizes.smallMedium
    implicitHeight: implicitWidth
    Image {
        anchors.fill: parent
        source: SvgData.url(icon.assetName !== "" ? icon.assetName : ActionIcons.path(icon.glyph).split("/").pop().replace(/\.svg$/, ""), icon.color)
        sourceSize.width: Math.max(1, width * 2)
        sourceSize.height: Math.max(1, height * 2)
        fillMode: Image.PreserveAspectFit
    }
}
