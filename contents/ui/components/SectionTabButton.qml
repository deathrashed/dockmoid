import QtQuick
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import "../../lib/style.js" as Style

/* A tab: a quiet outlined surface, a wash on hover, and an accent wash and underline when current. */
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
    // Every tab keeps a quiet outline, so the unselected ones still read as
    // tabs; the current one adds the accent wash and underline.
    background: Rectangle {
        radius: Kirigami.Units.smallSpacing
        color: control.checked ? Qt.alpha(Kirigami.Theme.highlightColor, Style.ALPHA.tintFaint)
            : control.hovered ? Qt.alpha(Kirigami.Theme.textColor, Style.ALPHA.hover)
            : Qt.alpha(Kirigami.Theme.textColor, Style.ALPHA.surface2)
        border.width: 1
        border.color: control.checked ? Qt.alpha(Kirigami.Theme.highlightColor, Style.ALPHA.borderAccent)
            : Qt.alpha(Kirigami.Theme.textColor, Style.ALPHA.borderFaint)
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
