import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts

import org.kde.kirigami as Kirigami

/*
 * General settings: how often we ask Docker anything, and what we do about it.
 */
Kirigami.ScrollablePage {
    id: page

    property alias cfg_fetchOnStartup: fetchOnStartup.checked
    property alias cfg_refreshOnExpand: refreshOnExpand.checked
    property alias cfg_statsWhenCollapsed: statsWhenCollapsed.checked
    property alias cfg_updateInterval: updateInterval.value
    property alias cfg_usageInterval: usageInterval.value
    property alias cfg_useNotifications: useNotifications.checked
    property alias cfg_notifyOnEngineChange: notifyOnEngineChange.checked
    property alias cfg_confirmDestructive: confirmDestructive.checked
    property alias cfg_showDiskUsage: showDiskUsage.checked
    property alias cfg_debugCommands: debugCommands.checked

    ColumnLayout {
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
        }
        spacing: Kirigami.Units.smallSpacing

        // ------------------------------------------- polling ------------
        Kirigami.FormLayout {
            wideMode: false
            Kirigami.Separator {
                Kirigami.FormData.isSection: true
                Kirigami.FormData.label: i18n("Refreshing")
            }
        }

        Kirigami.FormLayout {
            Controls.CheckBox {
                id: fetchOnStartup
                Kirigami.FormData.label: i18n("Check Docker on startup: ")
            }

            Controls.CheckBox {
                id: refreshOnExpand
                Kirigami.FormData.label: i18n("Refresh as soon as the view is opened: ")
            }

            Controls.SpinBox {
                id: updateInterval
                Kirigami.FormData.label: i18n("Update the container list every: ")
                from: 2
                to: 3600
                stepSize: 1
                editable: true
                textFromValue: function (value) { return i18np("%1 second", "%1 seconds", value) }
                valueFromText: function (text) { return parseInt(text) }
            }
        }

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            visible: updateInterval.value < 10
            type: updateInterval.value < 5
                ? Kirigami.MessageType.Error
                : Kirigami.MessageType.Warning
            text: i18n("Polling every %1 seconds runs a docker command constantly. This costs a little CPU and, on a laptop, battery. Values under 10 seconds are rarely useful.", updateInterval.value)
        }

        Kirigami.FormLayout {
            Controls.CheckBox {
                id: statsWhenCollapsed
                Kirigami.FormData.label: i18n("Keep CPU and memory live while collapsed: ")
            }

            Controls.SpinBox {
                id: usageInterval
                Kirigami.FormData.label: i18n("Update usage every: ")
                from: 1
                to: 3600
                stepSize: 1
                editable: true
                textFromValue: function (value) { return i18np("%1 second", "%1 seconds", value) }
                valueFromText: function (text) { return parseInt(text) }
            }
        }

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            type: Kirigami.MessageType.Information
            text: i18n("While the view is closed, only the container list is refreshed. CPU and memory come from a command that samples usage over a couple of seconds, so it is skipped until you actually open the view — unless the option above is turned on.")
        }

        // --------------------------------------- notifications ---------
        Kirigami.FormLayout {
            wideMode: false
            Kirigami.Separator {
                Kirigami.FormData.isSection: true
                Kirigami.FormData.label: i18n("Notifications")
            }
        }

        Kirigami.FormLayout {
            Controls.CheckBox {
                id: useNotifications
                Kirigami.FormData.label: i18n("Notify when a container action finishes: ")
            }

            Controls.CheckBox {
                id: notifyOnEngineChange
                Kirigami.FormData.label: i18n("Notify when Docker starts or stops: ")
                enabled: useNotifications.checked
            }
        }

        // ------------------------------------------ safety --------------
        Kirigami.FormLayout {
            wideMode: false
            Kirigami.Separator {
                Kirigami.FormData.isSection: true
                Kirigami.FormData.label: i18n("Safety")
            }
        }

        Kirigami.FormLayout {
            Controls.CheckBox {
                id: confirmDestructive
                Kirigami.FormData.label: i18n("Ask before removing a container: ")
            }

            Controls.CheckBox {
                id: showDiskUsage
                Kirigami.FormData.label: i18n("Show disk usage in the status bar: ")
            }
        }

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            type: Kirigami.MessageType.Information
            text: i18n("Stopping the Docker service and pruning unused data always ask for confirmation, regardless of the setting above. Disk usage runs a slower command, so it is only collected when the view is open.")
        }

        // ------------------------------------------ debug ---------------
        Kirigami.FormLayout {
            wideMode: false
            Kirigami.Separator {
                Kirigami.FormData.isSection: true
                Kirigami.FormData.label: i18n("Troubleshooting")
            }
        }

        Kirigami.FormLayout {
            Controls.CheckBox {
                id: debugCommands
                Kirigami.FormData.label: i18n("Log every command to the system log: ")
            }
        }

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            type: Kirigami.MessageType.Information
            text: i18n("Turn this on and read the output with: journalctl --user -f | grep runner")
        }

        Item {
            Layout.fillHeight: true
        }
    }
}
