import QtQuick

import org.kde.kirigami as Kirigami
import org.kde.kquickcontrolsaddons as KQuickControlsAddons
import org.kde.plasma.components as PlasmaComponents

/*
 * EnginePlaceholder — what to show instead of an empty list when Docker cannot
 * be reached, saying why and what to do about it. The three cases look the
 * same from outside ("nothing happens") but have unrelated fixes.
 */
Item {
    id: root

    required property var backend

    readonly property string problem: root.backend.engineProblem
    readonly property string fixCommand: "sudo usermod -aG docker $USER"

    Kirigami.PlaceholderMessage {
        anchors.centerIn: parent
        width: parent.width - Kirigami.Units.gridUnit * 2
        icon.name: root.problem === "missing" ? "dialog-question"
                 : (root.problem === "permission" ? "dialog-password" : "docker")
        text: root.problem === "missing" ? i18n("The container command was not found")
            : (root.problem === "permission" ? i18n("You are not allowed to use Docker")
               : i18n("Docker is not running"))
        explanation: root.problem === "missing"
            ? i18n("%1 is not installed, or is not on the PATH Plasma sees. Install it, or set the engine command under Configure → Advanced → Connection.", root.backend.engineBase)
            : (root.problem === "permission"
               ? i18n("Your user cannot talk to the Docker socket. Add yourself to the docker group, then log out and back in:")
               : i18n("The daemon did not answer. Start it, or switch to another host from the ⋯ menu."))

        helpfulAction: Kirigami.Action {
            icon.name: root.problem === "missing" ? "internet-services"
                     : (root.problem === "permission" ? "edit-copy" : "media-playback-start")
            text: root.problem === "missing" ? i18n("Open the install guide")
                : (root.problem === "permission" ? i18n("Copy the command") : i18n("Start Docker"))
            onTriggered: {
                if (root.problem === "missing") Qt.openUrlExternally("https://docs.docker.com/engine/install/")
                else if (root.problem === "permission") clipboard.content = root.fixCommand
                else root.backend.startEngine()
            }
        }
    }

    PlasmaComponents.Label {
        visible: root.problem === "permission"
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.5 + Kirigami.Units.gridUnit * 5
        font.family: "monospace"
        text: root.fixCommand
        opacity: 0.8
    }

    KQuickControlsAddons.Clipboard {
        id: clipboard
    }
}
