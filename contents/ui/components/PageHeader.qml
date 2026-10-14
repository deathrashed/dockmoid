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
    /* Tighter, for a page shown inside the dock. */
    property bool compact: false
    property alias leading: leadingRow.data
    property alias badges: badgeRow.data
    default property alias actions: actionRow.data

    implicitHeight: line.implicitHeight + (root.compact ? Kirigami.Units.smallSpacing : Kirigami.Units.largeSpacing) * 2
    Layout.fillWidth: true

    Rectangle {
        anchors.fill: parent
        color: Qt.alpha(Kirigami.Theme.textColor, Style.ALPHA.surface1)
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
