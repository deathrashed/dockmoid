import QtQuick
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami

Controls.TabButton {
    id: control
    implicitHeight: Kirigami.Units.gridUnit * 2
    leftPadding: Kirigami.Units.largeSpacing
    rightPadding: Kirigami.Units.largeSpacing
    topPadding: Kirigami.Units.smallSpacing
    bottomPadding: Kirigami.Units.smallSpacing
    contentItem: Controls.Label {
        text: control.text
        font.family: control.font.family
        font.pointSize: control.font.pointSize
        font.bold: control.checked
        color: Kirigami.Theme.textColor
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }
    background: Rectangle {
        radius: Kirigami.Units.smallSpacing
        color: control.checked ? Qt.alpha(Qt.darker(Kirigami.Theme.highlightColor, 1.7), 0.2)
            : control.hovered ? Qt.darker(Kirigami.Theme.backgroundColor, 1.12)
            : Qt.darker(Kirigami.Theme.backgroundColor, 1.12)
        border.width: 1
        border.color: control.checked ? Qt.alpha(Qt.lighter(Kirigami.Theme.highlightColor, 1.7), 0.82)
            : Qt.alpha(Qt.lighter(Kirigami.Theme.backgroundColor, 1.7), 0.22)
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: control.checked ? 2 : 0
            radius: height / 2
            color: Kirigami.Theme.highlightColor
        }
    }
}
