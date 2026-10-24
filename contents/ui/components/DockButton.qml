import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import "../../lib/actionIcons.js" as ActionIcons
import "../../lib/style.js" as Style

/*
 * DockButton — the one button the widget draws its own artwork on.
 *
 * `variant` picks the emphasis: "default", "primary" (the selected-tab
 * look: accent wash and outline), "danger" (negative colour on the icon and
 * label) or "flat". A checkable button that is on looks like "primary". `iconOnly` replaces the
 * label with a tooltip; it is how the compact per-row controls are drawn.
 * `blockedReason` greys it out like `enabled: false` while keeping a tooltip
 * that says why (a disabled control gets no hover).
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
    property string blockedReason: ""
    readonly property bool usable: control.enabled && control.blockedReason === ""

    /* Colour while enabled. The disabled colour is read inside each child
       item, because Kirigami.Theme resolves it per item and an item inside a
       disabled button uses the Disabled colour group. */
    readonly property bool primary: control.variant === "primary"
    /* Text on the accent fill: dark on a light accent, white on a dark one. */
    readonly property color activeColor: control.variant === "danger" ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.textColor

    /* One control height everywhere; icon-only buttons are square. */
    implicitHeight: Math.max(implicitBackgroundHeight + topInset + bottomInset,
                             implicitContentHeight + topPadding + bottomPadding,
                             Kirigami.Units.gridUnit * 1.7)
    implicitWidth: control.iconOnly ? implicitHeight
        : Math.max(implicitBackgroundWidth + leftInset + rightInset, implicitContentWidth + leftPadding + rightPadding)

    /* Room between the frame and the artwork, so the icon never touches the
       outline and the label never runs into the right edge. */
    leftPadding: control.iconOnly ? Kirigami.Units.smallSpacing : Kirigami.Units.largeSpacing
    rightPadding: control.iconOnly ? Kirigami.Units.smallSpacing : Kirigami.Units.largeSpacing + Kirigami.Units.smallSpacing / 2
    spacing: Kirigami.Units.smallSpacing * 1.5

    flat: control.iconOnly || control.variant === "flat"
    topPadding: Kirigami.Units.smallSpacing
    bottomPadding: Kirigami.Units.smallSpacing
    background: ButtonSurface {
        control: control
        emphasised: control.primary || control.checked || control.menuOpen
        flat: control.flat
        danger: control.variant === "danger"
    }
    display: control.iconOnly ? PlasmaComponents.AbstractButton.IconOnly : PlasmaComponents.AbstractButton.TextBesideIcon
    icon.name: ""
    icon.source: Qt.resolvedUrl(ActionIcons.path(glyph))
    icon.color: Kirigami.Theme.textColor
    icon.width: control.glyphSize
    icon.height: control.glyphSize

    onClicked: toolTipSuppressed = true
    // Keyboard activation of a blocked button does nothing either.
    Keys.onPressed: function (event) { if (control.blockedReason !== "" && (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) event.accepted = true }
    onHoveredChanged: if (!hovered) toolTipSuppressed = false

    // Centred as a group, so a button stretched by a layout keeps its
    // icon and label together in the middle instead of against the left edge.
    contentItem: Item {
        implicitWidth: contentRow.implicitWidth
        implicitHeight: contentRow.implicitHeight
        RowLayout {
            id: contentRow
            anchors.centerIn: parent
            spacing: control.iconOnly ? 0 : control.spacing
            ActionIcon {
                glyph: control.glyph
                color: control.usable ? (control.iconTone !== "" ? (Style.HUE[control.iconTone] !== undefined ? Style.HUE[control.iconTone] : control.activeColor) : control.activeColor) : Kirigami.Theme.disabledTextColor
                Layout.alignment: Qt.AlignCenter
                implicitWidth: control.glyphSize
                implicitHeight: control.glyphSize
            }
            PlasmaComponents.Label {
                visible: !control.iconOnly
                text: control.Kirigami.MnemonicData.richTextLabel
                font: control.font
                color: control.usable ? control.activeColor : Kirigami.Theme.disabledTextColor
            }
        }
    }

    PlasmaComponents.ToolTip {
        visible: control.iconOnly && control.hovered && !control.toolTipSuppressed && !control.menuOpen && control.blockedReason === ""
        text: control.text
        delay: 500
    }

    // While blocked: swallow presses so the button does nothing, and explain why on hover.
    MouseArea {
        id: blocker
        anchors.fill: parent
        visible: control.blockedReason !== ""
        hoverEnabled: true
        acceptedButtons: Qt.AllButtons
        PlasmaComponents.ToolTip {
            visible: blocker.containsMouse
            text: control.iconOnly ? control.text + "\n" + control.blockedReason : control.blockedReason
            delay: 500
        }
    }
    Accessible.description: control.blockedReason
}
