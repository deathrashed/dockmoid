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
        icon: "preferences-system-time"
        source: "config/configGeneral.qml"
    }
    ConfigCategory {
        name: i18nc("@title", "Display")
        icon: "video-display"
        source: "config/configDisplay.qml"
    }
    ConfigCategory {
        name: i18nc("@title", "Network")
        icon: "network-wired-activated"
        source: "config/configNetwork.qml"
    }
    ConfigCategory {
        name: i18nc("@title", "Integration")
        icon: "utilities-terminal"
        source: "config/configIntegration.qml"
    }
    ConfigCategory {
        name: i18nc("@title", "Services")
        icon: "view-list-tree"
        source: "config/configServices.qml"
    }
    ConfigCategory {
        name: i18nc("@title", "Commands")
        icon: "applications-development"
        source: "config/configCommand.qml"
    }
}
