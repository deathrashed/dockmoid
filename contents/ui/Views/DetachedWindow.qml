import QtQuick
import QtQuick.Window

import org.kde.kirigami as Kirigami

/*
 * DetachedWindow — the popup, promoted to a real window.
 *
 * It holds nothing of its own: the same PopupView component that the applet
 * popup loads is handed to it, so detaching is a change of parent, never a
 * change of UI. Because main.qml only ever instantiates one of the two, there
 * is no second copy of the list to keep in sync.
 */
Window {
    id: root

    /* Supplied by main.qml. */
    property Component contentComponent
    property string viewTitle: i18n("Dockmoid")

    visible: false
    title: viewTitle
    width: Kirigami.Units.gridUnit * 48
    height: Kirigami.Units.gridUnit * 32
    minimumWidth: Kirigami.Units.gridUnit * 22
    minimumHeight: Kirigami.Units.gridUnit * 14
    color: Kirigami.Theme.backgroundColor

    Loader {
        anchors.fill: parent
        sourceComponent: root.contentComponent
    }
}
