import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import "../../lib/style.js" as Style

/*
 * Pill — a small badge in the style of shadcn / shieldcn badges.
 *
 *   variant  "ghost"      tinted wash with a hairline outline (default)
 *            "outline"    outline only
 *            "solid"      filled with the tone colour
 *            "secondary"  neutral wash, coloured text
 *   label    when set, the badge is two-tone: a quiet label segment and the
 *            value segment ("health | healthy")
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
    /* A shorter badge for use inside a list row. */
    property bool dense: false

    readonly property color toneColor: tones.color(root.tone)
    /* Derived from the theme's small font, which may carry a pixel size only. */
    readonly property font valueFont: { const f = Kirigami.Theme.smallFont; f.weight = Font.DemiBold; return f }
    readonly property bool split: root.label !== ""
    readonly property real pad: Kirigami.Units.smallSpacing * (root.dense ? 1.1 : 1.5)
    readonly property color onSolid: root.toneColor.hslLightness > 0.62 ? "#1b1e20" : "#ffffff"
    readonly property color valueColor: root.variant === "solid" ? root.onSolid : root.toneColor

    implicitHeight: Kirigami.Units.gridUnit * (root.dense ? 1.05 : 1.3)
    implicitWidth: line.implicitWidth
    radius: Kirigami.Units.smallSpacing * 1.25
    clip: true
    color: root.variant === "solid" ? root.toneColor
        : root.variant === "ghost" ? Qt.alpha(root.toneColor, Style.ALPHA.tintStrong)
        : root.variant === "secondary" ? Qt.alpha(Kirigami.Theme.textColor, Style.ALPHA.surface3)
        : "transparent"
    border.width: 1
    border.color: root.variant === "solid" ? Qt.darker(root.toneColor, 1.2)
        : root.variant === "outline" ? Qt.alpha(root.toneColor, Style.ALPHA.borderStrong)
        : Qt.alpha(root.toneColor, Style.ALPHA.borderSoft)

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
                color: Kirigami.Theme.disabledTextColor
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
                    color: root.valueColor
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
                    color: root.valueColor
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
