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
                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                text: i18n("Names must start with a letter or digit and may contain letters, digits, dots, dashes and underscores.")
            }
        }
    }

    // ====================================================== prune ========

    function confirmPrune() {
        pruneDialog.open()
    }

    QQC2.Dialog {
        id: pruneDialog
        title: i18n("Prune Docker")
        modal: true
        anchors.centerIn: parent
        standardButtons: QQC2.Dialog.Yes | QQC2.Dialog.No

        onAccepted: root.backend.prune()

        ColumnLayout {
            spacing: Kirigami.Units.smallSpacing

            PlasmaExtras.Heading {
                Layout.fillWidth: true
                level: 3
                text: i18n("Remove all unused Docker data?")
            }

            PlasmaComponents.Label {
                Layout.fillWidth: true
                Layout.preferredWidth: Kirigami.Units.gridUnit * 24
                wrapMode: Text.WordWrap
                text: i18n("Stopped containers, unused images, build cache and unused volumes are deleted. Running containers are not touched, but anything you stopped in order to keep a rollback will be gone. The configured command is: %1", plasmoid.configuration.pruneCommand)
            }
        }
    }
}
