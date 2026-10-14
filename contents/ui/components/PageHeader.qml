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
 * in the default slot, so headers look alike but stay specific.
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

    RowLayout {
        id: line
        anchors.fill: parent
        anchors.leftMargin: Kirigami.Units.largeSpacing
        anchors.rightMargin: Kirigami.Units.largeSpacing
        spacing: Kirigami.Units.largeSpacing

        Rectangle {
            visible: root.glyph !== ""
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
            Layout.alignment: Qt.AlignVCenter
        }
        ColumnLayout {
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
            RowLayout {
                Layout.fillWidth: true
                visible: badgeRow.children.length > 0 || root.subtitle !== ""
                spacing: Kirigami.Units.smallSpacing
                RowLayout { id: badgeRow; spacing: Kirigami.Units.smallSpacing }
                PlasmaComponents.Label {
                    visible: root.subtitle !== ""
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    text: root.subtitle
                    font: Kirigami.Theme.smallFont
                    color: Kirigami.Theme.disabledTextColor
                    elide: Text.ElideMiddle
                }
            }
        }
        RowLayout {
            id: actionRow
            Layout.alignment: Qt.AlignVCenter
            spacing: Kirigami.Units.smallSpacing
        }
    }
}
