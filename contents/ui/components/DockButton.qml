import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import "../../lib/actionIcons.js" as ActionIcons

/*
 * DockButton — the one button the widget draws its own artwork on.
 *
 * `variant` picks the emphasis: "default", "primary" (accent), "danger"
 * (negative colour on the icon and label) or "flat". `iconOnly` replaces the
 * label with a tooltip; it is how the compact per-row controls are drawn.
 */
PlasmaComponents.Button {
    id: control

    property string glyph: "document-view"
    property string variant: "default"
    property bool iconOnly: false
    property int glyphSize: Kirigami.Units.iconSizes.small
    property bool toolTipSuppressed: false
    property bool menuOpen: false

    /* Colour while enabled. The disabled colour is read inside each child
       item, because Kirigami.Theme resolves it per item and an item inside a
       disabled button uses the Disabled colour group. */
    readonly property color activeColor: control.variant === "danger" ? Kirigami.Theme.negativeTextColor
        : Kirigami.Theme.textColor

    flat: control.iconOnly || control.variant === "flat"
    highlighted: control.variant === "primary"
    display: control.iconOnly ? PlasmaComponents.AbstractButton.IconOnly : PlasmaComponents.AbstractButton.TextBesideIcon
    icon.name: ""
    icon.source: Qt.resolvedUrl(ActionIcons.path(glyph))
    icon.color: Kirigami.Theme.textColor
    icon.width: control.glyphSize
    icon.height: control.glyphSize

    onClicked: toolTipSuppressed = true
    onHoveredChanged: if (!hovered) toolTipSuppressed = false

    contentItem: RowLayout {
        spacing: control.iconOnly ? 0 : control.spacing
        ActionIcon {
            glyph: control.glyph
            color: control.enabled ? control.activeColor : Kirigami.Theme.disabledTextColor
            Layout.alignment: Qt.AlignCenter
            implicitWidth: control.glyphSize
            implicitHeight: control.glyphSize
        }
        PlasmaComponents.Label {
            visible: !control.iconOnly
            text: control.Kirigami.MnemonicData.richTextLabel
            font: control.font
            color: control.enabled ? control.activeColor : Kirigami.Theme.disabledTextColor
        }
    }

    PlasmaComponents.ToolTip {
        visible: control.iconOnly && control.hovered && !control.toolTipSuppressed && !control.menuOpen
        text: control.text
        delay: 500
    }
}
