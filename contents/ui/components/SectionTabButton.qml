import QtQuick
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import "../../lib/style.js" as Style

/* A flat tab: quiet text, a soft wash on hover and an accent underline when current. */
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
        color: control.checked ? Kirigami.Theme.textColor : Qt.alpha(Kirigami.Theme.textColor, 0.72)
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }
    background: Rectangle {
        radius: Kirigami.Units.smallSpacing
        color: control.checked ? Qt.alpha(Kirigami.Theme.highlightColor, Style.ALPHA.tintFaint)
            : control.hovered ? Qt.alpha(Kirigami.Theme.textColor, Style.ALPHA.surface2)
            : "transparent"
        Rectangle {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: Kirigami.Units.smallSpacing; rightMargin: Kirigami.Units.smallSpacing }
            height: 2
            radius: 1
            color: Kirigami.Theme.highlightColor
            opacity: control.checked ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Kirigami.Units.shortDuration } }
        }
    }
}
