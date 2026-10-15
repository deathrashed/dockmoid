import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import "../../lib/actionIcons.js" as ActionIcons
import "../../lib/style.js" as Style

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
    /* Colour of the icon alone (a Tones name or hue); the label keeps the text colour. */
    property string iconTone: ""

    /* Colour while enabled. The disabled colour is read inside each child
       item, because Kirigami.Theme resolves it per item and an item inside a
       disabled button uses the Disabled colour group. */
    readonly property bool primary: control.variant === "primary"
    /* Text on the accent fill: dark on a light accent, white on a dark one. */
    readonly property color onAccent: Kirigami.Theme.highlightColor.hslLightness > 0.62 ? "#1b1e20" : "#ffffff"
    readonly property color activeColor: control.variant === "danger" ? Kirigami.Theme.negativeTextColor
        : control.primary ? control.onAccent
        : Kirigami.Theme.textColor

    /* One control height everywhere; icon-only buttons are square. */
    implicitHeight: Math.max(implicitBackgroundHeight + topInset + bottomInset,
                             implicitContentHeight + topPadding + bottomPadding,
                             Kirigami.Units.gridUnit * 1.7)
    implicitWidth: control.iconOnly ? implicitHeight
        : Math.max(implicitBackgroundWidth + leftInset + rightInset, implicitContentWidth + leftPadding + rightPadding)

    flat: control.iconOnly || control.variant === "flat"
    display: control.iconOnly ? PlasmaComponents.AbstractButton.IconOnly : PlasmaComponents.AbstractButton.TextBesideIcon
    icon.name: ""
    icon.source: Qt.resolvedUrl(ActionIcons.path(glyph))
    icon.color: Kirigami.Theme.textColor
    icon.width: control.glyphSize
    icon.height: control.glyphSize

    onClicked: toolTipSuppressed = true
    onHoveredChanged: if (!hovered) toolTipSuppressed = false

    /* The accent fill sits between the style's frame and the content, so the
       default look of every other variant stays exactly as the style draws it. */
    Rectangle {
        z: -0.5
        visible: control.primary
        anchors.fill: parent
        radius: Kirigami.Units.smallSpacing
        color: !control.enabled ? Qt.alpha(Kirigami.Theme.textColor, Style.ALPHA.surface3)
            : control.down ? Qt.darker(Kirigami.Theme.highlightColor, 1.25)
            : control.hovered ? Qt.lighter(Kirigami.Theme.highlightColor, 1.12)
            : Kirigami.Theme.highlightColor
        border.width: control.visualFocus ? 2 : 1
        border.color: control.visualFocus ? Kirigami.Theme.textColor
            : Qt.alpha(Qt.darker(Kirigami.Theme.highlightColor, 1.4), 0.8)
    }

    contentItem: RowLayout {
        spacing: control.iconOnly ? 0 : control.spacing
        ActionIcon {
            glyph: control.glyph
            color: control.enabled ? (control.iconTone !== "" ? (Style.HUE[control.iconTone] !== undefined ? Style.HUE[control.iconTone] : control.activeColor) : control.activeColor) : Kirigami.Theme.disabledTextColor
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
