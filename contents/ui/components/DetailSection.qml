pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

/* A compact disclosure section for optional container details. */
ColumnLayout {
    id: root
    property string title: ""
    property bool expanded: false
    default property alias content: body.data
    spacing: 0

    SectionHeader {
        Layout.fillWidth: true
        Layout.preferredHeight: Kirigami.Units.gridUnit * 1.7
        framed: true
        title: root.title
        expanded: root.expanded
        onToggled: root.expanded = !root.expanded
    }
    ColumnLayout {
        id: body
        Layout.fillWidth: true
        visible: root.expanded
        spacing: 0
    }
}
