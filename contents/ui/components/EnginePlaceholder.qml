import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.kquickcontrolsaddons as KQuickControlsAddons
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.plasmoid
import "../../lib/recovery.js" as Recovery

/*
 * EnginePlaceholder — what to show instead of an empty list when the engine
 * cannot be reached: which host, why, and the fixes that fit that connection.
 * A remote host or rootless engine never gets a Start button or docker-group
 * advice it cannot use (lib/recovery.js decides which apply).
 */
Item {
    id: root

    required property var backend

    readonly property var plan: Recovery.plan({
        problem: root.backend.engineProblem,
        podman: root.backend.isPodman,
        remote: root.backend.remoteEngine,
        rootless: /^unix:\/\/\/run\/user\//.test(root.backend.endpointHost),
        canControlService: root.backend.canControlService
    })
    readonly property string host: root.backend.endpointHost !== "" ? root.backend.endpointHost
        : root.backend.contextName !== "" ? root.backend.contextName : i18n("this computer")

    readonly property var words: ({
        "docker-missing": [i18n("Docker was not found"), i18n("%1 is not installed, or is not on the PATH Plasma sees. Install it, or set the engine command in Settings → Advanced.", root.backend.engineBase)],
        "podman-missing": [i18n("Podman was not found"), i18n("%1 is not installed, or is not on the PATH Plasma sees. Install it, or set the engine command in Settings → Advanced.", root.backend.engineBase)],
        "remote-down": [i18n("%1 does not answer", root.host), i18n("The remote engine did not respond. Check that the host is up, that SSH or TCP access works from a terminal as this user, and that the engine runs there. Dockmoid cannot start a remote engine.")],
        "remote-denied": [i18n("%1 refused the connection", root.host), i18n("The remote host did not accept this user. Check the SSH key or user configured for this connection; nothing on this computer needs to change.")],
        "podman-down": [i18n("Podman does not answer"), i18n("Podman's API socket for your user is not running. Start it (no root needed), then retry:")],
        "podman-denied": [i18n("Podman refused the request"), i18n("Your user cannot reach Podman's socket. Rootless Podman needs no group membership; check that the socket belongs to you, or start it:")],
        "rootless-down": [i18n("Rootless Docker does not answer"), i18n("The per-user Docker daemon is not running. Start it (no root needed), then retry:")],
        "rootless-denied": [i18n("Rootless Docker refused the request"), i18n("The per-user socket did not accept this user. Check that it belongs to you, or start the daemon again:")],
        "docker-denied": [i18n("You are not allowed to use Docker"), i18n("Your user cannot talk to the Docker socket. Membership of the docker group grants root-equivalent access; if you accept that, add yourself, then log out and back in:")],
        "docker-down": [i18n("Docker is not running"), root.backend.canControlService
            ? i18n("The daemon did not answer. Start it, or switch to another host in Settings → Connections.")
            : i18n("The daemon did not answer. Start it with your system's service manager, or switch to another host in Settings → Connections.")]
    })
    readonly property var text: root.words[root.plan.cause] || [i18n("The engine does not answer"), ""]

    ColumnLayout {
        anchors.centerIn: parent
        width: parent.width - Kirigami.Units.gridUnit * 2
        spacing: Kirigami.Units.largeSpacing

        Kirigami.PlaceholderMessage {
            Layout.fillWidth: true
            icon.name: root.backend.engineProblem === "missing" ? "dialog-question"
                     : root.backend.engineProblem === "permission" ? "dialog-password" : "network-disconnect"
            text: root.text[0]
            explanation: root.text[1]
        }
        // The command, selectable and copyable, rather than buried in the explanation.
        PlasmaComponents.TextField {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: Math.min(parent.width, Kirigami.Units.gridUnit * 18)
            visible: root.plan.command !== ""
            readOnly: true
            text: root.plan.command
            font: Kirigami.Theme.fixedWidthFont
        }
        Flow {
            Layout.alignment: Qt.AlignHCenter
            Layout.maximumWidth: parent.width
            spacing: Kirigami.Units.smallSpacing
            Repeater {
                model: root.plan.actions
                delegate: DockButton {
                    required property string modelData
                    required property int index
                    variant: index === 0 ? "primary" : "default"
                    glyph: modelData === "install" ? "external-link" : modelData === "copy" ? "edit-copy"
                        : modelData === "start" ? "media-playback-start" : modelData === "retry" ? "view-refresh" : "settings"
                    text: modelData === "install" ? i18n("Install Guide") : modelData === "copy" ? i18n("Copy Command")
                        : modelData === "start" ? i18n("Start %1", root.backend.engineName) : modelData === "retry" ? i18n("Try Again")
                        : i18n("Connection Settings")
                    onClicked: {
                        switch (modelData) {
                        case "install": Qt.openUrlExternally(root.backend.isPodman ? "https://podman.io/docs/installation" : "https://docs.docker.com/engine/install/"); break
                        case "copy": clipboard.content = root.plan.command; break
                        case "start": root.backend.startEngine(); break
                        case "retry": root.backend.refresh({force: true}); break
                        default: { const action = Plasmoid.internalAction("configure"); if (action) action.trigger() }
                        }
                    }
                }
            }
        }
        PlasmaComponents.Label {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.disabledTextColor
            text: i18n("Host: %1", root.host) + (root.backend.lastError !== "" ? "\n" + root.backend.lastError.split("\n")[0] : "")
        }
    }

    KQuickControlsAddons.Clipboard {
        id: clipboard
    }
}
