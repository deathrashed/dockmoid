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
    property color accent: "transparent"
    /* Alternative to `accent`: a tone name ("ok", "warn", "bad", "info"), "" for none. */
    property string tone: ""
    property bool interactive: false
    property bool hovered: false
    property bool selected: false
    default property alias content: body.data
    property real padding: Kirigami.Units.largeSpacing
    readonly property color stripe: root.tone !== "" ? tones.color(root.tone) : root.accent
    readonly property bool hasAccent: root.stripe.a > 0

    radius: Kirigami.Units.smallSpacing * 1.5
    color: root.selected ? Qt.alpha(Kirigami.Theme.highlightColor, Style.ALPHA.tintStrong)
        : (root.interactive && root.hovered) ? Qt.alpha(Kirigami.Theme.textColor, Style.ALPHA.hover)
        : Qt.alpha(Kirigami.Theme.textColor, Style.ALPHA.surface2)
    border.width: 1
    border.color: root.selected ? Qt.alpha(Kirigami.Theme.highlightColor, Style.ALPHA.borderStrong)
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

        PlasmaComponents.Label {
            visible: root.title !== ""
            Layout.fillWidth: true
            text: root.title
            font.pointSize: Kirigami.Theme.smallFont.pointSize
            font.bold: true
            font.capitalization: Font.AllUppercase
            font.letterSpacing: 0.6
            color: Kirigami.Theme.disabledTextColor
            elide: Text.ElideRight
        }
        ColumnLayout {
            id: body
            Layout.fillWidth: true
            spacing: 0
        }
    }
}
