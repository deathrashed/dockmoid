import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import "../../lib/style.js" as Style

/*
 * StatTile — a number with an icon and a label ("8 Running"). Tapping one
 * applies the matching filter; the active tile is drawn as selected.
 */
Card {
    id: root

    property string glyph: "layers"
    property int value: 0
    property string label: ""
    /* "ok", "info", "warn", "bad" or "muted"; see Tones. */
    property string toneName: "muted"
    property bool active: false
    property bool clickable: true
    /* Icon and number only; the label moves to the tooltip. */
    property bool compact: false
    signal clicked()

    padding: root.compact ? Kirigami.Units.smallSpacing : Kirigami.Units.smallSpacing * 1.5
    interactive: root.clickable
    hovered: hover.hovered
    selected: root.active
    implicitWidth: line.implicitWidth + padding * 2
    implicitHeight: line.implicitHeight + padding * 2

    Accessible.role: root.clickable ? Accessible.Button : Accessible.StaticText
    Accessible.name: root.value + " " + root.label

    Tones { id: palette }

    RowLayout {
        id: line
        spacing: Kirigami.Units.smallSpacing
        Rectangle {
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: Kirigami.Units.iconSizes.smallMedium + Kirigami.Units.smallSpacing
            implicitHeight: implicitWidth
            radius: Kirigami.Units.smallSpacing
            color: Qt.alpha(palette.color(root.toneName), Style.ALPHA.tintStrong)
            ActionIcon {
                anchors.centerIn: parent
                glyph: root.glyph
                color: palette.color(root.toneName)
                implicitWidth: Kirigami.Units.iconSizes.small
                implicitHeight: implicitWidth
            }
        }
        ColumnLayout {
            spacing: 0
            PlasmaComponents.Label {
                text: String(root.value)
                font.bold: true
                font.pointSize: Kirigami.Theme.defaultFont.pointSize + 2
                font.features: ({"tnum": 1})
            }
            PlasmaComponents.Label {
                visible: !root.compact
                text: root.label
                font: Kirigami.Theme.smallFont
                color: Kirigami.Theme.disabledTextColor
            }
        }
    }

    PlasmaComponents.ToolTip { visible: hover.hovered && root.compact; text: root.label }
    HoverHandler { id: hover; cursorShape: root.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor }
    TapHandler { enabled: root.clickable; onTapped: root.clicked() }
}
