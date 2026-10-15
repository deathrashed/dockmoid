import QtQuick
import org.kde.kirigami as Kirigami
import "../../lib/style.js" as Style

/*
 * IconButton — a square icon button made of a rectangle and an icon.
 *
 * The Plasma button style builds a stack of frame, shadow and focus items for
 * every button; a list row carries four. This draws the same job with a handful
 * of items, so lists stay quick to build and to scroll. It keeps the parts of
 * the button API the widget uses: glyph, text (tooltip and accessible name),
 * clicked, checkable/checked, enabled, hovered and menuOpen.
 */
Item {
    id: control

    property string glyph: "application-menu"
    property string text: ""
    property int glyphSize: Kirigami.Units.iconSizes.small
    property bool checkable: false
    property bool checked: false
    property bool menuOpen: false
    property bool toolTipSuppressed: false
    readonly property bool hovered: hover.hovered
    readonly property bool down: tap.pressed
    signal clicked()

    implicitWidth: Kirigami.Units.gridUnit * 1.7
    implicitHeight: implicitWidth
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: control.text
    Accessible.onPressAction: control.activate()

    function activate() {
        if (!control.enabled) return
        if (control.checkable) control.checked = !control.checked
        control.clicked()
    }

    Keys.onReturnPressed: control.activate()
    Keys.onEnterPressed: control.activate()
    Keys.onSpacePressed: control.activate()
    onHoveredChanged: if (!hovered) control.toolTipSuppressed = false

    Rectangle {
        anchors.fill: parent
        radius: Kirigami.Units.smallSpacing
        color: control.down ? Qt.alpha(Kirigami.Theme.textColor, Style.ALPHA.hover)
            : control.checked ? Qt.alpha(Kirigami.Theme.highlightColor, Style.ALPHA.tintFaint)
            : control.hovered ? Qt.alpha(Kirigami.Theme.textColor, Style.ALPHA.surface3) : "transparent"
        border.width: control.activeFocus || control.checked ? 1 : 0
        border.color: control.activeFocus ? Kirigami.Theme.highlightColor : Qt.alpha(Kirigami.Theme.highlightColor, Style.WASH_BORDER.hover)
    }
    ActionIcon {
        anchors.centerIn: parent
        glyph: control.glyph
        color: control.enabled ? Kirigami.Theme.textColor : Kirigami.Theme.disabledTextColor
        implicitWidth: control.glyphSize
        implicitHeight: control.glyphSize
    }
    HoverHandler { id: hover; cursorShape: control.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor }
    TapHandler {
        id: tap
        enabled: control.enabled
        gesturePolicy: TapHandler.ReleaseWithinBounds
        onTapped: { control.toolTipSuppressed = true; control.activate() }
    }
    Tip { text: control.text; suppressed: control.menuOpen || control.toolTipSuppressed }
}
