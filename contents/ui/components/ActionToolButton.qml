import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import "../../lib/actionIcons.js" as ActionIcons

PlasmaComponents.ToolButton {
    id: control
    property bool toolTipSuppressed: false
    property bool menuOpen: false
    onClicked: toolTipSuppressed = true
    onHoveredChanged: if (!hovered) toolTipSuppressed = false
    property string glyph: "application-menu"
    property int glyphSize: Kirigami.Units.iconSizes.small
    display: PlasmaComponents.AbstractButton.IconOnly
    icon.name: ""
    icon.source: Qt.resolvedUrl(ActionIcons.path(glyph))
    icon.color: Kirigami.Theme.textColor
    icon.width: glyphSize
    icon.height: glyphSize
    contentItem: Item {
        implicitWidth: control.glyphSize
        implicitHeight: control.glyphSize
        ActionIcon {
            anchors.centerIn: parent
            width: control.glyphSize
            height: width
            glyph: control.glyph
            color: control.enabled ? Kirigami.Theme.textColor : Kirigami.Theme.disabledTextColor
        }
    }
    PlasmaComponents.ToolTip { visible: control.hovered && !control.toolTipSuppressed && !control.menuOpen; text: control.text; delay: 500 }
}
