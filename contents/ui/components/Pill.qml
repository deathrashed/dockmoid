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

    readonly property color toneColor: tones.color(root.tone)
    /* Derived from the theme's small font, which may carry a pixel size only. */
    readonly property font valueFont: { const f = Kirigami.Theme.smallFont; f.weight = Font.DemiBold; return f }
    readonly property bool split: root.label !== ""
    readonly property real pad: Kirigami.Units.smallSpacing * (root.dense ? 1.1 : 1.5)
    readonly property color onSolid: root.toneColor.hslLightness > 0.62 ? "#1b1e20" : "#ffffff"
    readonly property color valueColor: root.variant === "solid" ? root.onSolid : Qt.alpha(Kirigami.Theme.textColor, Style.TEXT.strong)
    /* Icons take an opaque colour (the SVG renderer ignores translucent ones); softness comes from opacity. */
    readonly property color iconColor: root.variant === "solid" ? root.onSolid
        : root.colorIcon ? root.toneColor : Kirigami.Theme.textColor

    implicitHeight: Kirigami.Units.gridUnit * (root.dense ? 1.05 : 1.3)
    implicitWidth: line.implicitWidth
    radius: Kirigami.Units.smallSpacing * 1.25
    clip: true
    color: root.variant === "solid" ? root.toneColor
        : root.variant === "secondary" ? Qt.alpha(Kirigami.Theme.textColor, Style.ALPHA.surface3)
        : "transparent"
    border.width: root.variant === "secondary" ? 0 : 1.5
    border.color: root.variant === "solid" ? Qt.darker(root.toneColor, 1.15) : root.toneColor

    Tones { id: tones }

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
            implicitWidth: valueRow.implicitWidth + root.pad * 2
            RowLayout {
                id: valueRow
                anchors.centerIn: parent
                spacing: Kirigami.Units.smallSpacing * 0.75
                Rectangle {
                    id: dot
                    visible: root.statusDot
                    implicitWidth: 6
                    implicitHeight: 6
                    radius: 3
                    color: root.toneColor
                    SequentialAnimation on opacity {
                        running: root.pulse && root.statusDot && root.visible
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.3; duration: 900; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1; duration: 900; easing.type: Easing.InOutSine }
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
