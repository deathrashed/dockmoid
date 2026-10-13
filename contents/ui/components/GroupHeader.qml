import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

/*
 * GroupHeader — the section bar above each compose project.
 *
 * Carries the project name, how much of it is up, and the start / stop /
 * restart trio. Those buttons act on the *whole* project, so they are
 * disabled while a search filter is active: otherwise searching for one
 * service and hitting "stop" would silently take down every container that the
 * filter had hidden.
 */
Item {
    id: root

    required property var backend
    required property string groupKey
    /* Whether a search is narrowing the list right now. */
    property bool filtering: false

    readonly property var members: backend.groupMembers(groupKey)
    readonly property bool isProject: backend.groupIsProject(groupKey)
    readonly property int runningCount: {
        var n = 0
        for (var i = 0; i < root.members.length; i++) {
            if (root.members[i].isRunning) n++
        }
        return n
    }

    implicitHeight: layout.implicitHeight + Kirigami.Units.smallSpacing * 2

    Rectangle {
        anchors.fill: parent
        color: Qt.alpha(Kirigami.Theme.highlightColor, 0.12)
    }

    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: 1
        color: Qt.alpha(Kirigami.Theme.textColor, 0.15)
    }

    RowLayout {
        id: layout
        anchors.fill: parent
        anchors.leftMargin: Kirigami.Units.smallSpacing
        anchors.rightMargin: Kirigami.Units.smallSpacing
        spacing: Kirigami.Units.smallSpacing

        Kirigami.Icon {
            visible: root.isProject
            source: "folder"
            isMask: true
            implicitWidth: Kirigami.Units.iconSizes.small
            implicitHeight: implicitWidth
            color: Kirigami.Theme.colorSet
        }

        PlasmaComponents.Label {
            text: root.groupKey
            font.bold: true
            elide: Text.ElideRight
            Layout.maximumWidth: root.width * 0.4
        }

        PlasmaComponents.Label {
            text: i18np("%1/%2 up", "%1/%2 up", root.runningCount, root.members.length)
            font.pixelSize: Kirigami.Theme.smallFont.pixelSize
            color: root.runningCount === root.members.length && root.members.length > 0
                ? Kirigami.Theme.positiveTextColor
                : Kirigami.Theme.disabledTextColor
        }

        PlasmaComponents.Label {
            text: i18n("group")
            visible: !root.isProject
            font.pixelSize: Kirigami.Theme.smallFont.pixelSize
            color: Kirigami.Theme.disabledTextColor
        }

        Item { Layout.fillWidth: true }

        PlasmaComponents.ToolButton {
            id: groupStart
            display: PlasmaComponents.AbstractButton.IconOnly
            icon.name: "media-playback-start"
            text: i18n("Start all in this group")
            enabled: !root.filtering
            onClicked: root.backend.startGroup(root.groupKey)
            PlasmaComponents.ToolTip { text: groupStart.text }
        }

        PlasmaComponents.ToolButton {
            id: groupRestart
            display: PlasmaComponents.AbstractButton.IconOnly
            icon.name: "view-refresh"
            text: i18n("Restart all in this group")
            enabled: !root.filtering
            onClicked: root.backend.restartGroup(root.groupKey)
            PlasmaComponents.ToolTip { text: groupRestart.text }
        }

        PlasmaComponents.ToolButton {
            id: groupStop
            display: PlasmaComponents.AbstractButton.IconOnly
            icon.name: "media-playback-stop"
            text: i18n("Stop all in this group")
            enabled: !root.filtering
            onClicked: root.backend.stopGroup(root.groupKey)
            PlasmaComponents.ToolTip { text: groupStop.text }
        }
    }
}
