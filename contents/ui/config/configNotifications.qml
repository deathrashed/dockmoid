import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

/*
 * Notifications: what is worth interrupting for.
 */
KCM.SimpleKCM {
    id: page

    property alias cfg_useNotifications: useNotifications.checked
    property alias cfg_notifyOnEngineChange: notifyOnEngineChange.checked
    property alias cfg_notifyOnCrash: notifyOnCrash.checked
    property alias cfg_notifyOnRestartLoop: notifyOnRestartLoop.checked
    property alias cfg_notifyOnUnhealthy: notifyOnUnhealthy.checked
    property alias cfg_notifyOnRecovered: notifyOnRecovered.checked
    property alias cfg_notifyOnStartStop: notifyOnStartStop.checked
    property alias cfg_notifyMuteAfterAction: mute.value

    Kirigami.FormLayout {
        Controls.CheckBox {
            id: useNotifications
            Kirigami.FormData.label: i18n("Notifications:")
            text: i18n("enabled")
        }
        Hint { text: i18n("Nothing below does anything until this is on. Launching the widget never notifies about containers that were already in some state.") }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Tell me when")
        }

        Controls.CheckBox {
            id: notifyOnCrash
            enabled: useNotifications.checked
            text: i18n("a container crashes")
        }
        Hint { text: i18n("It exits with an error code. Exits from docker stop, Ctrl+C or SIGTERM are not crashes.") }

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

        Controls.CheckBox {
            id: notifyOnStartStop
            enabled: useNotifications.checked
            text: i18n("any container starts or stops")
        }
        Hint { text: i18n("Chatty if you restart things often.") }

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

        Controls.SpinBox {
            id: mute
            enabled: useNotifications.checked
            Kirigami.FormData.label: i18n("Stay silent for:")
            from: 0; to: 300; editable: true
            textFromValue: function (v) { return i18np("%1 second", "%1 seconds", v) }
            valueFromText: function (t) { return parseInt(t) || 0 }
        }
        Hint { text: i18n("Pressing Stop or Restart here does not raise a notification about the result. The result of an action itself is still shown by the action's own message.") }

        Hint {
            Kirigami.FormData.label: i18n("Sounds and popups:")
            text: i18n("Crash and unhealthy alerts are separate events in System Settings → Notifications → Dockmoid, so each can get its own sound, popup style or be silenced there.")
        }
    }
}
