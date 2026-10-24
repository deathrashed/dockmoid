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
 */
Rectangle {
    id: surface

    /* The button: reads hovered, down, enabled and visualFocus. */
    required property var control
    property bool emphasised: false
    property bool flat: false
    property bool danger: false
    readonly property bool usable: surface.control.enabled && surface.control.usable !== false

    implicitHeight: Kirigami.Units.gridUnit * 1.7
    implicitWidth: implicitHeight
    radius: Kirigami.Units.smallSpacing
    color: !surface.usable ? (surface.flat ? "transparent" : Qt.alpha(Kirigami.Theme.textColor, Style.ALPHA.surface1))
        : surface.control.down ? Qt.alpha(Kirigami.Theme.highlightColor, Style.ALPHA.tintStrong)
        : surface.emphasised ? Qt.alpha(Kirigami.Theme.highlightColor, surface.control.hovered ? Style.ALPHA.tintWeak : Style.ALPHA.tintFaint)
        : surface.control.hovered ? Qt.alpha(Kirigami.Theme.textColor, Style.ALPHA.surface3)
        : surface.flat ? "transparent" : Qt.alpha(Kirigami.Theme.textColor, Style.ALPHA.surface2)
    border.width: surface.control.visualFocus ? 2 : (surface.flat && !surface.emphasised && !surface.control.hovered ? 0 : 1)
    border.color: surface.control.visualFocus ? Kirigami.Theme.focusColor
        : surface.emphasised ? Qt.alpha(Kirigami.Theme.highlightColor, Style.WASH_BORDER.hover)
        : surface.danger && surface.control.hovered ? Qt.alpha(Kirigami.Theme.negativeTextColor, Style.WASH_BORDER.hover)
        : Qt.alpha(Kirigami.Theme.textColor, Style.ALPHA.border)
}
