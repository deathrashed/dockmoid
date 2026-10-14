import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

/*
 * Monitoring: the things Dockmoid watches for beyond "is it running".
 * Each can raise a notification (see Notifications) and shows up in the list.
 */
KCM.SimpleKCM {
    id: page

    property alias cfg_alertCpu: alertCpu.value
    property alias cfg_alertMem: alertMem.value
    property alias cfg_alertSeconds: alertSeconds.value
    property alias cfg_probes: probes.text
    property alias cfg_probeInterval: probeInterval.value
    property alias cfg_notifyOnProbe: notifyOnProbe.checked
    property alias cfg_checkImageUpdates: checkUpdates.checked
    property alias cfg_updateCheckHours: updateHours.value
    property alias cfg_notifyOnUpdate: notifyOnUpdate.checked
    property alias cfg_historySamples: historySamples.value

    function percent(v) { return v === 0 ? i18n("off") : i18n("%1%", v) }

    Kirigami.FormLayout {
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
        Controls.SpinBox {
            id: alertSeconds
            Kirigami.FormData.label: i18n("…if it lasts:")
            from: 10; to: 3600; stepSize: 10; editable: true
            textFromValue: function (v) { return i18np("%1 second", "%1 seconds", v) }
            valueFromText: function (t) { return parseInt(t) || 120 }
        }
        Hint { text: i18n("A spike never notifies; the use has to stay above the limit for this long, and you hear about each episode once. Needs notifications turned on, and a popup open or “keep sampling” enabled so usage is being measured.") }

        Controls.SpinBox {
            id: historySamples
            Kirigami.FormData.label: i18n("Graph history:")
            from: 10; to: 300; stepSize: 10; editable: true
            textFromValue: function (v) { return i18n("%1 samples", v) }
            valueFromText: function (t) { return parseInt(t) || 40 }
        }
        Hint { text: i18n("How many readings the CPU and memory graphs in a container's page keep.") }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Web pages")
        }

        Controls.ScrollView {
            Kirigami.FormData.label: i18n("Check these:")
            Kirigami.FormData.labelAlignment: Qt.AlignTop
            Layout.preferredWidth: Kirigami.Units.gridUnit * 26
            Layout.preferredHeight: Kirigami.Units.gridUnit * 6

            Controls.TextArea {
                id: probes
                wrapMode: TextEdit.NoWrap
                font.family: "monospace"
                placeholderText: "jellyfin=http://localhost:8096/health"
                selectByMouse: true
            }
        }
        Hint { text: i18n("One per line: container-name=address. A container turns red in the list when its page stops answering, even while the container itself is still running. You can also put a label on a container instead: dockmoid.probe=http://localhost:8096/") }

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

        Controls.CheckBox {
            id: checkUpdates
            Kirigami.FormData.label: i18n("Look for newer images:")
            text: i18n("ask the registries")
        }
        Hint { text: i18n("Off by default because it contacts Docker Hub, GHCR and the like. It compares the digest of each image you have with the registry's, one image at a time, nothing is downloaded. Containers show an “update” tag and can be updated from their menu.") }

        Controls.SpinBox {
            id: updateHours
            enabled: checkUpdates.checked
            Kirigami.FormData.label: i18n("Check every:")
            from: 1; to: 168; editable: true
            textFromValue: function (v) { return i18np("%1 hour", "%1 hours", v) }
            valueFromText: function (t) { return parseInt(t) || 6 }
        }
        Controls.CheckBox {
            id: notifyOnUpdate
            enabled: checkUpdates.checked
            text: i18n("notify when a new update shows up")
        }
        Hint { text: i18n("Needs docker buildx (included with current Docker). Images built locally, or shown only as an id, are skipped.") }
    }
}
