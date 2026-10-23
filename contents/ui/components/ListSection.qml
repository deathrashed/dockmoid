import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import "../../lib/style.js" as Style

/*
 * ListSection — the heading above a run of containers that share a state.
 * Clicking it folds the run away; the count stays visible either way.
 */
Item {
    id: root
    /* "pinned", "attention", "running", "stopped" or "not-created". */
    property string group: ""
    property int count: 0
    property bool collapsed: false
    signal toggled()

    readonly property var looks: ({
        "pinned": {label: i18n("Pinned"), glyph: "pin", tone: "info"},
        "attention": {label: i18n("Needs Attention"), glyph: "circle-alert", tone: "yellow"},
        "running": {label: i18n("Running"), glyph: "circle-play", tone: "ok"},
        "stopped": {label: i18n("Stopped"), glyph: "circle-stop", tone: "rose"},
        "not-created": {label: i18n("Pending Deployment"), glyph: "circle-plus", tone: "blue",
                        hint: i18n("Defined in a Compose file, no container yet")}
    })
    readonly property var look: root.looks[root.group] || ({label: root.group, glyph: "layers", tone: "muted"})
    readonly property color toneColor: tones.color(root.look.tone)
    readonly property font headingFont: {
        const f = Kirigami.Theme.smallFont
        f.bold = true
        f.capitalization = Font.AllUppercase
        f.letterSpacing = 0.8
        return f
    }

    implicitHeight: Kirigami.Units.gridUnit * 1.9

    Tones { id: tones }

    Rectangle {
        anchors.fill: parent
        anchors.topMargin: Kirigami.Units.smallSpacing / 2
        anchors.leftMargin: Kirigami.Units.smallSpacing
        anchors.rightMargin: Kirigami.Units.smallSpacing
        radius: Kirigami.Units.smallSpacing
        color: hover.hovered ? Qt.alpha(root.toneColor, Style.WASH.hover) : "transparent"
    }

    HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: root.toggled() }

    Accessible.role: Accessible.Button
    Accessible.name: root.look.label + " " + root.count
    PlasmaComponents.ToolTip.text: (root.look.hint ? root.look.hint + "\n" : "") + (root.collapsed ? i18n("Click to show") : i18n("Click to hide"))
    PlasmaComponents.ToolTip.visible: hover.hovered
    PlasmaComponents.ToolTip.delay: Kirigami.Units.toolTipDelay

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Kirigami.Units.largeSpacing
        anchors.rightMargin: Kirigami.Units.largeSpacing
        anchors.topMargin: Kirigami.Units.smallSpacing / 2
        spacing: Kirigami.Units.smallSpacing
        ActionIcon {
            glyph: root.collapsed ? "go-next" : "chevron-down"
            color: Kirigami.Theme.disabledTextColor
            implicitWidth: Kirigami.Units.iconSizes.small * 0.85
            implicitHeight: implicitWidth
        }
        ActionIcon {
            glyph: root.look.glyph
            color: root.toneColor
            implicitWidth: Kirigami.Units.iconSizes.small
            implicitHeight: implicitWidth
        }
        PlasmaComponents.Label {
            text: root.look.label
            font: root.headingFont
            opacity: Style.TEXT.soft
        }
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            Layout.leftMargin: Kirigami.Units.smallSpacing
            Layout.rightMargin: Kirigami.Units.smallSpacing
            color: Qt.alpha(Kirigami.Theme.textColor, Style.ALPHA.borderFaint)
        }
        // The count closes the line at the right edge, in the section's colour.
        Rectangle {
            visible: root.count > 0
            implicitWidth: Math.max(implicitHeight, countLabel.implicitWidth + Kirigami.Units.smallSpacing * 2)
            implicitHeight: countLabel.implicitHeight + 2
            radius: implicitHeight / 2
            color: Qt.alpha(root.toneColor, Style.ALPHA.tintStrong)
            border.color: Qt.alpha(root.toneColor, Style.WASH_BORDER.rest)
            PlasmaComponents.Label {
                id: countLabel
                anchors.centerIn: parent
                text: String(root.count)
                font: Kirigami.Theme.smallFont
                color: Kirigami.Theme.textColor
            }
        }
    }
}
