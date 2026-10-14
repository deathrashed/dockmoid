import QtQuick
import org.kde.kirigami as Kirigami
import "../../lib/style.js" as Style

/*
 * Tones — the five meanings the popup colours things with, named by meaning
 * rather than by colour, so "running", "needs a look" and "broken" are chosen
 * in one place. Put one instance on an item and read its colours, or call
 * color(name) with "ok", "info", "warn", "bad", "muted" or one of the
 * accent hues in lib/style.js ("cyan", "blue", "violet", "pink", "amber", "teal", "slate").
 *
 * It stays a visible, zero-sized Item on purpose: Kirigami.Theme is not
 * resolved for an invisible item and every colour reads back black.
 */
Item {
    id: root
    width: 0
    height: 0

    readonly property color ok: Kirigami.Theme.positiveTextColor
    readonly property color info: Kirigami.Theme.highlightColor
    readonly property color warn: Kirigami.Theme.neutralTextColor
    readonly property color bad: Kirigami.Theme.negativeTextColor
    readonly property color muted: Kirigami.Theme.disabledTextColor
    readonly property color text: Kirigami.Theme.textColor
    readonly property color cyan: Style.HUE.cyan
    readonly property color blue: Style.HUE.blue
    readonly property color violet: Style.HUE.violet
    readonly property color pink: Style.HUE.pink
    readonly property color amber: Style.HUE.amber
    readonly property color teal: Style.HUE.teal
    readonly property color slate: Style.HUE.slate

    function color(tone) {
        switch (tone) {
        case "ok": return root.ok
        case "info": return root.info
        case "warn": return root.warn
        case "bad": return root.bad
        case "muted": return root.muted
        case "cyan": return root.cyan
        case "blue": return root.blue
        case "violet": return root.violet
        case "pink": return root.pink
        case "amber": return root.amber
        case "teal": return root.teal
        case "slate": return root.slate
        default: return root.text
        }
    }
}
