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
    /* A titled card can fold away its body; the title row becomes the toggle. */
    property bool collapsible: false
    property bool expanded: true
    /* Small text at the right of the title row, e.g. a count or a summary. */
    property string titleHint: ""
    /* A section heading in full-size text over a tinted band, rather than the
       quiet small-caps label used inside tiles. */
    property bool prominentTitle: false
    default property alias content: body.data
    property real padding: Kirigami.Units.largeSpacing
    readonly property color stripe: root.tone !== "" ? root.toneColor(root.tone) : root.accent
    readonly property font titleFont: {
        const f = Kirigami.Theme.smallFont
        f.bold = true
        f.capitalization = Font.AllUppercase
        f.letterSpacing = 0.6
        return f
    }
    readonly property bool hasAccent: root.stripe.a > 0
    readonly property font headingFont: {
        const f = Kirigami.Theme.defaultFont
        f.bold = true
        return f
    }

    radius: Kirigami.Units.smallSpacing * 1.5
    color: root.washTone !== "" ? Qt.alpha(root.toneColor(root.washTone), root.selected ? Style.WASH.selected : (root.interactive && root.hovered) ? Style.WASH.hover : Style.WASH.rest)
        : root.selected ? Qt.alpha(Kirigami.Theme.highlightColor, Style.WASH.selected)
        : (root.interactive && root.hovered) ? Qt.alpha(Kirigami.Theme.textColor, Style.ALPHA.hover)
        : Qt.alpha(Kirigami.Theme.textColor, Style.ALPHA.surface2)
    border.width: 1
    border.color: root.washTone !== "" ? Qt.alpha(root.toneColor(root.washTone), root.selected ? Style.WASH_BORDER.selected : (root.interactive && root.hovered) ? Style.WASH_BORDER.hover : Style.WASH_BORDER.rest)
        : root.selected ? Qt.alpha(Kirigami.Theme.highlightColor, Style.ALPHA.borderStrong)
        : (root.interactive && root.hovered) ? Qt.alpha(Kirigami.Theme.highlightColor, Style.ALPHA.borderAccent)
        : Qt.alpha(Kirigami.Theme.textColor, Style.ALPHA.borderFaint)

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


    /* The band and coloured rule behind a prominent title. */
    Rectangle {
        visible: root.prominentTitle && root.title !== ""
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 1 }
        height: titleRow.height + root.padding + (root.expanded || !root.collapsible ? Kirigami.Units.smallSpacing : root.padding - 1)
        topLeftRadius: root.radius - 1
        topRightRadius: root.radius - 1
        bottomLeftRadius: root.expanded || !root.collapsible ? 0 : root.radius - 1
        bottomRightRadius: bottomLeftRadius
        // One neutral band for every section; the colour is in the icon and the rule.
        color: Qt.alpha(Kirigami.Theme.textColor, Style.ALPHA.surface2)
        Rectangle {
            visible: root.expanded || !root.collapsible
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: 1.5
            color: Qt.alpha(root.toneColor(root.titleTone), Style.WASH_BORDER.hover)
        }
    }

    ColumnLayout {
        id: column
        anchors.fill: parent
        anchors.margins: root.padding
        anchors.leftMargin: root.padding + (root.hasAccent ? 3 : 0)
        spacing: Kirigami.Units.smallSpacing

        RowLayout {
            id: titleRow
            visible: root.title !== ""
            Layout.fillWidth: true
            Layout.bottomMargin: root.prominentTitle && (root.expanded || !root.collapsible) ? Kirigami.Units.smallSpacing : 0
            spacing: Kirigami.Units.smallSpacing
            TapHandler {
                enabled: root.collapsible
                onTapped: root.expanded = !root.expanded
            }
            HoverHandler {
                enabled: root.collapsible
                cursorShape: Qt.PointingHandCursor
            }
            ActionIcon {
                visible: root.titleGlyph !== ""
                glyph: root.titleGlyph
                color: root.toneColor(root.titleTone)
                implicitWidth: root.prominentTitle ? Kirigami.Units.iconSizes.smallMedium : Kirigami.Units.iconSizes.small
                implicitHeight: implicitWidth
            }
            PlasmaComponents.Label {
                Layout.fillWidth: true
                text: root.title
                font: root.prominentTitle ? root.headingFont : root.titleFont
                color: root.prominentTitle ? Kirigami.Theme.textColor : Kirigami.Theme.disabledTextColor
                elide: Text.ElideRight
            }
            PlasmaComponents.Label {
                visible: root.titleHint !== "" && (!root.expanded || !root.collapsible)
                text: root.titleHint
                font: Kirigami.Theme.smallFont
                color: Kirigami.Theme.disabledTextColor
                elide: Text.ElideRight
                Layout.maximumWidth: column.width / 2
            }
            ActionIcon {
                visible: root.collapsible
                glyph: root.expanded ? "chevron-down" : "go-next"
                color: Kirigami.Theme.disabledTextColor
                implicitWidth: Kirigami.Units.iconSizes.small
                implicitHeight: implicitWidth
            }
        }
        ColumnLayout {
            id: body
            visible: !root.collapsible || root.expanded
            Layout.fillWidth: true
            spacing: 0
        }
        // A card stretched taller than its content (side by side in a grid)
        // keeps the content under its title instead of centring it.
        Item { Layout.fillHeight: true; visible: !root.collapsible || root.expanded }
    }
}
