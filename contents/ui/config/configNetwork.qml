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

    property alias cfg_enableBrowserLinks: enableBrowserLinks.checked
    property alias cfg_autoDetectHosts: autoDetect.checked
    property alias cfg_lanHost: lanHost.text
    property alias cfg_tailscaleHost: tailscaleHost.text
    property alias cfg_allowLanLinks: allowLan.checked
    property alias cfg_allowTailscaleLinks: allowTailscale.checked
    property alias cfg_httpsPorts: httpsPorts.text

    Kirigami.FormLayout {
        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Open in browser")
        }

        Controls.CheckBox {
            id: enableBrowserLinks
            Kirigami.FormData.label: i18n("Links:")
            text: i18n("offer them for published ports")
        }
        Hint { text: i18n("Only TCP ports are offered; a UDP port cannot be opened in a browser.") }

        Controls.CheckBox {
            id: autoDetect
            enabled: enableBrowserLinks.checked
            Kirigami.FormData.label: i18n("Addresses:")
            text: i18n("find them automatically")
        }
        Hint { text: i18n("Fills in whichever fields below are left empty: the LAN address from your default route, and the Tailscale address if tailscale is installed and connected.") }

        Controls.TextField {
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
            id: tailscaleHost
            enabled: enableBrowserLinks.checked
            Kirigami.FormData.label: i18n("Tailscale address:")
            placeholderText: i18n("automatic")
        }
        Controls.CheckBox {
            id: allowTailscale
            enabled: enableBrowserLinks.checked
            text: i18n("offer it")
        }
        Hint { text: i18n("A name works as well as an address, for example nas.local or a MagicDNS name.") }

        Controls.TextField {
            id: httpsPorts
            enabled: enableBrowserLinks.checked
            Kirigami.FormData.label: i18n("Open with https:")
            placeholderText: "443, 8443, 9443"
        }
        Hint { text: i18n("Comma separated host ports that speak https.") }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Which address a port gets")
        }
        Hint {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 30
            text: i18n("A port published on every interface gets the LAN and Tailscale links. A port bound to 127.0.0.1 only gets a localhost link, since a LAN link to it would just fail. A port bound to one specific address uses that address.")
        }
    }
}
