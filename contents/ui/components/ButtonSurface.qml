import QtQuick
import org.kde.kirigami as Kirigami
import "../../lib/style.js" as Style

/*
 * ButtonSurface — the one background every Dockmoid button draws.
 *
 * Quiet by default: a faint surface and hairline (none for flat buttons
 * until hovered). Emphasis — a primary action, a toggle that is on, an open
 * menu — uses the same look as a selected tab: a light accent wash and an
 * accent outline, never a solid accent fill. Drawn here rather than by the
 * Plasma style, so every button looks the same whichever page created it.
 *
 * Colours come from the button's own theme (see DockButton for why that
 * theme always follows the parent's).
 */
Rectangle {
    id: surface

    /* The button: reads hovered, down, enabled and visualFocus. */
    required property var control
    property bool emphasised: false
    property bool flat: false
    property bool danger: false
    readonly property bool usable: surface.control.enabled && surface.control.usable !== false
    /* The button's own theme colours, passed in by the button (see above). */
    property color textColor: Kirigami.Theme.textColor
    property color accentColor: Kirigami.Theme.highlightColor
    property color focusColor: Kirigami.Theme.focusColor
    property color negativeColor: Kirigami.Theme.negativeTextColor

    implicitHeight: Kirigami.Units.gridUnit * 1.7
    implicitWidth: implicitHeight
    radius: Kirigami.Units.smallSpacing
    color: !surface.usable ? (surface.flat ? "transparent" : Qt.alpha(surface.textColor, Style.ALPHA.surface1))
        : surface.control.down ? Qt.alpha(surface.accentColor, Style.ALPHA.tintStrong)
        : surface.emphasised ? Qt.alpha(surface.accentColor, surface.control.hovered ? Style.ALPHA.tintWeak : Style.ALPHA.tintFaint)
        : surface.control.hovered ? Qt.alpha(surface.textColor, Style.ALPHA.surface3)
        : surface.flat ? "transparent" : Qt.alpha(surface.textColor, Style.ALPHA.surface2)
    border.width: surface.control.visualFocus ? 2 : (surface.flat && !surface.emphasised && !surface.control.hovered ? 0 : 1)
    border.color: surface.control.visualFocus ? surface.focusColor
        : surface.emphasised ? Qt.alpha(surface.accentColor, Style.WASH_BORDER.hover)
        : surface.danger && surface.control.hovered ? Qt.alpha(surface.negativeColor, Style.WASH_BORDER.hover)
        : Qt.alpha(surface.textColor, Style.ALPHA.border)
}
