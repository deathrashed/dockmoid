import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

import "../components" as Components
import "../../lib/style.js" as Style

/* What an inspector page says while nothing is selected. */
ColumnLayout {
    id: root
    property string text: ""
    spacing: Kirigami.Units.smallSpacing
    Item { Layout.fillHeight: true }
    Components.ActionIcon {
        Layout.alignment: Qt.AlignHCenter
        glyph: "mouse-pointer-click"
        color: Style.HUE.sky
        implicitWidth: Kirigami.Units.iconSizes.medium
        implicitHeight: implicitWidth
    }
    PlasmaComponents.Label {
        Layout.fillWidth: true
        Layout.leftMargin: Kirigami.Units.gridUnit
        Layout.rightMargin: Kirigami.Units.gridUnit
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        text: root.text
        color: Kirigami.Theme.disabledTextColor
    }
    Item { Layout.fillHeight: true }
}
