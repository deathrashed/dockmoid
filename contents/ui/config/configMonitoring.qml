import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.kde.notification

/*
 * Monitoring: the things Dockmoid watches for beyond "is it running".
 * Each can raise a notification (see Notifications) and shows up in the list.
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

    property bool cfg_useNotificationsDefault
    property bool cfg_notifyOnEngineChangeDefault
    property bool cfg_notifyOnCrashDefault
    property bool cfg_notifyOnRestartLoopDefault
    property bool cfg_notifyOnUnhealthyDefault
    property bool cfg_notifyOnRecoveredDefault
    property bool cfg_notifyOnStartStopDefault
    property int cfg_notifyMuteAfterActionDefault
    property int cfg_alertCpuDefault
    property int cfg_alertMemDefault
    property int cfg_alertSecondsDefault
    property string cfg_probesDefault
    property int cfg_probeIntervalDefault
    property bool cfg_notifyOnProbeDefault
    property bool cfg_checkImageUpdatesDefault
    property int cfg_updateCheckHoursDefault
    property bool cfg_notifyOnUpdateDefault
    property int cfg_historySamplesDefault


    property alias cfg_alertCpu: alertCpu.value
    property alias cfg_alertMem: alertMem.value
    property alias cfg_alertSeconds: alertSeconds.value
    property alias cfg_probes: probes.value
    property alias cfg_probeInterval: probeInterval.value
    property alias cfg_notifyOnProbe: notifyOnProbe.checked
    property alias cfg_checkImageUpdates: checkUpdates.checked
    property alias cfg_updateCheckHours: updateHours.value
    property alias cfg_notifyOnUpdate: notifyOnUpdate.checked
    property alias cfg_historySamples: historySamples.value

    function percent(v) { return v === 0 ? i18n("off") : i18n("%1%", v) }

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
        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Resource use")
        }

        Controls.SpinBox {
            id: alertCpu
            Kirigami.FormData.label: i18n("Warn above CPU:")
            from: 0; to: 100; stepSize: 5; editable: true
            textFromValue: function (v) { return page.percent(v) }
            valueFromText: function (t) { return parseInt(t) || 0 }
        }
        Controls.SpinBox {
            id: alertMem
            Kirigami.FormData.label: i18n("Warn above memory:")
            from: 0; to: 100; stepSize: 5; editable: true
            textFromValue: function (v) { return page.percent(v) }
            valueFromText: function (t) { return parseInt(t) || 0 }
        }
        RowLayout {
            Kirigami.FormData.label: i18n("…if it lasts:")
            Controls.SpinBox {
                id: alertSeconds

                from: 10; to: 3600; stepSize: 10; editable: true
                textFromValue: function (v) { return i18np("%1 second", "%1 seconds", v) }
                valueFromText: function (t) { return parseInt(t) || 120 }
            }
            QuestionHelp { helpText: i18n("A spike never notifies; the use has to stay above the limit for this long, and you hear about each episode once. Needs notifications turned on, and a popup open or “keep sampling” enabled so usage is being measured.") }
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Graph history:")
            Controls.SpinBox {
                id: historySamples

                from: 10; to: 300; stepSize: 10; editable: true
                textFromValue: function (v) { return i18n("%1 samples", v) }
                valueFromText: function (t) { return parseInt(t) || 40 }
            }
            QuestionHelp { helpText: i18n("How many readings the CPU and memory graphs in a container's page keep.") }
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Web pages")
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Check these:")
            StructuredRulesEditor {
                id: probes
                title: i18n("Web probes")
                kind: "probe"
                delimiter: "="
                headers: [i18n("Container name"), i18n("HTTP address")]
                example: i18n("No probes configured. Add a container name and its health-check URL.")

                Layout.fillWidth: true
                Layout.minimumWidth: 0
            }
            QuestionHelp { helpText: i18n("One per line: container-name=address. A container turns red in the list when its page stops answering, even while the container itself is still running. You can also put a label on a container instead: dockmoid.probe=http://localhost:8096/") }
        }

        Controls.SpinBox {
            id: probeInterval
            Kirigami.FormData.label: i18n("Check every:")
            from: 15; to: 3600; editable: true
            textFromValue: function (v) { return i18np("%1 second", "%1 seconds", v) }
            valueFromText: function (t) { return parseInt(t) || 60 }
        }
        Controls.CheckBox {
            id: notifyOnProbe
            text: i18n("notify when a page stops or starts answering")
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Image updates")
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Look for newer images:")
            Controls.CheckBox {
                id: checkUpdates

                text: i18n("ask the registries")
            }
            QuestionHelp { helpText: i18n("Off by default because it contacts Docker Hub, GHCR and the like. It compares the digest of each image you have with the registry's, one image at a time, nothing is downloaded. Containers show an “update” tag and can be updated from their menu.") }
        }

        Controls.SpinBox {
            id: updateHours
            enabled: checkUpdates.checked
            Kirigami.FormData.label: i18n("Check every:")
            from: 1; to: 168; editable: true
            textFromValue: function (v) { return i18np("%1 hour", "%1 hours", v) }
            valueFromText: function (t) { return parseInt(t) || 6 }
        }
        RowLayout {
            Controls.CheckBox {
                id: notifyOnUpdate
                enabled: checkUpdates.checked
                text: i18n("notify when a new update shows up")
            }
            QuestionHelp { helpText: i18n("Needs docker buildx (included with current Docker). Images built locally, or shown only as an id, are skipped.") }
        }
        Controls.Button { text: i18n("Restore page defaults"); icon.name: "edit-undo"; onClicked: { page.cfg_alertCpu = page.cfg_alertCpuDefault; page.cfg_alertMem = page.cfg_alertMemDefault; page.cfg_alertSeconds = page.cfg_alertSecondsDefault; page.cfg_probes = page.cfg_probesDefault; page.cfg_probeInterval = page.cfg_probeIntervalDefault; page.cfg_notifyOnProbe = page.cfg_notifyOnProbeDefault; page.cfg_checkImageUpdates = page.cfg_checkImageUpdatesDefault; page.cfg_updateCheckHours = page.cfg_updateCheckHoursDefault; page.cfg_notifyOnUpdate = page.cfg_notifyOnUpdateDefault; page.cfg_historySamples = page.cfg_historySamplesDefault } }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Notifications")
        }
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
