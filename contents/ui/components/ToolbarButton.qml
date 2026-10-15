import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import "../../lib/style.js" as Style

// This presentation applies only to the overview toolbar, not container actions.
PlasmaComponents.ToolButton {
    id: control
    property bool toolTipSuppressed: false
    property bool menuOpen: false
    onClicked: toolTipSuppressed = true
    onHoveredChanged: if (!hovered) toolTipSuppressed = false
    property string glyph: "application-menu"
    property int presentation: 0
    property string label: text
    property bool menuIndicator: false
    property string badgeText: ""
    /* Tones name or hue for the icon; empty keeps the text colour. */
    property string tint: ""
    readonly property bool stacked: presentation === 3
    readonly property bool showIcon: presentation !== 2
    readonly property bool showLabel: presentation !== 0
    readonly property real idealWidth: Math.max(background ? background.implicitWidth : 0,
        leftPadding + rightPadding + (stacked
            ? Math.max(showIcon ? Kirigami.Units.iconSizes.small : 0, showLabel ? caption.implicitWidth : 0)
            : (showIcon ? Kirigami.Units.iconSizes.small : 0) + (showLabel ? caption.implicitWidth : 0)
                + (showIcon && showLabel ? Kirigami.Units.smallSpacing : 0))
        + (menuIndicator ? Kirigami.Units.iconSizes.small / 2 + Kirigami.Units.smallSpacing : 0))
    implicitWidth: idealWidth
    contentItem: RowLayout {
        spacing: Kirigami.Units.smallSpacing
        GridLayout {
        Layout.fillWidth: true
        columns: control.stacked ? 1 : 2
        rowSpacing: 2
        columnSpacing: Kirigami.Units.smallSpacing
        ActionIcon {
            visible: control.showIcon
            glyph: control.glyph
            Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
            Layout.preferredWidth: Kirigami.Units.iconSizes.small
            Layout.preferredHeight: Kirigami.Units.iconSizes.small
            color: control.enabled ? (control.tint !== "" ? (Style.HUE[control.tint] !== undefined ? Style.HUE[control.tint] : Kirigami.Theme.textColor) : Kirigami.Theme.textColor) : Kirigami.Theme.disabledTextColor
        }
        PlasmaComponents.Label {
            id: caption
            visible: control.showLabel
            text: control.label
            font: control.font
            Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
            color: control.enabled ? Kirigami.Theme.textColor : Kirigami.Theme.disabledTextColor
        }
        }
        ActionIcon {
            visible: control.menuIndicator
            glyph: "chevron-down"
            Layout.preferredWidth: Kirigami.Units.iconSizes.small / 2
            Layout.preferredHeight: Kirigami.Units.iconSizes.small
            color: control.enabled ? Kirigami.Theme.textColor : Kirigami.Theme.disabledTextColor
        }
    }
    Rectangle {
        visible: control.badgeText !== ""
        anchors.right: parent.right; anchors.top: parent.top
        width: Math.max(12, badge.implicitWidth + 4); height: 12; radius: 6
        color: Kirigami.Theme.highlightColor
        PlasmaComponents.Label { id: badge; anchors.centerIn: parent; text: control.badgeText; font.pixelSize: 9; font.bold: true; color: Kirigami.Theme.highlightedTextColor }
    }
    PlasmaComponents.ToolTip { visible: control.hovered && !control.toolTipSuppressed && !control.menuOpen; text: control.text; delay: 500 }
}
