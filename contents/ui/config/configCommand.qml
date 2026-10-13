import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts

import org.kde.kirigami as Kirigami

/*
 * Every command the plasmoid can run.
 *
 * All of them are plain shell fragments, so they honour DOCKER_HOST, contexts,
 * aliases, podman and the user's PATH exactly like a terminal would. That is
 * also why they are editable: the defaults suit a systemd install, but a
 * rootless, remote or podman setup needs different ones.
 */
Kirigami.ScrollablePage {
    id: page

    property alias cfg_checkActiveCommand: checkActive.text
    property alias cfg_listCommand: list.text
    property alias cfg_usageCommand: usage.text
    property alias cfg_infoCommand: info.text
    property alias cfg_systemDfCommand: systemDf.text

    property alias cfg_startOneCommand: startOne.text
    property alias cfg_stopOneCommand: stopOne.text
    property alias cfg_restartOneCommand: restartOne.text
    property alias cfg_killOneCommand: killOne.text
    property alias cfg_pauseOneCommand: pauseOne.text
    property alias cfg_unpauseOneCommand: unpauseOne.text
    property alias cfg_removeOneCommand: removeOne.text
    property alias cfg_renameOneCommand: renameOne.text
    property alias cfg_pullImageCommand: pullImage.text

    property alias cfg_logsCommand: logs.text
    property alias cfg_logsFollowCommand: logsFollow.text
    property alias cfg_shellCommand: shell.text
    property alias cfg_inspectCommand: inspect.text

    property alias cfg_groupStartCommand: groupStart.text
    property alias cfg_groupStopCommand: groupStop.text
    property alias cfg_groupRestartCommand: groupRestart.text

    property alias cfg_startCommand: startService.text
    property alias cfg_stopServiceCommand: stopService.text
    property alias cfg_stopSocketCommand: stopSocket.text
    property alias cfg_pruneCommand: prune.text

    readonly property var readFields: [
        checkActive, list, usage, info, systemDf
    ]
    readonly property var controlFields: [
        startOne, stopOne, restartOne, killOne, pauseOne, unpauseOne,
        removeOne, renameOne, pullImage
    ]
    readonly property var diagnosticFields: [
        logs, logsFollow, shell, inspect
    ]
    readonly property var groupFields: [
        groupStart, groupStop, groupRestart
    ]
    readonly property var engineFields: [
        startService, stopService, stopSocket, prune
    ]

    ColumnLayout {
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
        }
        spacing: Kirigami.Units.smallSpacing

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            type: Kirigami.MessageType.Information
            text: i18n("Commands may contain placeholders that are substituted before the command runs: {id} short container id, {name} new name, {image} image reference, {shell} shell binary, {tail} number of log lines, {project} compose project name, {file} compose file path. Subshells such as $(...) work too.")
        }

        // ------------------------------------------ reads --------------
        Kirigami.FormLayout {
            wideMode: false
            Kirigami.Separator {
                Kirigami.FormData.isSection: true
                Kirigami.FormData.label: i18n("Reading")
            }
        }

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            type: Kirigami.MessageType.Information
            text: i18n("Docker is considered running when the check command exits with status 0. The default asks the daemon directly, so it also works for rootless Docker, remote contexts and podman. A command that prints 'inactive' or 'failed' is treated as down even on a zero exit.")
        }

        Kirigami.FormLayout {
            wideMode: false
            Controls.TextField {
                id: checkActive
                Kirigami.FormData.label: i18n("Is Docker running: ")
            }
            Controls.TextField {
                id: list
                Kirigami.FormData.label: i18n("List containers: ")
            }
            Controls.TextField {
                id: usage
                Kirigami.FormData.label: i18n("Container usage: ")
            }
            Controls.TextField {
                id: info
                Kirigami.FormData.label: i18n("Engine summary: ")
            }
            Controls.TextField {
                id: systemDf
                Kirigami.FormData.label: i18n("Disk usage: ")
            }
        }

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            type: Kirigami.MessageType.Information
            text: i18n("The list and usage commands must emit one JSON object per line; that is what Docker 23 and newer produce with --format json. The engine summary must emit pipe separated values in the order shown in the field.")
        }

        // --------------------------------------- container ------------
        Kirigami.FormLayout {
            wideMode: false
            Kirigami.Separator {
                Kirigami.FormData.isSection: true
                Kirigami.FormData.label: i18n("Container actions")
            }
        }

        Kirigami.FormLayout {
            wideMode: false
            Controls.TextField {
                id: startOne
                Kirigami.FormData.label: i18n("Start: ")
            }
            Controls.TextField {
                id: stopOne
                Kirigami.FormData.label: i18n("Stop: ")
            }
            Controls.TextField {
                id: restartOne
                Kirigami.FormData.label: i18n("Restart: ")
            }
            Controls.TextField {
                id: killOne
                Kirigami.FormData.label: i18n("Kill: ")
            }
            Controls.TextField {
                id: pauseOne
                Kirigami.FormData.label: i18n("Pause: ")
            }
            Controls.TextField {
                id: unpauseOne
                Kirigami.FormData.label: i18n("Unpause: ")
            }
            Controls.TextField {
                id: removeOne
                Kirigami.FormData.label: i18n("Remove: ")
            }
            Controls.TextField {
                id: renameOne
                Kirigami.FormData.label: i18n("Rename: ")
            }
            Controls.TextField {
                id: pullImage
                Kirigami.FormData.label: i18n("Pull image: ")
            }
        }

        // -------------------------------------- diagnostics ------------
        Kirigami.FormLayout {
            wideMode: false
            Kirigami.Separator {
                Kirigami.FormData.isSection: true
                Kirigami.FormData.label: i18n("Logs, shell and inspection")
            }
        }

        Kirigami.FormLayout {
            wideMode: false
            Controls.TextField {
                id: logs
                Kirigami.FormData.label: i18n("Read logs: ")
            }
            Controls.TextField {
                id: logsFollow
                Kirigami.FormData.label: i18n("Follow logs: ")
            }
            Controls.TextField {
                id: shell
                Kirigami.FormData.label: i18n("Open a shell: ")
            }
            Controls.TextField {
                id: inspect
                Kirigami.FormData.label: i18n("Inspect: ")
            }
        }

        // ------------------------------------------- groups -------------
        Kirigami.FormLayout {
            wideMode: false
            Kirigami.Separator {
                Kirigami.FormData.isSection: true
                Kirigami.FormData.label: i18n("Compose project actions")
            }
        }

        Kirigami.FormLayout {
            wideMode: false
            Controls.TextField {
                id: groupStart
                Kirigami.FormData.label: i18n("Start a project: ")
            }
            Controls.TextField {
                id: groupStop
                Kirigami.FormData.label: i18n("Stop a project: ")
            }
            Controls.TextField {
                id: groupRestart
                Kirigami.FormData.label: i18n("Restart a project: ")
            }
        }

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            type: Kirigami.MessageType.Information
            text: i18n("These act on every container carrying a compose project label, using the docker CLI rather than the compose plugin, so they work even where the plugin is not installed. They are disabled while a search is filtering the list, to avoid acting on containers you cannot see.")
        }

        // ------------------------------------------- engine -------------
        Kirigami.FormLayout {
            wideMode: false
            Kirigami.Separator {
                Kirigami.FormData.isSection: true
                Kirigami.FormData.label: i18n("Docker service")
            }
        }

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            type: Kirigami.MessageType.Warning
            text: i18n("These need elevated privileges, so the defaults go through pkexec and will prompt for your password. If your setup does not use systemd, replace them with whatever starts and stops your engine — or point them at a rootless engine, where no privilege is needed at all.")
        }

        Kirigami.FormLayout {
            wideMode: false
            Controls.TextField {
                id: startService
                Kirigami.FormData.label: i18n("Start the service: ")
            }
            Controls.TextField {
                id: stopService
                Kirigami.FormData.label: i18n("Stop the service: ")
            }
            Controls.TextField {
                id: stopSocket
                Kirigami.FormData.label: i18n("Stop the socket: ")
            }
            Controls.TextField {
                id: prune
                Kirigami.FormData.label: i18n("Prune: ")
            }
        }

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            type: Kirigami.MessageType.Warning
            text: i18n("Prune deletes stopped containers, unused images, build cache and unused volumes. It is destructive and cannot be undone, so it always asks first.")
        }

        Item {
            Layout.fillHeight: true
        }
    }
}
