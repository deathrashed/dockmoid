import QtQuick
import org.kde.plasma.configuration

/*
 * Configuration categories.
 *
 * The order here is the order of the pages in the settings dialog: the things
 * most people change first, then the reference material.
 */
ConfigModel {
    ConfigCategory {
        name: i18nc("@title", "General")
        icon: "configure"
        source: "config/configGeneral.qml"
    }
    ConfigCategory {
        name: i18nc("@title", "Appearance")
        icon: "preferences-desktop-theme"
        source: "config/configDisplay.qml"
    }
    ConfigCategory {
        name: i18nc("@title", "Storage")
        icon: "drive-harddisk"
        source: "config/configStorage.qml"
    }
    ConfigCategory {
        name: i18nc("@title", "Monitoring")
        icon: "utilities-system-monitor"
        source: "config/configMonitoring.qml"
    }
    ConfigCategory {
        name: i18nc("@title", "Connections")
        icon: "network-server"
        source: "config/configNetwork.qml"
    }
    ConfigCategory {
        name: i18nc("@title", "Advanced")
        icon: "utilities-terminal"
        source: "config/configCommand.qml"
    }
}
