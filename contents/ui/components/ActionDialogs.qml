pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.extras as PlasmaExtras

/*
 * ActionDialogs — the confirmations the destructive operations go through.
 *
 * These live at the top of the view rather than inside each row because a
 * dialog parented to a delegate inside a ListView inside a StackView gets
 * buried the moment anything is pushed on top. One set of dialogs, owned by the
 * view, is both simpler and the only version that reliably renders on top.
 */
Item {
    id: root

    required property var backend

    property var pendingRecord: null
    signal runRequested(string recordId)
    function openRun(rec) { if (!root.backend.readOnly && rec.isRunning) root.runRequested(rec.id) }

    /* The icon chooser is large; build it the first time it is asked for. */
    Loader {
        id: iconChooser
        active: false
        sourceComponent: CustomIconDialog { backend: root.backend }
    }
    function chooseIcon(rec) {
        iconChooser.active = true
        if (iconChooser.item) (iconChooser.item as CustomIconDialog).choose(rec)
    }

    function confirmUpdate(rec) {
        var recreate = rec.project && rec.service && backend.canUseCompose
        confirm(recreate ? i18n("Update service %1?", rec.name) : i18n("Pull latest image for %1?", rec.name),
            recreate ? (rec.isRunning
                ? i18n("Host: %1\nImage: %2\nThe latest image will be pulled and this Compose service will be recreated and started. Expect a brief interruption. Other services are not recreated.", backend.engineBinary, rec.image)
                : i18n("Host: %1\nImage: %2\nThe latest image will be pulled and this Compose service will be recreated without starting it. Other services are not recreated.", backend.engineBinary, rec.image))
                : i18n("Host: %1\nImage: %2\nOnly the newer image is downloaded. The existing container keeps its current image until recreated using its deployment configuration.", backend.engineBinary, rec.image),
            function () { if (recreate) root.backend.updateContainer(rec); else root.backend.pullImage(rec) })
    }

    // ===================================================== remove ========

    function confirmRemove(record) {
        // The setting governs per-container destructive actions. Engine stop
        // and prune always confirm, whatever this is set to.
        if (!plasmoid.configuration.confirmDestructive) {
            root.backend.removeContainer(record)
            return
        }
        root.pendingRecord = record
        removeDialog.open()
    }

    QQC2.Dialog {
        id: removeDialog
        title: i18n("Remove container")
        modal: true
        anchors.centerIn: parent
        standardButtons: QQC2.Dialog.Yes | QQC2.Dialog.No
        onOpened: { standardButton(QQC2.Dialog.Yes).text = i18n("Remove"); standardButton(QQC2.Dialog.No).text = i18n("Cancel") }

        onAccepted: {
            if (root.pendingRecord) {
                root.backend.removeContainer(root.pendingRecord)
            }
            root.pendingRecord = null
        }

        ColumnLayout {
            spacing: Kirigami.Units.smallSpacing

            PlasmaExtras.Heading {
                Layout.fillWidth: true
                level: 3
                text: i18n("Remove %1?", root.pendingRecord ? root.pendingRecord.name : "")
            }

            PlasmaComponents.Label {
                Layout.fillWidth: true
                Layout.preferredWidth: Kirigami.Units.gridUnit * 24
                wrapMode: Text.WordWrap
                text: i18n("The container is deleted, not just stopped. Its writable layer is destroyed. Named volumes and bind mounts are left alone.")
            }
        }
    }

    // =================================================== generic confirm ===

    property var confirmAction: null
    property string confirmTitle: ""
    property string confirmText: ""

    /* Ask once, then run `action`. For anything not worth a dialog of its own. */
    function confirm(title, text, action) {
        root.confirmTitle = title
        root.confirmText = text
        root.confirmAction = action
        confirmDialog.open()
    }

    QQC2.Dialog {
        id: confirmDialog
        title: root.confirmTitle
        modal: true
        anchors.centerIn: parent
        standardButtons: QQC2.Dialog.Yes | QQC2.Dialog.No
        onOpened: { standardButton(QQC2.Dialog.Yes).text = i18n("Confirm"); standardButton(QQC2.Dialog.No).text = i18n("Cancel") }
        onAccepted: { if (root.confirmAction) root.confirmAction(); root.confirmAction = null }

        PlasmaComponents.Label {
            width: Kirigami.Units.gridUnit * 24
            wrapMode: Text.WordWrap
            text: root.confirmText
        }
    }

    // ===================================================== rename ========

    function promptRename(record) {
        root.pendingRecord = record
        renameField.text = record ? record.name : ""
        renameDialog.open()
        renameField.forceActiveFocus()
        renameField.selectAll()
    }

    /*
     * Docker container names must start with an alphanumeric and may then
     * contain alphanumerics, dots, dashes and underscores. Checking here turns
     * a round trip to the daemon into instant feedback.
     */
    function nameIsValid(name) {
        return /^[a-zA-Z0-9][a-zA-Z0-9_.-]*$/.test(name)
    }

    QQC2.Dialog {
        id: renameDialog
        title: i18n("Rename container")
        modal: true
        anchors.centerIn: parent
        standardButtons: QQC2.Dialog.Ok | QQC2.Dialog.Cancel

        onOpened: {
            renameDialog.standardButton(QQC2.Dialog.Ok).enabled = nameIsValid(renameField.text)
        }

        onAccepted: {
            if (root.pendingRecord && nameIsValid(renameField.text)) {
                root.backend.renameContainer(root.pendingRecord, renameField.text)
            }
            root.pendingRecord = null
        }

        ColumnLayout {
            spacing: Kirigami.Units.smallSpacing
            width: Kirigami.Units.gridUnit * 22

            PlasmaComponents.TextField {
                id: renameField
                Layout.fillWidth: true
                onTextChanged: {
                    renameDialog.standardButton(QQC2.Dialog.Ok).enabled = nameIsValid(text)
                    renameError.visible = text !== "" && !nameIsValid(text)
                }
            }

            PlasmaComponents.Label {
                id: renameError
                Layout.fillWidth: true
                visible: false
                wrapMode: Text.WordWrap
                color: Kirigami.Theme.negativeTextColor
                font: Kirigami.Theme.smallFont
                text: i18n("Names must start with a letter or digit and may contain letters, digits, dots, dashes and underscores.")
            }
        }
    }

    // ====================================================== prune ========

    function confirmPrune() {
        pruneImages.checked = false
        pruneContainers.checked = false
        root.backend.refreshDiskUsage()
        pruneDialog.open()
    }

    /* "Images", "Build Cache" ... -> the reclaimable size from `docker system df`. */
    function reclaimable(type) {
        var rows = root.backend.diskUsage || []
        for (let i = 0; i < rows.length; i++) {
            if (rows[i].type.toLowerCase() === type) return rows[i].reclaimable || rows[i].size
        }
        return ""
    }

    QQC2.Dialog {
        id: pruneDialog
        title: i18n("Clean up Docker")
        modal: true
        anchors.centerIn: parent
        standardButtons: QQC2.Dialog.Ok | QQC2.Dialog.Cancel

        onOpened: standardButton(QQC2.Dialog.Ok).text = i18n("Clean up")
        onAccepted: root.backend.prune({
            "images": pruneImages.checked,
            "containers": pruneContainers.checked
        })

        ColumnLayout {
            spacing: Kirigami.Units.smallSpacing
            width: Kirigami.Units.gridUnit * 26

            PlasmaExtras.Heading {
                Layout.fillWidth: true
                level: 3
                text: i18n("Remove unused Docker data?")
            }

            PlasmaComponents.Label {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: i18n("Default cleanup removes dangling images and build cache. Containers, networks, volumes, Compose files and bind-mounted data are preserved.")
            }

            QQC2.CheckBox {
                id: pruneImages
                text: root.reclaimable("images") !== ""
                    ? i18n("Also remove every unused image (%1 reclaimable)", root.reclaimable("images"))
                    : i18n("Also remove every unused image")
            }

            QQC2.CheckBox {
                id: pruneContainers
                text: i18n("Also remove stopped containers")
            }

            PlasmaComponents.Label {
                Layout.fillWidth: true
                Layout.leftMargin: Kirigami.Units.gridUnit * 1.5
                visible: pruneContainers.checked
                wrapMode: Text.WordWrap
                color: Kirigami.Theme.negativeTextColor
                text: i18n("Remove stopped container instances and their writable layers. Compose services remain visible as Undeployed. Volumes and bind-mounted data are preserved.")
            }

            PlasmaComponents.Label {
                Layout.fillWidth: true
                wrapMode: Text.WrapAnywhere
                font.family: Kirigami.Theme.fixedWidthFont.family
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                opacity: 0.7
                text: root.backend.cleanupCommand({images:pruneImages.checked,containers:pruneContainers.checked})
            }
        }
    }
}
