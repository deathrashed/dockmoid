import QtQuick
import QtQuick.Window

// Let the compositor resize the attached popup rather than manually moving it.
Item {
    id: root
    property var popupWindow: Window.window
    property int grip: 5
    Repeater {
        model: [Qt.TopEdge, Qt.RightEdge, Qt.BottomEdge, Qt.LeftEdge]
        delegate: MouseArea {
            required property int modelData
            readonly property bool horizontal: modelData === Qt.TopEdge || modelData === Qt.BottomEdge
            x: modelData === Qt.RightEdge ? root.width - root.grip : 0
            y: modelData === Qt.BottomEdge ? root.height - root.grip : 0
            width: horizontal ? root.width : root.grip
            height: horizontal ? root.grip : root.height
            cursorShape: horizontal ? Qt.SizeVerCursor : Qt.SizeHorCursor
            acceptedButtons: Qt.LeftButton
            onPressed: function(mouse) {
                if (root.popupWindow) mouse.accepted = root.popupWindow.startSystemResize(modelData)
                else mouse.accepted = false
            }
        }
    }
}
