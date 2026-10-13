import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts

import org.kde.kirigami as Kirigami

/*
 * Network settings: turning published ports into links that actually work.
 */
Kirigami.ScrollablePage {
    id: page

    property alias cfg_enableBrowserLinks: enableBrowserLinks.checked
    property alias cfg_lanHost: lanHost.text
    property alias cfg_tailscaleHost: tailscaleHost.text
    property alias cfg_allowLanLinks: allowLan.checked
    property alias cfg_allowTailscaleLinks: allowTailscale.checked
    property alias cfg_httpsPorts: httpsPorts.text

    ColumnLayout {
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
        }
        spacing: Kirigami.Units.smallSpacing

        Kirigami.FormLayout {
            wideMode: false
            Kirigami.Separator {
                Kirigami.FormData.isSection: true
                Kirigami.FormData.label: i18n("Open in browser")
            }
        }

        Kirigami.FormLayout {
            Controls.CheckBox {
                id: enableBrowserLinks
                Kirigami.FormData.label: i18n("Offer links for published ports: ")
            }

            Controls.TextField {
                id: lanHost
                Kirigami.FormData.label: i18n("LAN address of this host: ")
                enabled: enableBrowserLinks.checked
                placeholderText: "192.168.1.10"
            }

            Controls.TextField {
                id: tailscaleHost
                Kirigami.FormData.label: i18n("Tailscale address of this host: ")
                enabled: enableBrowserLinks.checked
                placeholderText: "100.64.0.1"
            }

            Controls.CheckBox {
                id: allowLan
                Kirigami.FormData.label: i18n("Offer the LAN address: ")
                enabled: enableBrowserLinks.checked
            }

            Controls.CheckBox {
                id: allowTailscale
                Kirigami.FormData.label: i18n("Offer the Tailscale address: ")
                enabled: enableBrowserLinks.checked
            }

            Controls.TextField {
                id: httpsPorts
                Kirigami.FormData.label: i18n("Treat these ports as https: ")
                enabled: enableBrowserLinks.checked
                placeholderText: "443, 8443, 3000"
            }
        }

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            type: Kirigami.MessageType.Information
            text: i18n("A port published on every interface is reachable on this machine, on the LAN and over Tailscale, so all three are offered. A port bound to 127.0.0.1 is only reachable from this machine, so only a localhost link is offered — a LAN link to a loopback-bound service would just fail.")
        }

        Kirigami.FormLayout {
            wideMode: false
            Kirigami.Separator {
                Kirigami.FormData.isSection: true
                Kirigami.FormData.label: i18n("Ports without a known address")
            }
        }

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            type: Kirigami.MessageType.Information
            text: i18n("A container published on a specific address is offered using that address, and a port published on an address you have not listed here is still offered as-is.")
        }

        Item {
            Layout.fillHeight: true
        }
    }
}
