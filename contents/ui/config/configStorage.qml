import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import QtCore

import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.kde.kquickcontrolsaddons as KQuickControlsAddons
import "../backend" as Backend

/* Defaults and export hints for project deployments and engine storage. */
KCM.SimpleKCM {
    id: page

    property int currentTab: 0

    header: Kirigami.NavigationTabBar {
        actions: [
            Kirigami.Action {
                icon.name: "folder-development"
                text: i18n("Projects")
                checked: page.currentTab === 0
                onTriggered: page.currentTab = 0
            },
            Kirigami.Action {
                icon.name: "drive-harddisk"
                text: i18n("Engine")
                checked: page.currentTab === 1
                onTriggered: page.currentTab = 1
            }
        ]
    }

    property string cfg_deploymentDirectoryDefault
    property string cfg_deploymentStorageDirectoryDefault
    property string cfg_deploymentRegistryDefault
    property string cfg_deploymentRestartPolicyDefault
    property string cfg_deploymentNetworkDefault
    property string cfg_engineStorageTargetDefault

    property alias cfg_deploymentDirectory: projectDirectory.text
    property alias cfg_deploymentStorageDirectory: bindMountDirectory.text
    property alias cfg_deploymentRegistry: registry.text
    property alias cfg_deploymentNetwork: network.text
    property alias cfg_engineStorageTarget: engineStorageTarget.text
    property string cfg_deploymentRestartPolicy

    function syncRestartPolicy() {
        var index = page.restartPolicyValues.indexOf(page.cfg_deploymentRestartPolicy)
        if (index >= 0 && restartPolicy.currentIndex !== index)
            restartPolicy.currentIndex = index
    }

    onCfg_deploymentRestartPolicyChanged: syncRestartPolicy()

    readonly property string homeDirectory: decodeURIComponent(String(StandardPaths.writableLocation(StandardPaths.HomeLocation))
        .replace(/^file:\/\//, ""))
    readonly property string resolvedProjectDirectory: String(cfg_deploymentDirectory || "").trim() || homeDirectory + "/docker"
    readonly property string resolvedStorageDirectory: String(cfg_deploymentStorageDirectory || "").trim() || homeDirectory + "/docker-data"
    readonly property var restartPolicyValues: ["unless-stopped", "always", "on-failure", "no"]

    function fileUrl(path) {
        return "file://" + String(path).split("/").map(encodeURIComponent).join("/")
    }

    function localPath(url) {
        return decodeURIComponent(String(url).replace(/^file:\/\//, ""))
    }

    property string currentEngineRoot: ""
    property string storageQueryError: ""
    property bool queryingStorage: false
    readonly property string selectedEngine: {
        var cfg = plasmoid.configuration
        var base = String(cfg.engineCommand || "docker").trim()
        var context = String(cfg.activeContext || "")
        return /^[A-Za-z0-9][A-Za-z0-9_.-]*$/.test(context)
            ? base + (/(?:^|\/)podman$/.test(base) ? " --connection " : " --context ") + context : base
    }
    Backend.CommandRunner { id: storageRunner }
    function queryEngineStorage() {
        const selected = page.selectedEngine
        const podman = /(?:^|\/)podman(?:\s|$)/.test(selected)
        page.queryingStorage = true; page.storageQueryError = ""
        storageRunner.run(selected + (podman ? " info --format '{{.Store.GraphRoot}}'" : " info --format '{{.DockerRootDir}}'"), "diagnostic-storage", function(code,out,err) {
            page.queryingStorage = false
            if (selected !== page.selectedEngine) { page.storageQueryError = i18n("Connection changed; refresh the location."); return }
            if (code === 0) page.currentEngineRoot = String(out).trim()
            else page.storageQueryError = String(err || out).trim().split("\n")[0]
        }, {timeout:30000})
    }

    KQuickControlsAddons.Clipboard { id: clipboard }

    FolderDialog {
        id: projectFolderDialog
        title: i18n("Choose the Compose projects folder")
        currentFolder: page.fileUrl(page.resolvedProjectDirectory)
        onAccepted: projectDirectory.text = page.localPath(selectedFolder)
    }

    FolderDialog {
        id: storageFolderDialog
        title: i18n("Choose the bind-mount data folder")
        currentFolder: page.fileUrl(page.resolvedStorageDirectory)
        onAccepted: bindMountDirectory.text = page.localPath(selectedFolder)
    }

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
                Kirigami.FormData.label: i18n("Deployment defaults")
            }

            RowLayout {
                Kirigami.FormData.label: i18n("Projects folder:")
                RowLayout {

                    Controls.TextField {
                        id: projectDirectory
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        placeholderText: page.homeDirectory + "/docker"
                        Accessible.name: i18n("Compose projects folder")
                    }
                    Controls.Button {
                        text: i18n("Browse…")
                        icon.name: "folder-open"
                        onClicked: projectFolderDialog.open()
                    }
                }
                QuestionHelp {
                    helpText: i18n("Compose files and project folders live here. Leave blank to use %1.", page.homeDirectory + "/docker")
                }
            }

            RowLayout {
                Kirigami.FormData.label: i18n("Bind-mount data:")
                RowLayout {

                    Controls.TextField {
                        id: bindMountDirectory
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        placeholderText: page.homeDirectory + "/docker-data"
                        Accessible.name: i18n("Bind-mount data folder")
                    }
                    Controls.Button {
                        text: i18n("Browse…")
                        icon.name: "folder-open"
                        onClicked: storageFolderDialog.open()
                    }
                }
                QuestionHelp { helpText: i18n("Use this for files mounted into containers, such as app databases and media. Leave blank to use %1.", page.homeDirectory + "/docker-data") }
            }

            RowLayout {
                Kirigami.FormData.label: i18n("Default registry:")
                Controls.TextField {
                    id: registry
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0

                    placeholderText: "docker.io"
                }
                QuestionHelp { helpText: i18n("Used when an image reference has no registry host. Docker Hub is the default.") }
            }

            Controls.ComboBox {
                id: restartPolicy
                objectName: "deploymentRestartPolicyCombo"
                Kirigami.FormData.label: i18n("Restart policy:")
                textRole: "label"
                valueRole: "value"
                Component.onCompleted: page.syncRestartPolicy()
                onActivated: page.cfg_deploymentRestartPolicy = currentValue
                model: [
                    { label: i18n("Unless stopped"), value: "unless-stopped" },
                    { label: i18n("Always"), value: "always" },
                    { label: i18n("On failure"), value: "on-failure" },
                    { label: i18n("Never"), value: "no" }
                ]
            }

            RowLayout {
                Kirigami.FormData.label: i18n("Default network:")
                Controls.TextField {
                    id: network
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0

                    placeholderText: i18n("engine default")
                }
                QuestionHelp { helpText: i18n("Optional Compose network name for generated deployments. Leave blank to use the engine or project default.") }
            }
        }

        Kirigami.FormLayout {
            Layout.fillWidth: true
            Layout.maximumWidth: Kirigami.Units.gridUnit * 42
            Layout.alignment: Qt.AlignHCenter
            wideMode: width >= Kirigami.Units.gridUnit * 26
            visible: page.currentTab === 1

            Kirigami.Separator {
                Kirigami.FormData.isSection: true
                Kirigami.FormData.label: i18n("Engine-managed storage")
            }

            Controls.Label {
                Kirigami.FormData.label: i18n("Selected engine:")
                text: page.selectedEngine
                wrapMode: Text.WrapAnywhere
                Layout.fillWidth: true
            }
            Controls.Label {
                Kirigami.FormData.label: i18n("Reported storage root:")
                text: page.currentEngineRoot || i18n("Not checked")
                wrapMode: Text.WrapAnywhere
                Layout.fillWidth: true
            }
            RowLayout {
                Controls.Button {
                    text: page.queryingStorage ? i18n("Checking…") : i18n("Read current location")
                    enabled: !page.queryingStorage
                    icon.name: "view-refresh"
                    onClicked: page.queryEngineStorage()
                }
                QuestionHelp { helpText: i18n("This is a read-only query of the selected engine. Remote paths belong to that host. Docker's image store may also use containerd storage separately.") }
            }

            Kirigami.InlineMessage {
                Layout.fillWidth: true
                visible: page.storageQueryError !== ""
                type: Kirigami.MessageType.Error
                text: page.storageQueryError
            }

            RowLayout {
                Kirigami.FormData.label: i18n("Desired data-root:")
                Controls.TextField {
                    id: engineStorageTarget
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0

                    placeholderText: "/var/lib/docker"
                }
                QuestionHelp { helpText: i18n("Set an absolute destination path to prepare a daemon configuration snippet. This is only an export target; Dockmoid does not change the daemon or move existing data.") }
            }

            RowLayout {
                Kirigami.FormData.label: i18n("Configuration:")
                RowLayout {

                    Controls.Button {
                        text: i18n("Copy JSON")
                        icon.name: "edit-copy"
                        enabled: engineStorageTarget.text.trim().startsWith("/")
                        onClicked: clipboard.content = JSON.stringify({ "data-root": engineStorageTarget.text.trim() }, null, 2)
                    }
                    Controls.Button {
                        text: i18n("Docker daemon docs")
                        icon.name: "internet-web-browser"
                        onClicked: Qt.openUrlExternally("https://docs.docker.com/engine/daemon/")
                    }
                }
                QuestionHelp { helpText: i18n("The copied JSON contains only the data-root value. Review Docker's daemon documentation and handle any data migration separately before applying it.") }
                QuestionHelp { helpText: i18n("With Docker's containerd image store, image contents may live in a separate containerd location and are not necessarily moved by changing data-root.") }
            }
        }

        Controls.Button {
            Layout.alignment: Qt.AlignLeft
            text: i18n("Restore page defaults")
            icon.name: "edit-undo"
            onClicked: {
                page.cfg_deploymentDirectory = page.cfg_deploymentDirectoryDefault
                page.cfg_deploymentStorageDirectory = page.cfg_deploymentStorageDirectoryDefault
                page.cfg_deploymentRegistry = page.cfg_deploymentRegistryDefault
                page.cfg_deploymentRestartPolicy = page.cfg_deploymentRestartPolicyDefault
                page.cfg_deploymentNetwork = page.cfg_deploymentNetworkDefault
                page.cfg_engineStorageTarget = page.cfg_engineStorageTargetDefault
            }
        }
    }
}
