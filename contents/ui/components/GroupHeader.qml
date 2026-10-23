import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import "../../lib/actionIcons.js" as ActionIcons
import "../../lib/style.js" as Style

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

    component ComposeMenuItem: PlasmaComponents.MenuItem {
        property string glyph: ""
        icon.name: ""
        icon.source: glyph !== "" ? Qt.resolvedUrl(ActionIcons.path(glyph)) : ""
        icon.color: Kirigami.Theme.textColor
        icon.width: Kirigami.Units.iconSizes.smallMedium
        icon.height: Kirigami.Units.iconSizes.smallMedium
    }

    required property var backend
    required property string groupKey
    /* Whether a search is narrowing the list right now. */
    property bool filtering: false

    readonly property var members: backend.groupMembers(groupKey)
    readonly property bool isProject: backend.groupIsProject(groupKey)
    readonly property int runningCount: {
        var n = 0
        for (let i = 0; i < root.members.length; i++) {
            if (root.members[i].isRunning) n++
        }
        return n
    }

    /* Compose-wide actions are carried out by the view that owns the dialogs
       and the output page; the header only says which one was asked for. */
    signal composeRequested(string verb)

    implicitHeight: layout.implicitHeight + Kirigami.Units.smallSpacing * 2

    Rectangle {
        anchors.fill: parent
        color: Qt.alpha(Kirigami.Theme.highlightColor, Style.ALPHA.tintStrong)
    }

    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: 1
        color: Qt.alpha(Kirigami.Theme.textColor, Style.ALPHA.borderFaint)
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
            font: Kirigami.Theme.smallFont
            color: root.runningCount === root.members.length && root.members.length > 0
                ? Kirigami.Theme.positiveTextColor
                : Kirigami.Theme.disabledTextColor
        }

        PlasmaComponents.Label {
            text: i18n("group")
            visible: !root.isProject
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.disabledTextColor
        }

        Item { Layout.fillWidth: true }

        ActionToolButton {
            id: groupStart
            glyph: "media-playback-start"
            text: i18n("Start All in Group")
            enabled: !root.backend.readOnly && !root.filtering
            onClicked: root.backend.startGroup(root.groupKey)
        }

        ActionToolButton {
            id: groupRestart
            glyph: "view-refresh"
            text: i18n("Restart All in Group")
            enabled: !root.backend.readOnly && !root.filtering
            onClicked: root.backend.restartGroup(root.groupKey)
        }

        ActionToolButton {
            id: groupMore
            visible: root.isProject
            glyph: "application-menu"
            text: i18n("More Compose actions")
            enabled: !root.backend.readOnly && !root.filtering
            onClicked: groupMenu.popup(groupMore, 0, groupMore.height)

            PlasmaComponents.Menu {
                id: groupMenu
                ComposeMenuItem { glyph: "media-playback-start"; text: i18n("Up (Create and Start)"); onTriggered: root.composeRequested("up") }
                ComposeMenuItem { glyph: "system-download"; text: i18n("Pull Images"); onTriggered: root.composeRequested("pull") }
                ComposeMenuItem { glyph: "package-upgrade"; text: i18n("Pull and Recreate"); onTriggered: root.composeRequested("update") }
                ComposeMenuItem { glyph: "view-refresh"; text: i18n("Force Recreate"); onTriggered: root.composeRequested("recreate") }
                PlasmaComponents.MenuSeparator {}
                ComposeMenuItem { glyph: "edit-delete"; text: i18n("Down (Remove Containers)"); onTriggered: root.composeRequested("down") }
            }
        }

        ActionToolButton {
            id: groupStop
            glyph: "media-playback-stop"
            text: i18n("Stop All in Group")
            enabled: !root.backend.readOnly && !root.filtering
            onClicked: root.backend.stopGroup(root.groupKey)
        }
    }
}
