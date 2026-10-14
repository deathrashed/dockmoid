import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import "../../lib/style.js" as Style

/*
 * Card — the one surface the popup uses for grouped content.
 *
 * As a container it takes children and an optional small-caps title. As a
 * background (anchors.fill a delegate) it just draws the surface, so tiles,
 * chips and panels share one radius, outline, hover and selection treatment.
 * `accent` paints a slim state stripe down the left edge.
 */
Rectangle {
    id: root

    property string title: ""
    property string titleGlyph: ""
    /* Tone or hue name for the title icon; see Tones. */
    property string titleTone: "muted"
    property color accent: "transparent"
    /* Alternative to `accent`: a tone name ("ok", "warn", "bad", "info"), "" for none. */
    property string tone: ""
    /* A Tones name or hue: tint the whole surface in that colour. */
    property string washTone: ""
    property bool interactive: false
    property bool hovered: false
    property bool selected: false
    default property alias content: body.data
    property real padding: Kirigami.Units.largeSpacing
    readonly property color stripe: root.tone !== "" ? tones.color(root.tone) : root.accent
    readonly property font titleFont: {
        const f = Kirigami.Theme.smallFont
        f.bold = true
        f.capitalization = Font.AllUppercase
        f.letterSpacing = 0.6
        return f
    }
    readonly property bool hasAccent: root.stripe.a > 0

    radius: Kirigami.Units.smallSpacing * 1.5
    color: root.washTone !== "" ? Qt.alpha(tones.color(root.washTone), root.selected ? Style.WASH.selected : (root.interactive && root.hovered) ? Style.WASH.hover : Style.WASH.rest)
        : root.selected ? Qt.alpha(Kirigami.Theme.highlightColor, Style.ALPHA.tintStrong)
        : (root.interactive && root.hovered) ? Qt.alpha(Kirigami.Theme.textColor, Style.ALPHA.hover)
        : Qt.alpha(Kirigami.Theme.textColor, Style.ALPHA.surface2)
    border.width: 1
    border.color: root.washTone !== "" ? Qt.alpha(tones.color(root.washTone), root.selected ? Style.WASH_BORDER.selected : (root.interactive && root.hovered) ? Style.WASH_BORDER.hover : Style.WASH_BORDER.rest)
        : root.selected ? Qt.alpha(Kirigami.Theme.highlightColor, Style.ALPHA.borderStrong)
        : (root.interactive && root.hovered) ? Qt.alpha(Kirigami.Theme.highlightColor, Style.ALPHA.borderAccent)
        : Qt.alpha(Kirigami.Theme.textColor, Style.ALPHA.borderFaint)

    implicitHeight: column.implicitHeight + root.padding * 2
    implicitWidth: column.implicitWidth + root.padding * 2

    Behavior on color { ColorAnimation { duration: Kirigami.Units.shortDuration } }

    Rectangle {
        visible: root.hasAccent
        anchors { left: parent.left; top: parent.top; bottom: parent.bottom; topMargin: root.radius / 2; bottomMargin: root.radius / 2 }
        width: 3
        radius: 2
        color: root.stripe
    }

    Tones { id: tones }

    ColumnLayout {
        id: column
        anchors.fill: parent
        anchors.margins: root.padding
        anchors.leftMargin: root.padding + (root.hasAccent ? 3 : 0)
        spacing: Kirigami.Units.smallSpacing

        RowLayout {
            visible: root.title !== ""
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing
            ActionIcon {
                visible: root.titleGlyph !== ""
                glyph: root.titleGlyph
                color: tones.color(root.titleTone)
                implicitWidth: Kirigami.Units.iconSizes.small
                implicitHeight: implicitWidth
            }
            PlasmaComponents.Label {
                Layout.fillWidth: true
                text: root.title
                font: root.titleFont
                color: Kirigami.Theme.disabledTextColor
                elide: Text.ElideRight
            }
        }
        ColumnLayout {
            id: body
            Layout.fillWidth: true
            spacing: 0
        }
    }
}
