import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import "../../lib/style.js" as Style

/*
 * Pill — a small badge in the style of shieldcn's ghost and outline badges.
 *
 * Transparent inside, a rounded outline in the tone colour, and plain
 * foreground text and icon: the colour lives in the border (and the status
 * dot), never in a tinted fill or tinted text.
 *
 *   variant  "ghost" / "outline"  outline only (the same look; default)
 *            "solid"              filled with the tone colour
 *            "secondary"          neutral wash, no outline
 *   label    when set, the badge is two-tone: a quiet label segment and the
 *            value segment ("health | healthy")
 *   colorIcon  paint the icon in the tone colour instead of the foreground
 *   statusDot, pulse   a leading dot; pulse breathes it (keep it to one or two
 *            badges on screen)
 *
 * `tone` is a Tones name: "ok", "info", "warn", "bad", "muted" or an accent hue.
 */
Rectangle {
    id: root

    property string text: ""
    property string label: ""
    property string tone: "muted"
    property string glyph: ""
    property string variant: "ghost"
    property bool statusDot: false
    property bool pulse: false
    property bool colorIcon: false
    /* A shorter badge for use inside a list row. */
    property bool dense: false

    readonly property color base: root.toneColor(root.tone)
    /* Derived from the theme's small font, which may carry a pixel size only. */
    readonly property font valueFont: { const f = Kirigami.Theme.smallFont; f.weight = Font.DemiBold; return f }
    readonly property bool split: root.label !== ""
    readonly property real pad: Kirigami.Units.smallSpacing * (root.dense ? 1.1 : 1.5)
    readonly property color onSolid: root.base.hslLightness > 0.62 ? "#1b1e20" : "#ffffff"
    readonly property color valueColor: root.variant === "solid" ? root.onSolid : Qt.alpha(Kirigami.Theme.textColor, Style.TEXT.strong)
    /* Icons take an opaque colour (the SVG renderer ignores translucent ones); softness comes from opacity. */
    readonly property color iconColor: root.variant === "solid" ? root.onSolid
        : root.colorIcon ? root.base : Kirigami.Theme.textColor

    /* A tone name or hue to a colour; cheaper than an item per instance. */
    function toneColor(name) {
        switch (name) {
        case "ok": return Kirigami.Theme.positiveTextColor
        case "bad": return Kirigami.Theme.negativeTextColor
        case "warn": return Kirigami.Theme.neutralTextColor
        case "info": return Kirigami.Theme.highlightColor
        case "muted": return Kirigami.Theme.disabledTextColor
        case "text": return Kirigami.Theme.textColor
        default: return Style.HUE[name] !== undefined ? Style.HUE[name] : Kirigami.Theme.textColor
        }
    }

    implicitHeight: Kirigami.Units.gridUnit * (root.dense ? 1.05 : 1.3)
    implicitWidth: line.implicitWidth
    radius: Kirigami.Units.smallSpacing * 1.25
    clip: true
    color: root.variant === "solid" ? root.base
        : root.variant === "secondary" ? Qt.alpha(Kirigami.Theme.textColor, Style.ALPHA.surface3)
        : "transparent"
    border.width: root.variant === "secondary" ? 0 : 1.5
    border.color: root.variant === "solid" ? Qt.darker(root.base, 1.15) : root.base


    RowLayout {
        id: line
        anchors.fill: parent
        spacing: 0

        Rectangle {
            visible: root.split
            Layout.fillHeight: true
            implicitWidth: labelText.implicitWidth + root.pad * 2
            color: Qt.alpha(Kirigami.Theme.textColor, Style.ALPHA.surface3)
            PlasmaComponents.Label {
                id: labelText
                anchors.centerIn: parent
                text: root.label
                font: Kirigami.Theme.smallFont
                color: Qt.alpha(Kirigami.Theme.textColor, Style.TEXT.soft)
            }
        }
        Item {
            Layout.fillHeight: true
            /* A leading dot or icon reads tighter than the text's trailing edge,
               so that side gets a little more room to look even. */
            readonly property real lead: root.statusDot || root.glyph !== "" ? Kirigami.Units.smallSpacing / 2 : 0
            implicitWidth: valueRow.implicitWidth + root.pad * 2 + lead
            RowLayout {
                id: valueRow
                anchors.centerIn: parent
                anchors.horizontalCenterOffset: parent.lead / 2
                spacing: Kirigami.Units.smallSpacing * 0.75
                Rectangle {
                    id: dot
                    visible: root.statusDot
                    implicitWidth: 6
                    implicitHeight: 6
                    radius: 3
                    color: root.base
                    SequentialAnimation on opacity {
                        // A closed popup keeps its items "visible", so also ask the window;
                        // otherwise the pulse keeps the animation timer awake.
                        running: root.pulse && root.statusDot && root.visible
                                 && root.Window.window !== null && root.Window.window.visible
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.3; duration: 900; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1; duration: 900; easing.type: Easing.InOutSine }
                        onStopped: dot.opacity = 1
                    }
                }
                ActionIcon {
                    visible: root.glyph !== ""
                    glyph: root.glyph
                    color: root.iconColor
                    opacity: root.variant === "solid" || root.colorIcon ? 1 : Style.TEXT.normal
                    implicitWidth: Kirigami.Units.iconSizes.small * 0.8
                    implicitHeight: implicitWidth
                }
                PlasmaComponents.Label {
                    text: root.text
                    font: root.valueFont
                    color: root.valueColor
                }
            }
        }
    }
}
