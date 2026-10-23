import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.extras as PlasmaExtras
import "../../lib/style.js" as Style

/*
 * PageHeader — the title band every sub-page starts with.
 *
 * Optional `leading` content (an icon tile), a title with `badges` beside it,
 * a quiet subtitle, and `actions` on the right. Pages put their own controls
 * in the default slot, so headers look alike but stay specific. With
 * `stackActions` the actions get a row of their own under the title, so on a
 * narrow page status badges and buttons never share (and overlap on) a line.
 */
Item {
    id: root

    property string title: ""
    property string subtitle: ""
    /* A Tones name or hue: tints the band and, with `glyph`, adds an icon tile. */
    property string tone: ""
    property string glyph: ""
    /* Tighter, for a page shown inside the dock. */
    property bool compact: false
    property bool stackActions: false
    property alias leading: leadingRow.data
    property alias badges: badgeRow.data
    default property alias actions: actionRow.data

    implicitHeight: line.implicitHeight + (root.compact ? Kirigami.Units.smallSpacing : Kirigami.Units.largeSpacing) * 2
    Layout.fillWidth: true

    Tones { id: tones }
    readonly property color band: root.tone !== "" ? tones.color(root.tone) : Kirigami.Theme.textColor

    Rectangle {
        anchors.fill: parent
        color: Qt.alpha(Kirigami.Theme.textColor, Style.ALPHA.surface2)
    }
    Rectangle {
        visible: root.tone !== ""
        anchors.fill: parent
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: Qt.alpha(root.band, Style.BAND.start) }
            GradientStop { position: 0.7; color: Qt.alpha(root.band, Style.BAND.end) }
            GradientStop { position: 1; color: "transparent" }
        }
    }
    Rectangle {
        visible: root.tone !== ""
        anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
        width: 3
        color: root.band
    }
    Rectangle {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 1
        color: Qt.alpha(Kirigami.Theme.textColor, Style.ALPHA.borderFaint)
    }

    GridLayout {
        id: line
        anchors.fill: parent
        anchors.leftMargin: Kirigami.Units.largeSpacing
        anchors.rightMargin: Kirigami.Units.largeSpacing
        anchors.topMargin: root.stackActions ? Kirigami.Units.smallSpacing : 0
        anchors.bottomMargin: root.stackActions ? Kirigami.Units.smallSpacing : 0
        columns: 4
        columnSpacing: Kirigami.Units.largeSpacing
        rowSpacing: Kirigami.Units.smallSpacing

        Rectangle {
            visible: root.glyph !== ""
            Layout.row: 0
            Layout.column: 0
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: Kirigami.Units.iconSizes.medium + Kirigami.Units.smallSpacing * 2
            implicitHeight: implicitWidth
            radius: Kirigami.Units.smallSpacing * 1.5
            color: Qt.alpha(root.band, Style.ALPHA.tintStrong)
            border.color: Qt.alpha(root.band, Style.ALPHA.borderSoft)
            ActionIcon {
                anchors.centerIn: parent
                glyph: root.glyph
                color: root.band
                implicitWidth: Kirigami.Units.iconSizes.smallMedium
                implicitHeight: implicitWidth
            }
        }
        RowLayout {
            id: leadingRow
            visible: children.length > 0
            Layout.row: 0
            Layout.column: 1
            Layout.alignment: Qt.AlignVCenter
        }
        ColumnLayout {
            Layout.row: 0
            Layout.column: 2
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            Layout.alignment: Qt.AlignVCenter
            spacing: 0
            PlasmaExtras.Heading {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                level: root.compact ? 4 : 3
                text: root.title
                elide: Text.ElideRight
            }
            // Flows, so badges wrap under each other on a narrow page instead
            // of running underneath the action buttons; the subtitle follows them.
            Flow {
                id: badgeLine
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                visible: badgeRow.children.length > 0 || root.subtitle !== ""
                spacing: Kirigami.Units.smallSpacing
                Flow {
                    id: badgeRow
                    visible: children.length > 0
                    spacing: Kirigami.Units.smallSpacing
                    /* One line's worth of badges; narrower only when that does not fit. */
                    readonly property real naturalWidth: {
                        let total = 0
                        for (let i = 0; i < children.length; i++)
                            if (children[i].visible) total += children[i].implicitWidth + (total > 0 ? spacing : 0)
                        return total
                    }
                    width: Math.min(naturalWidth, badgeLine.width)
                }
                PlasmaComponents.Label {
                    visible: root.subtitle !== ""
                    width: Math.min(implicitWidth, badgeLine.width)
                    // Centred on a badge's line (Pill is 1.3 grid units tall).
                    height: badgeRow.visible ? Math.max(implicitHeight, Kirigami.Units.gridUnit * 1.3) : implicitHeight
                    verticalAlignment: Text.AlignVCenter
                    text: root.subtitle
                    font: Kirigami.Theme.smallFont
                    color: Kirigami.Theme.disabledTextColor
                    elide: Text.ElideMiddle
                }
            }
        }
        RowLayout {
            id: actionRow
            Layout.row: root.stackActions ? 1 : 0
            Layout.column: root.stackActions ? 0 : 3
            Layout.columnSpan: root.stackActions ? 4 : 1
            Layout.alignment: root.stackActions ? Qt.AlignLeft | Qt.AlignVCenter : Qt.AlignVCenter
            spacing: Kirigami.Units.smallSpacing
        }
    }
}
