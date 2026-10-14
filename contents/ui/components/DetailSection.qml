pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

/* A compact disclosure section for optional container details. */
ColumnLayout {
    id: root
    property string title: ""
    property bool expanded: false
    default property alias content: body.data
    spacing: 0

    PlasmaComponents.ToolButton {
        id: header
        Layout.fillWidth: true
        Layout.preferredHeight: Kirigami.Units.gridUnit * 1.7
        text: root.title
        icon.name: root.expanded ? "arrow-down" : "arrow-right"
        display: PlasmaComponents.AbstractButton.TextBesideIcon
        checked: root.expanded
        onClicked: root.expanded = !root.expanded
        background: Rectangle {
            radius: Kirigami.Units.smallSpacing
            color: header.checked ? Qt.alpha(Kirigami.Theme.highlightColor, 0.12)
                                  : Qt.alpha(Kirigami.Theme.textColor, 0.045)
            border.color: Qt.alpha(Kirigami.Theme.textColor, 0.12)
        }
    }
    ColumnLayout {
        id: body
        Layout.fillWidth: true
        visible: root.expanded
        spacing: 0
    }
}
