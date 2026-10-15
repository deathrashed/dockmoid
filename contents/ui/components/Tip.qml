import QtQuick
import org.kde.plasma.components as PlasmaComponents

/*
 * Tip — a tooltip that costs almost nothing until the pointer rests on its
 * parent. A PlasmaComponents.ToolTip builds a popup, frame and animations up
 * front; a list with a dozen rows and ten tips each paid for that on every row.
 * Put one inside the item it describes.
 */
Item {
    id: root
    property string text: ""
    property int delay: 500
    /* Hold the tip back, e.g. while a menu from the same item is open. */
    property bool suppressed: false
    property bool armed: false

    anchors.fill: parent

    HoverHandler {
        id: hover
        onHoveredChanged: if (!hovered) root.armed = false
    }
    Timer {
        interval: root.delay
        running: hover.hovered && root.text !== "" && !root.suppressed
        onTriggered: root.armed = true
    }
    Loader {
        active: root.armed && root.text !== "" && !root.suppressed
        sourceComponent: PlasmaComponents.ToolTip { visible: true; text: root.text }
    }
}
