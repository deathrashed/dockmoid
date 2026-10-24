import QtQuick
import QtQuick.Effects
import org.kde.kirigami as Kirigami
import "../../lib/actionIcons.js" as ActionIcons
import "../../lib/actionSvg.js" as SvgData

/* The icons the widget names are embedded with their colour written in: no
   theme lookup or GPU masking is needed. Any other Lucide name (one added to
   the code without regenerating) loads from its bundled file and is tinted here: Lucide
   strokes are black, so they are brightened to white and coloured. The
   software renderer has no shader effects, so there the file is shown as it
   is. A name with no file shows the alert icon. */
Item {
    id: icon
    property string glyph: "document-view"
    property string assetName: ""
    property color color: Kirigami.Theme.textColor
    readonly property string name: icon.assetName !== "" ? icon.assetName : ActionIcons.path(icon.glyph).split("/").pop().replace(/\.svg$/, "")
    readonly property bool embedded: SvgData.has(icon.name)
    implicitWidth: Kirigami.Units.iconSizes.smallMedium
    implicitHeight: implicitWidth
    Image {
        anchors.fill: parent
        readonly property bool missing: !icon.embedded && fromFile.status === Image.Error
        visible: icon.embedded || missing
        source: icon.embedded ? SvgData.url(icon.name, icon.color)
            : missing ? SvgData.url("circle-alert", icon.color) : ""
        sourceSize.width: Math.max(1, width * 2)
        sourceSize.height: Math.max(1, height * 2)
        fillMode: Image.PreserveAspectFit
    }
    Image {
        id: fromFile
        anchors.fill: parent
        visible: !icon.embedded && !tint.visible && GraphicsInfo.api === GraphicsInfo.Software
        source: icon.embedded ? "" : Qt.resolvedUrl("../../assets/lucide/" + icon.name + ".svg")
        sourceSize.width: Math.max(1, width * 2)
        sourceSize.height: Math.max(1, height * 2)
        fillMode: Image.PreserveAspectFit
    }
    MultiEffect {
        id: tint
        anchors.fill: parent
        visible: !icon.embedded && fromFile.status === Image.Ready && GraphicsInfo.api !== GraphicsInfo.Software
        source: fromFile
        brightness: 1.0
        colorization: 1.0
        colorizationColor: icon.color
    }
}
