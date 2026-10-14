import QtQuick
import org.kde.kirigami as Kirigami

/*
 * Tones — the five meanings the popup colours things with, named by meaning
 * rather than by colour, so "running", "needs a look" and "broken" are chosen
 * in one place. Put one instance on an item and read its colours, or call
 * color(name) with "ok", "info", "warn", "bad" or "muted".
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

    function color(tone) {
        switch (tone) {
        case "ok": return root.ok
        case "info": return root.info
        case "warn": return root.warn
        case "bad": return root.bad
        case "muted": return root.muted
        default: return root.text
        }
    }
}
