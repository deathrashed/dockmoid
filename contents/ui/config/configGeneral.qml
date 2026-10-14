import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

/*
 * General: how often Docker is asked anything, and what happens at startup.
 *
 * Refreshing is tiered so the widget stays detailed without being expensive: a
 * cheap "did anything change?" query runs often, the container list is re-read
 * only when something did (or on the slower heartbeat), and CPU/memory — which
 * need a sampling window — only while somebody is looking.
 */
KCM.SimpleKCM {
    id: page

    property alias cfg_fetchOnStartup: fetchOnStartup.checked
    property alias cfg_refreshOnExpand: refreshOnExpand.checked
    property alias cfg_statsWhenCollapsed: statsWhenCollapsed.checked
    property alias cfg_updateInterval: updateInterval.value
    property alias cfg_changeCheckInterval: changeCheck.value
    property alias cfg_idleCheckInterval: idleCheck.value
    property alias cfg_usageInterval: usageInterval.value
    property alias cfg_restartPolicyInterval: policyInterval.value
    property alias cfg_confirmDestructive: confirmDestructive.checked
    property alias cfg_showDiskUsage: showDiskUsage.checked
    property alias cfg_debugCommands: debugCommands.checked

    function seconds(value) { return i18np("%1 second", "%1 seconds", value) }

    Kirigami.FormLayout {
        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Start up")
        }

        Controls.CheckBox {
            id: fetchOnStartup
            Kirigami.FormData.label: i18n("Check Docker:")
            text: i18n("when the widget loads")
        }

        Controls.CheckBox {
            id: refreshOnExpand
            text: i18n("every time the popup is opened")
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Staying up to date")
        }

        Controls.SpinBox {
            id: changeCheck
            Kirigami.FormData.label: i18n("Look for changes every:")
            from: 1; to: 300; editable: true
            textFromValue: function (v) { return page.seconds(v) }
            valueFromText: function (t) { return parseInt(t) || 3 }
        }
        Hint { text: i18n("While the popup or window is open. Each look is one tiny query that prints nothing when nothing happened.") }

        Controls.SpinBox {
            id: idleCheck
            Kirigami.FormData.label: i18n("…and while it is closed:")
            from: 2; to: 600; editable: true
            textFromValue: function (v) { return page.seconds(v) }
            valueFromText: function (t) { return parseInt(t) || 15 }
        }

        Controls.SpinBox {
            id: updateInterval
            Kirigami.FormData.label: i18n("Re-read everything at least every:")
            from: 5; to: 3600; editable: true
            textFromValue: function (v) { return page.seconds(v) }
            valueFromText: function (t) { return parseInt(t) || 60 }
        }
        Hint { text: i18n("A safety net in case a change notification was missed, and the only schedule used if your engine does not support them.") }

        Controls.SpinBox {
            id: policyInterval
            Kirigami.FormData.label: i18n("Re-read autostart settings every:")
            from: 10; to: 3600; editable: true
            textFromValue: function (v) { return page.seconds(v) }
            valueFromText: function (t) { return parseInt(t) || 60 }
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("CPU and memory")
        }

        Controls.SpinBox {
            id: usageInterval
            Kirigami.FormData.label: i18n("Sample usage every:")
            from: 1; to: 3600; editable: true
            textFromValue: function (v) { return page.seconds(v) }
            valueFromText: function (t) { return parseInt(t) || 5 }
        }

        Controls.CheckBox {
            id: statsWhenCollapsed
            Kirigami.FormData.label: i18n("Keep sampling:")
            text: i18n("while the popup is closed")
        }
        Hint { text: i18n("Usage is sampled over a second or two, so by default it only runs while you are looking at it.") }

        Controls.CheckBox {
            id: showDiskUsage
            Kirigami.FormData.label: i18n("Disk usage:")
            text: i18n("show it in the status bar")
        }
        Hint { text: i18n("Runs a slower command, and only while the popup is open.") }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Safety")
        }

        Controls.CheckBox {
            id: confirmDestructive
            Kirigami.FormData.label: i18n("Ask before:")
            text: i18n("removing a container")
        }
        Hint { text: i18n("Stopping the Docker service and cleaning up unused data always ask, whatever this is set to.") }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Troubleshooting")
        }

        Controls.CheckBox {
            id: debugCommands
            Kirigami.FormData.label: i18n("Log commands:")
            text: i18n("print every command to the system log")
        }
        Hint { text: i18n("Read it with: journalctl --user -f | grep runner") }
    }
}
