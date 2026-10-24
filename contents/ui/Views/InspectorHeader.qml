import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

import "../components" as Components

/* The selected container's name above an inspector page, with page-specific buttons.
   On a narrow inspector the buttons drop their labels (tooltips keep them). */
RowLayout {
    id: root
    required property var backend
    required property var record
    default property alias actions: buttons.data
    readonly property bool narrow: width < Kirigami.Units.gridUnit * 24
    function applyNarrow() {
        for (let i = 0; i < buttons.children.length; i++) {
            const child = buttons.children[i] as Components.DockButton
            if (child) child.iconOnly = root.narrow
        }
    }
    onNarrowChanged: applyNarrow()
    Component.onCompleted: applyNarrow()
    Layout.margins: Kirigami.Units.smallSpacing
    spacing: Kirigami.Units.smallSpacing
    Components.ServiceIcon {
        backend: root.backend
        record: root.record || ({})
        iconSize: Kirigami.Units.iconSizes.small
    }
    PlasmaComponents.Label {
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        text: root.record ? root.record.name : ""
        font.bold: true
        elide: Text.ElideRight
    }
    RowLayout { id: buttons; spacing: Kirigami.Units.smallSpacing }
}
