import QtQuick
import QtQuick.Window
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

import "../components" as Components

// Plain QML Window inherits plasmashell's native icon and has no per-window
// QIcon setter. A client title bar keeps branding local to this window and
// works without a binary plugin or compositor-specific window rules.
Window {
    id: root

    property Component contentComponent
    property string viewTitle: i18n("Dockmoid")
    readonly property bool maximized: visibility === Window.Maximized

    visible: false
    title: viewTitle
    flags: Qt.Window | Qt.FramelessWindowHint
    width: Kirigami.Units.gridUnit * 48
    height: Kirigami.Units.gridUnit * 32
    minimumWidth: Kirigami.Units.gridUnit * 22
    minimumHeight: Kirigami.Units.gridUnit * 14
    color: Kirigami.Theme.backgroundColor

    function bringForward() {
        if (root.visibility === Window.Minimized) root.showNormal()
        root.raise()
        root.requestActivate()
    }

    function toggleMaximized() {
        if (root.maximized) root.showNormal()
        else root.showMaximized()
    }

    Rectangle {
        id: titleBar
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: Math.max(32, Kirigami.Units.iconSizes.smallMedium + Kirigami.Units.smallSpacing * 2)
        color: Kirigami.Theme.alternateBackgroundColor

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
            onPressed: root.startSystemMove()
            onDoubleClicked: root.toggleMaximized()
        }
        Image {
            anchors.left: parent.left
            anchors.leftMargin: Kirigami.Units.smallSpacing * 2
            anchors.verticalCenter: parent.verticalCenter
            width: Kirigami.Units.iconSizes.smallMedium
            height: width
            source: "../../icons/dockmoid.png"
            // Decode at the screen's real pixel size (HiDPI included) and
            // filter the downscale, so the 1024 px artwork stays smooth.
            sourceSize: Qt.size(width * 2 * Screen.devicePixelRatio, height * 2 * Screen.devicePixelRatio)
            fillMode: Image.PreserveAspectFit
            smooth: true
            mipmap: true
        }
        PlasmaComponents.Label {
            anchors.centerIn: parent
            width: Math.max(0, parent.width - windowControls.width * 2 - Kirigami.Units.largeSpacing)
            horizontalAlignment: Text.AlignHCenter
            text: root.viewTitle
            elide: Text.ElideRight
        }
        RowLayout {
            id: windowControls
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0
            Components.ActionToolButton {
                glyph: "chevron-down"
                text: i18n("Minimize window")
                onClicked: root.showMinimized()
            }
            Components.ActionToolButton {
                glyph: root.maximized ? "window-restore" : "window-maximize"
                text: root.maximized ? i18n("Restore window") : i18n("Maximize window")
                onClicked: root.toggleMaximized()
            }
            Components.ActionToolButton {
                glyph: "edit-clear"
                text: i18n("Close window")
                onClicked: root.close()
            }
        }
    }

    Loader {
        anchors.top: titleBar.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        sourceComponent: root.contentComponent
    }

    // Let the window system handle resize grabs, including Wayland constraints.
    Repeater {
        model: [Qt.TopEdge, Qt.BottomEdge, Qt.LeftEdge, Qt.RightEdge,
            Qt.TopEdge | Qt.LeftEdge, Qt.TopEdge | Qt.RightEdge,
            Qt.BottomEdge | Qt.LeftEdge, Qt.BottomEdge | Qt.RightEdge]
        delegate: MouseArea {
            required property int modelData
            readonly property bool leftEdge: (modelData & Qt.LeftEdge) !== 0
            readonly property bool rightEdge: (modelData & Qt.RightEdge) !== 0
            readonly property bool topEdge: (modelData & Qt.TopEdge) !== 0
            readonly property bool bottomEdge: (modelData & Qt.BottomEdge) !== 0
            readonly property bool corner: (leftEdge || rightEdge) && (topEdge || bottomEdge)
            readonly property real grip: 5
            visible: !root.maximized
            x: rightEdge ? root.width - grip : (leftEdge ? 0 : grip)
            y: bottomEdge ? root.height - grip : (topEdge ? 0 : grip)
            width: leftEdge || rightEdge ? grip : root.width - grip * 2
            height: topEdge || bottomEdge ? grip : root.height - grip * 2
            cursorShape: corner ? (leftEdge === topEdge ? Qt.SizeFDiagCursor : Qt.SizeBDiagCursor)
                : (leftEdge || rightEdge ? Qt.SizeHorCursor : Qt.SizeVerCursor)
            onPressed: root.startSystemResize(modelData)
        }
    }
}
