import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

/*
 * Network: turning published ports into links that actually work.
 */
KCM.SimpleKCM {
    id: page

    property alias cfg_terminalCommand: terminalCommand.text
    property alias cfg_editorCommand: editorCommand.text
    property alias cfg_launchers: launchers.value
    property alias cfg_logTailLines: logTailLines.value

    property string cfg_launchersDefault
    property string cfg_terminalCommandDefault
    property string cfg_editorCommandDefault
    property int cfg_logTailLinesDefault
    property bool cfg_enableBrowserLinksDefault
    property bool cfg_autoDetectHostsDefault
    property string cfg_lanHostDefault
    property string cfg_tailscaleHostDefault
    property bool cfg_allowLanLinksDefault
    property bool cfg_allowTailscaleLinksDefault
    property string cfg_httpsPortsDefault


    property alias cfg_enableBrowserLinks: enableBrowserLinks.checked
    property alias cfg_autoDetectHosts: autoDetect.checked
    property alias cfg_lanHost: lanHost.text
    property alias cfg_tailscaleHost: tailscaleHost.text
    property alias cfg_allowLanLinks: allowLan.checked
    property alias cfg_allowTailscaleLinks: allowTailscale.checked
    property alias cfg_httpsPorts: httpsPorts.text

    Kirigami.FormLayout {
            Layout.fillWidth: true
        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Open in browser")
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Links:")
            Controls.CheckBox {
                id: enableBrowserLinks

                text: i18n("offer them for published ports")
            }
            QuestionHelp { helpText: i18n("Only TCP ports are offered; a UDP port cannot be opened in a browser.") }
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Addresses:")
            Controls.CheckBox {
                id: autoDetect
                enabled: enableBrowserLinks.checked

                text: i18n("find them automatically")
            }
            QuestionHelp { helpText: i18n("Fills in empty address fields using your default route and Tailscale connection. Ports published on every interface get LAN and Tailscale links. Ports bound to 127.0.0.1 get localhost links. Ports bound to one specific address use that address.") }
        }

        Controls.TextField {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
            id: lanHost
            enabled: enableBrowserLinks.checked
            Kirigami.FormData.label: i18n("LAN address:")
            placeholderText: i18n("automatic")
        }
        Controls.CheckBox {
            id: allowLan
            enabled: enableBrowserLinks.checked
            text: i18n("offer it")
        }

        Controls.TextField {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
            id: tailscaleHost
            enabled: enableBrowserLinks.checked
            Kirigami.FormData.label: i18n("Tailscale address:")
            placeholderText: i18n("automatic")
        }
        RowLayout {
            Controls.CheckBox {
                id: allowTailscale
                enabled: enableBrowserLinks.checked
                text: i18n("offer it")
            }
            QuestionHelp { helpText: i18n("A name works as well as an address, for example nas.local or a MagicDNS name.") }
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Open with https:")
            Controls.TextField {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                id: httpsPorts
                enabled: enableBrowserLinks.checked

                placeholderText: "443, 8443, 9443"
            }
            QuestionHelp { helpText: i18n("Comma separated host ports that speak https.") }
        }

        Controls.Button { text: i18n("Restore page defaults"); icon.name: "edit-undo"; onClicked: { page.cfg_enableBrowserLinks = page.cfg_enableBrowserLinksDefault; page.cfg_autoDetectHosts = page.cfg_autoDetectHostsDefault; page.cfg_lanHost = page.cfg_lanHostDefault; page.cfg_tailscaleHost = page.cfg_tailscaleHostDefault; page.cfg_allowLanLinks = page.cfg_allowLanLinksDefault; page.cfg_allowTailscaleLinks = page.cfg_allowTailscaleLinksDefault; page.cfg_httpsPorts = page.cfg_httpsPortsDefault } }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Terminal, editor and launchers")
        }
        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Terminal")
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Command:")
            Controls.TextField {
                id: terminalCommand

                placeholderText: i18n("automatic")
            }
            QuestionHelp { helpText: i18n("Leave empty to use the first terminal found (Konsole, GNOME Terminal, Kitty, Alacritty, Foot, WezTerm, Ghostty, XFCE Terminal, xterm). {command} is replaced with the docker command; without it the command is simply appended. Example: kitty -e {command}") }
        }

        Controls.SpinBox {
            id: logTailLines
            Kirigami.FormData.label: i18n("Log lines to load:")
            from: 50; to: 10000; stepSize: 50; editable: true
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Editor")
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Command:")
            Controls.TextField {
                id: editorCommand

                placeholderText: i18n("automatic")
            }
            QuestionHelp { helpText: i18n("Used by “Edit Compose File”. Leave empty to use Kate, gedit, VS Code or the system default, whichever exists. {file} is the compose file and {dir} its folder.") }
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("“Open in” menu")
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Launchers:")
            StructuredRulesEditor {
                id: launchers
                title: i18n("Open-in launchers")
                kind: "launcher"
                delimiter: "|"
                headers: [i18n("Label"), i18n("Icon name"), i18n("Scope"), i18n("Command")]
                example: i18n("No launchers configured.")
                // Command is the long column; the others share what is left.
                columnWeights: [2, 2, 1.5, 5]

                Layout.fillWidth: true
                Layout.preferredWidth: Math.max(Kirigami.Units.gridUnit * 24, Math.min(Kirigami.Units.gridUnit * 40, page.width - Kirigami.Units.gridUnit * 14))
                Layout.minimumWidth: 0
            }
            QuestionHelp { helpText: i18n("Scope “container” needs a running container and fills in {id} and {shell}; scope “project” needs a Compose folder and fills in {dir}. Launchers whose program is not installed are hidden automatically. Comments and malformed lines remain in the advanced text view.") }
        }

        Controls.Button {
            text: i18n("Restore the default launchers")
            icon.name: "edit-undo"
            onClicked: page.cfg_launchers = page.cfg_launchersDefault
        }
        Controls.Button { text: i18n("Restore page defaults"); icon.name: "edit-undo"; onClicked: { page.cfg_terminalCommand = page.cfg_terminalCommandDefault; page.cfg_editorCommand = page.cfg_editorCommandDefault; page.cfg_launchers = page.cfg_launchersDefault; page.cfg_logTailLines = page.cfg_logTailLinesDefault } }


    }
}
