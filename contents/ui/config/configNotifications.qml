import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts

import org.kde.notification
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

/*
 * Notifications: what is worth interrupting for.
 */
KCM.SimpleKCM {
    id: page
    property bool cfg_useNotificationsDefault
    property bool cfg_notifyOnEngineChangeDefault
    property bool cfg_notifyOnCrashDefault
    property bool cfg_notifyOnRestartLoopDefault
    property bool cfg_notifyOnUnhealthyDefault
    property bool cfg_notifyOnRecoveredDefault
    property bool cfg_notifyOnStartStopDefault
    property int cfg_notifyMuteAfterActionDefault


    property alias cfg_useNotifications: useNotifications.checked
    property alias cfg_notifyOnEngineChange: notifyOnEngineChange.checked
    property alias cfg_notifyOnCrash: notifyOnCrash.checked
    property alias cfg_notifyOnRestartLoop: notifyOnRestartLoop.checked
    property alias cfg_notifyOnUnhealthy: notifyOnUnhealthy.checked
    property alias cfg_notifyOnRecovered: notifyOnRecovered.checked
    property alias cfg_notifyOnStartStop: notifyOnStartStop.checked
    property alias cfg_notifyMuteAfterAction: mute.value

    Notification {
        id: testNotification
        componentName: "dockmoid"
        eventId: "event"
        iconName: "dockmoid"
        title: "Dockmoid"
        text: i18n("This is a test notification.")
    }

    Kirigami.FormLayout {
        Layout.fillWidth: true
        Layout.maximumWidth: Kirigami.Units.gridUnit * 42
        Layout.alignment: Qt.AlignHCenter
        RowLayout {
            Kirigami.FormData.label: i18n("Notifications:")
            Controls.CheckBox {
                id: useNotifications

                text: i18n("enabled")
            }
            QuestionHelp { helpText: i18n("Nothing below does anything until this is on. Launching the widget never notifies about containers that were already in some state.") }
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Tell me when")
        }

        RowLayout {
            Controls.CheckBox {
                id: notifyOnCrash
                enabled: useNotifications.checked
                text: i18n("a container crashes")
            }
            QuestionHelp { helpText: i18n("It exits with an error code. Exits from docker stop, Ctrl+C or SIGTERM are not crashes.") }
        }

        Controls.CheckBox {
            id: notifyOnRestartLoop
            enabled: useNotifications.checked
            text: i18n("a container starts restarting")
        }

        Controls.CheckBox {
            id: notifyOnUnhealthy
            enabled: useNotifications.checked
            text: i18n("a container becomes unhealthy")
        }

        Controls.CheckBox {
            id: notifyOnRecovered
            enabled: useNotifications.checked
            text: i18n("an unhealthy container recovers")
        }

        RowLayout {
            Controls.CheckBox {
                id: notifyOnStartStop
                enabled: useNotifications.checked
                text: i18n("any container starts or stops")
            }
            QuestionHelp { helpText: i18n("Chatty if you restart things often.") }
        }

        Controls.Label {
            Kirigami.FormData.label: i18n("Also from Monitoring:")
            text: i18n("high CPU or memory, web pages that stop answering, and new image updates are tuned on the Monitoring page.")
            wrapMode: Text.WordWrap
            Layout.maximumWidth: Kirigami.Units.gridUnit * 28
            font: Kirigami.Theme.smallFont
            opacity: 0.7
        }

        Controls.CheckBox {
            id: notifyOnEngineChange
            enabled: useNotifications.checked
            text: i18n("Docker itself starts or stops")
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Quiet after my own actions")
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Stay silent for:")
            Controls.SpinBox {
                id: mute
                enabled: useNotifications.checked

                from: 0; to: 300; editable: true
                textFromValue: function (v) { return i18np("%1 second", "%1 seconds", v) }
                valueFromText: function (t) { return parseInt(t) || 0 }
            }
            QuestionHelp { helpText: i18n("Pressing Stop or Restart here does not raise a notification about the result. The result of an action itself is still shown by the action's own message.") }
            QuestionHelp {
                Kirigami.FormData.label: i18n("Sounds and popups:")
                helpText: i18n("Crash and unhealthy alerts are separate events in System Settings → Notifications → Dockmoid, so each can get its own sound, popup style or be silenced there.")
            }
        }
        Controls.Button {
            Kirigami.FormData.label: i18n("Test:")
            text: i18n("Send test notification")
            icon.source: Qt.resolvedUrl("../../icons/dockmoid.png")
            onClicked: testNotification.sendEvent()
        }
        Controls.Button { text: i18n("Restore page defaults"); icon.name: "edit-undo"; onClicked: { page.cfg_useNotifications = page.cfg_useNotificationsDefault; page.cfg_notifyOnEngineChange = page.cfg_notifyOnEngineChangeDefault; page.cfg_notifyOnCrash = page.cfg_notifyOnCrashDefault; page.cfg_notifyOnRestartLoop = page.cfg_notifyOnRestartLoopDefault; page.cfg_notifyOnUnhealthy = page.cfg_notifyOnUnhealthyDefault; page.cfg_notifyOnRecovered = page.cfg_notifyOnRecoveredDefault; page.cfg_notifyOnStartStop = page.cfg_notifyOnStartStopDefault; page.cfg_notifyMuteAfterAction = page.cfg_notifyMuteAfterActionDefault } }

    }
}
