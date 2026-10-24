import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

/*
 * DetachedPlaceholder — what the applet popup shows while the real UI lives in
 * its own window.
 *
 * Keeping a small live card here (rather than an empty box) means the panel
 * popup is still a useful status readout while detached.
 *
 * `applet` is the PlasmoidItem, handed in by main.qml: QML ids do not cross
 * file boundaries, so this is the only way to reach setDetached().
 */
Item {
    id: root

    required property var backend
    required property var applet

    implicitHeight: content.implicitHeight + Kirigami.Units.largeSpacing * 2

    ColumnLayout {
        id: content
        anchors.centerIn: parent
        width: parent.width - Kirigami.Units.largeSpacing * 2
        spacing: Kirigami.Units.smallSpacing

        PlasmaComponents.Label {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: i18n("The view is open in its own window")
            font.bold: true
            elide: Text.ElideRight
        }

        PlasmaComponents.Label {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: root.backend.engineActive
                ? i18np("%1 of %2 containers running", "%1 of %2 containers running",
                        root.backend.running, root.backend.total)
                : i18n("%1 is not running", root.backend.engineName)
            color: root.backend.engineActive
                ? Kirigami.Theme.textColor
                : Kirigami.Theme.negativeTextColor
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: Kirigami.Units.smallSpacing

            PlasmaComponents.Button {
                icon.name: "view-refresh"
                text: i18n("Refresh")
                onClicked: root.backend.refresh({ "force": true, "withStats": true })
            }

            PlasmaComponents.Button {
                icon.name: "window-restore"
                text: i18n("Reattach")
                onClicked: root.applet.setDetached(false)
            }
        }
    }
}
