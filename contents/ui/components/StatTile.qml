import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

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

    padding: Kirigami.Units.smallSpacing
    interactive: root.clickable
    hovered: hover.hovered
    selected: root.active
    washTone: root.toneName
    implicitHeight: Kirigami.Units.gridUnit * 1.7
    implicitWidth: line.implicitWidth + padding * 2
    scale: root.clickable && hover.hovered ? 1.03 : 1
    Behavior on scale { NumberAnimation { duration: Kirigami.Units.shortDuration; easing.type: Easing.OutQuad } }

    Accessible.role: root.clickable ? Accessible.Button : Accessible.StaticText
    Accessible.name: root.value + " " + root.label

    Tones { id: palette }

    RowLayout {
        id: line
        anchors.centerIn: parent
        spacing: Kirigami.Units.smallSpacing
        ActionIcon {
            Layout.alignment: Qt.AlignVCenter
            glyph: root.glyph
            color: palette.color(root.toneName)
            implicitWidth: Kirigami.Units.iconSizes.small
            implicitHeight: implicitWidth
        }
        PlasmaComponents.Label {
            text: String(root.value)
            font.bold: true
            font.features: ({"tnum": 1})
        }
        PlasmaComponents.Label {
            visible: !root.compact
            text: root.label
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.disabledTextColor
        }
    }

    PlasmaComponents.ToolTip { visible: hover.hovered && root.compact; text: root.label }
    HoverHandler { id: hover; cursorShape: root.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor }
    TapHandler { enabled: root.clickable; onTapped: root.clicked() }
}
