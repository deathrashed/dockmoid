import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

/*
 * Every command the plasmoid can run.
 *
 * All of them are plain shell fragments, so they honour DOCKER_HOST, contexts,
 * aliases, podman and the user's PATH exactly like a terminal would. That is
 * also why they are editable: the defaults suit a systemd install, but a
 * rootless, remote or podman setup needs different ones.
 */
KCM.SimpleKCM {
    id: page

    property alias cfg_engineCommand: engineCommand.text
    property alias cfg_eventsCommand: eventsCommand.text
    property alias cfg_restartPolicyCommand: policyRead.text
    property alias cfg_setRestartPolicyCommand: policySet.text
    property alias cfg_checkActiveCommand: checkActive.text
    property alias cfg_listCommand: list.text
    property alias cfg_usageCommand: usage.text
    property alias cfg_infoCommand: info.text
    property alias cfg_systemDfCommand: systemDf.text
    property alias cfg_imagesCommand: imagesCmd.text
    property alias cfg_volumesCommand: volumesCmd.text
    property alias cfg_networksCommand: networksCmd.text
    property alias cfg_removeImageCommand: rmImage.text
    property alias cfg_removeVolumeCommand: rmVolume.text
    property alias cfg_removeNetworkCommand: rmNetwork.text
    property alias cfg_composeCommand: composeCmd.text
    property alias cfg_updateCheckCommand: updateCmd.text
    property alias cfg_contextListCommand: contextCmd.text
    property string cfg_checkActiveCommandDefault
    property string cfg_infoCommandDefault

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
        logs, logsFollow, inspect
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

        // ---------------------------------------- engine presets ---------
        Kirigami.FormLayout {
            wideMode: false
            Kirigami.Separator {
                Kirigami.FormData.isSection: true
                Kirigami.FormData.label: i18n("Container engine")
            }

            Controls.ComboBox {
                id: preset
                Kirigami.FormData.label: i18n("Set everything up for: ")
                textRole: "label"
                model: [
                    { "label": i18n("Choose…") },
                    { "label": i18n("Docker (systemd service)"), "engine": "docker",
                      "start": "pkexec systemctl start docker", "stop": "pkexec systemctl stop docker",
                      "socket": "pkexec systemctl stop docker.socket" },
                    { "label": i18n("Docker, rootless"), "engine": "docker",
                      "start": "systemctl --user start docker", "stop": "systemctl --user stop docker",
                      "socket": "true" },
                    { "label": i18n("Podman (experimental)"), "engine": "podman",
                      "start": "systemctl --user start podman.socket", "stop": "systemctl --user stop podman.socket",
                      "socket": "true",
                      "check": "{engine} info --format {{.Version.Version}}", "info": "" },
                    { "label": i18n("Colima"), "engine": "docker",
                      "start": "colima start", "stop": "colima stop", "socket": "true" }
                ]
                onActivated: function (index) {
                    var p = model[index]
                    if (!p.engine) return
                    engineCommand.text = p.engine
                    startService.text = p.start
                    stopService.text = p.stop
                    stopSocket.text = p.socket
                    checkActive.text = p.check !== undefined ? p.check : page.cfg_checkActiveCommandDefault
                    info.text = p.info !== undefined ? p.info : page.cfg_infoCommandDefault
                    currentIndex = 0
                }
            }

            Controls.TextField {
                id: engineCommand
                Kirigami.FormData.label: i18n("Engine command: ")
                placeholderText: "docker"
            }
        }

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            visible: true
            type: Kirigami.MessageType.Information
            text: i18n("Every default command below starts with {engine}, which is replaced by the engine command. Use docker, podman, nerdctl, a full path, or something like “sudo docker”. Picking a preset also fills in how the service is started and stopped; the usual setup for your distribution is the first entry. Podman support is experimental.")
        }

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            type: Kirigami.MessageType.Information
            text: i18n("Commands may contain placeholders that are substituted before the command runs: {engine} the engine command, {id} short container id, {name} container name (quoted), {image} image reference (quoted), {shell} shell binary, {tail} number of log lines, {project} compose project name, {file} compose file path. Subshells such as $(...) work too.")
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
            Controls.TextField {
                id: eventsCommand
                Kirigami.FormData.label: i18n("Look for changes: ")
            }
            Controls.TextField {
                id: policyRead
                Kirigami.FormData.label: i18n("Read autostart settings: ")
            }
            Controls.TextField {
                id: policySet
                Kirigami.FormData.label: i18n("Set autostart policy: ")
            }
        }

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            type: Kirigami.MessageType.Information
            text: i18n("The list and usage commands must emit JSON, one object per line (Docker 23 and newer) or a single array (Podman). “Look for changes” gets {since} and {until} as unix times and must print a line for each relevant event; if it fails, plain interval polling is used instead. The engine summary must emit pipe separated values in the order shown in the field, or nothing at all to skip it.")
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

        // ---------------------------------------- resources & more -------
        Kirigami.FormLayout {
            wideMode: false
            Kirigami.Separator {
                Kirigami.FormData.isSection: true
                Kirigami.FormData.label: i18n("Images, volumes, networks, Compose")
            }
            Controls.TextField { id: imagesCmd; Kirigami.FormData.label: i18n("List images: ") }
            Controls.TextField { id: volumesCmd; Kirigami.FormData.label: i18n("List volumes: ") }
            Controls.TextField { id: networksCmd; Kirigami.FormData.label: i18n("List networks: ") }
            Controls.TextField { id: rmImage; Kirigami.FormData.label: i18n("Remove an image: ") }
            Controls.TextField { id: rmVolume; Kirigami.FormData.label: i18n("Remove a volume: ") }
            Controls.TextField { id: rmNetwork; Kirigami.FormData.label: i18n("Remove a network: ") }
            Controls.TextField { id: composeCmd; Kirigami.FormData.label: i18n("Compose command: ") }
            Controls.TextField { id: updateCmd; Kirigami.FormData.label: i18n("Check an image for updates: ") }
            Controls.TextField { id: contextCmd; Kirigami.FormData.label: i18n("List hosts (contexts): ") }
        }

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            type: Kirigami.MessageType.Information
            text: i18n("Use “docker-compose” as the Compose command if you only have the old standalone tool. The update check must print “local digests|remote digest”; the default needs docker buildx. Hosts are Docker contexts (docker context create …), which is how you point Dockmoid at another machine over SSH.")
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
            text: i18n("Docker started by systemd needs elevated privileges, so the default goes through pkexec and asks for your password. Rootless Docker, Podman and Colima need none; pick them from the presets above.")
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
            text: i18n("The clean-up dialog adds -a (all unused images) and --volumes to this when you tick them. It always asks first.")
        }

        Item {
            Layout.fillHeight: true
        }
    }
}
