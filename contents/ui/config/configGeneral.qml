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

    property int currentTab: 0

    header: Kirigami.NavigationTabBar {
        actions: [
            Kirigami.Action {
                icon.name: "preferences-system"
                text: i18n("Behavior")
                checked: page.currentTab === 0
                onTriggered: page.currentTab = 0
            },
            Kirigami.Action {
                icon.name: "view-refresh"
                text: i18n("Refresh")
                checked: page.currentTab === 1
                onTriggered: page.currentTab = 1
            },
            Kirigami.Action {
                icon.name: "configure"
                text: i18n("Advanced")
                checked: page.currentTab === 2
                onTriggered: page.currentTab = 2
            }
        ]
    }
    property bool cfg_fetchOnStartupDefault
    property bool cfg_refreshOnExpandDefault
    property bool cfg_statsWhenCollapsedDefault
    property int cfg_updateIntervalDefault
    property int cfg_changeCheckIntervalDefault
    property int cfg_idleCheckIntervalDefault
    property int cfg_usageIntervalDefault
    property int cfg_restartPolicyIntervalDefault
    property bool cfg_confirmDestructiveDefault
    property bool cfg_readOnlyDefault
    property bool cfg_showDiskUsageDefault
    property bool cfg_debugCommandsDefault


    property alias cfg_fetchOnStartup: fetchOnStartup.checked
    property alias cfg_refreshOnExpand: refreshOnExpand.checked
    property alias cfg_statsWhenCollapsed: statsWhenCollapsed.checked
    property alias cfg_updateInterval: updateInterval.value
    property alias cfg_changeCheckInterval: changeCheck.value
    property alias cfg_idleCheckInterval: idleCheck.value
    property alias cfg_usageInterval: usageInterval.value
    property alias cfg_restartPolicyInterval: policyInterval.value
    property alias cfg_confirmDestructive: confirmDestructive.checked
    property alias cfg_readOnly: readOnly.checked
    property alias cfg_showDiskUsage: showDiskUsage.checked
    property alias cfg_debugCommands: debugCommands.checked

    function seconds(value) { return i18np("%1 second", "%1 seconds", value) }

    ColumnLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Kirigami.Units.smallSpacing

        Kirigami.FormLayout {
            Layout.fillWidth: true
            Layout.maximumWidth: Kirigami.Units.gridUnit * 42
            Layout.alignment: Qt.AlignHCenter
            wideMode: width >= Kirigami.Units.gridUnit * 26
            visible: page.currentTab === 0
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


        Controls.Button { text: i18n("Restore page defaults"); icon.name: "edit-undo"; onClicked: { page.cfg_fetchOnStartup = page.cfg_fetchOnStartupDefault; page.cfg_refreshOnExpand = page.cfg_refreshOnExpandDefault; page.cfg_statsWhenCollapsed = page.cfg_statsWhenCollapsedDefault; page.cfg_updateInterval = page.cfg_updateIntervalDefault; page.cfg_changeCheckInterval = page.cfg_changeCheckIntervalDefault; page.cfg_idleCheckInterval = page.cfg_idleCheckIntervalDefault; page.cfg_usageInterval = page.cfg_usageIntervalDefault; page.cfg_restartPolicyInterval = page.cfg_restartPolicyIntervalDefault; page.cfg_confirmDestructive = page.cfg_confirmDestructiveDefault; page.cfg_readOnly = page.cfg_readOnlyDefault; page.cfg_showDiskUsage = page.cfg_showDiskUsageDefault; page.cfg_debugCommands = page.cfg_debugCommandsDefault } }

        }

        Kirigami.FormLayout {
            Layout.fillWidth: true
            Layout.maximumWidth: Kirigami.Units.gridUnit * 42
            Layout.alignment: Qt.AlignHCenter
            wideMode: width >= Kirigami.Units.gridUnit * 26
            visible: page.currentTab === 1
        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Staying up to date")
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Look for changes every:")
            Controls.SpinBox {
                id: changeCheck

                from: 1; to: 300; editable: true
                textFromValue: function (v) { return page.seconds(v) }
                valueFromText: function (t) { return parseInt(t) || 3 }
            }
            QuestionHelp { helpText: i18n("While the popup or window is open. Each look is one tiny query that prints nothing when nothing happened.") }
        }

        Controls.SpinBox {
            id: idleCheck
            Kirigami.FormData.label: i18n("…and while it is closed:")
            from: 2; to: 600; editable: true
            textFromValue: function (v) { return page.seconds(v) }
            valueFromText: function (t) { return parseInt(t) || 15 }
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Re-read everything at least every:")
            Controls.SpinBox {
                id: updateInterval

                from: 5; to: 3600; editable: true
                textFromValue: function (v) { return page.seconds(v) }
                valueFromText: function (t) { return parseInt(t) || 60 }
            }
            QuestionHelp { helpText: i18n("A safety net in case a change notification was missed, and the only schedule used if your engine does not support them.") }
        }

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

        RowLayout {
            Kirigami.FormData.label: i18n("Keep sampling:")
            Controls.CheckBox {
                id: statsWhenCollapsed

                text: i18n("while the popup is closed")
            }
            QuestionHelp { helpText: i18n("Usage is sampled over a second or two, so by default it only runs while you are looking at it.") }
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Disk usage:")
            Controls.CheckBox {
                id: showDiskUsage

                text: i18n("show it in the status bar")
            }
            QuestionHelp { helpText: i18n("Runs a slower command, and only while the popup is open.") }
        }



        Controls.Button { text: i18n("Restore page defaults"); icon.name: "edit-undo"; onClicked: { page.cfg_fetchOnStartup = page.cfg_fetchOnStartupDefault; page.cfg_refreshOnExpand = page.cfg_refreshOnExpandDefault; page.cfg_statsWhenCollapsed = page.cfg_statsWhenCollapsedDefault; page.cfg_updateInterval = page.cfg_updateIntervalDefault; page.cfg_changeCheckInterval = page.cfg_changeCheckIntervalDefault; page.cfg_idleCheckInterval = page.cfg_idleCheckIntervalDefault; page.cfg_usageInterval = page.cfg_usageIntervalDefault; page.cfg_restartPolicyInterval = page.cfg_restartPolicyIntervalDefault; page.cfg_confirmDestructive = page.cfg_confirmDestructiveDefault; page.cfg_readOnly = page.cfg_readOnlyDefault; page.cfg_showDiskUsage = page.cfg_showDiskUsageDefault; page.cfg_debugCommands = page.cfg_debugCommandsDefault } }

        }

        Kirigami.FormLayout {
            Layout.fillWidth: true
            Layout.maximumWidth: Kirigami.Units.gridUnit * 42
            Layout.alignment: Qt.AlignHCenter
            wideMode: width >= Kirigami.Units.gridUnit * 26
            visible: page.currentTab === 2
        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Safety")
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Ask before:")
            Controls.CheckBox {
                id: confirmDestructive

                text: i18n("removing a container")
            }
            QuestionHelp { helpText: i18n("Stopping the Docker service and cleaning up unused data always ask, whatever this is set to.") }
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Monitoring mode:")
            Controls.CheckBox {
                id: readOnly

                text: i18n("disable actions that change containers and images")
            }
            QuestionHelp { helpText: i18n("Hides and blocks Dockmoid's management commands, including start, stop, restart, remove, pull, update, prune and arbitrary exec. This is a UI guardrail; engine permissions still control access.") }
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Troubleshooting")
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Log commands:")
            Controls.CheckBox {
                id: debugCommands

                text: i18n("print every command to the system log")
            }
            QuestionHelp { helpText: i18n("Read it with: journalctl --user -f | grep runner") }
        }


        Controls.Button { text: i18n("Restore page defaults"); icon.name: "edit-undo"; onClicked: { page.cfg_fetchOnStartup = page.cfg_fetchOnStartupDefault; page.cfg_refreshOnExpand = page.cfg_refreshOnExpandDefault; page.cfg_statsWhenCollapsed = page.cfg_statsWhenCollapsedDefault; page.cfg_updateInterval = page.cfg_updateIntervalDefault; page.cfg_changeCheckInterval = page.cfg_changeCheckIntervalDefault; page.cfg_idleCheckInterval = page.cfg_idleCheckIntervalDefault; page.cfg_usageInterval = page.cfg_usageIntervalDefault; page.cfg_restartPolicyInterval = page.cfg_restartPolicyIntervalDefault; page.cfg_confirmDestructive = page.cfg_confirmDestructiveDefault; page.cfg_readOnly = page.cfg_readOnlyDefault; page.cfg_showDiskUsage = page.cfg_showDiskUsageDefault; page.cfg_debugCommands = page.cfg_debugCommandsDefault } }

        }
    }
}
