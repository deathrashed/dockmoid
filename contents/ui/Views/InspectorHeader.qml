import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

import "../components" as Components

/* The selected container's name above an inspector page, with page-specific buttons. */
RowLayout {
    id: root
    required property var backend
    required property var record
    default property alias actions: buttons.data
    Layout.margins: Kirigami.Units.smallSpacing
    spacing: Kirigami.Units.smallSpacing
    Components.ServiceIcon {
        backend: root.backend
        record: root.record || ({})
        iconSize: Kirigami.Units.iconSizes.small
    }
    PlasmaComponents.Label {
        Layout.fillWidth: true
        text: root.record ? root.record.name : ""
        font.bold: true
        elide: Text.ElideRight
    }
    RowLayout { id: buttons; spacing: Kirigami.Units.smallSpacing }
}
