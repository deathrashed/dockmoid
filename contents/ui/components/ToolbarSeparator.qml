import QtQuick
import org.kde.kirigami as Kirigami
Item {
    implicitWidth: Kirigami.Units.smallSpacing * 2 + 1
    implicitHeight: Kirigami.Units.gridUnit * 1.6
    Rectangle {
        anchors.centerIn: parent
        width: 1
        height: parent.height * 0.65
        color: Kirigami.Theme.textColor
        opacity: 0.22
    }
}
