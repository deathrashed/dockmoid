import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import QtQuick.Dialogs
import "../../lib/profiles.js" as Profiles
import "../backend" as Backend

/*
 * Every command the plasmoid can run.
 *
 * All of them are plain shell fragments, so they honour DOCKER_HOST, contexts,
 * aliases, podman and the user's PATH exactly like a terminal would. That is
 * also why they are editable: the defaults suit a systemd install, but a
 * rootless, remote or podman setup needs different ones.
 */
KCM.SimpleKCM {
    id: page
    /* Commands are long; give each field room to show one in full. */
    readonly property real fieldWidth: Math.max(Kirigami.Units.gridUnit * 16, Math.min(Kirigami.Units.gridUnit * 34, page.width - Kirigami.Units.gridUnit * 16))

    property int currentTab: 0

    header: Kirigami.NavigationTabBar {
        objectName: "settingsTabs"
        actions: [
            Kirigami.Action {
                icon.name: "network-wired"
                text: i18n("Connection")
                checked: page.currentTab === 0
                onTriggered: page.currentTab = 0
            },
            Kirigami.Action {
                icon.name: "view-list-details"
                text: i18n("Reading")
                checked: page.currentTab === 1
                onTriggered: page.currentTab = 1
            },
            Kirigami.Action {
                icon.name: "system-run"
                text: i18n("Actions")
                checked: page.currentTab === 2
                onTriggered: page.currentTab = 2
            },
            Kirigami.Action {
                icon.name: "configure"
                text: i18n("Advanced")
                checked: page.currentTab === 3
                onTriggered: page.currentTab = 3
            },
            Kirigami.Action {
                icon.name: "user-identity"
                text: i18n("Profiles")
                checked: page.currentTab === 4
                onTriggered: page.currentTab = 4
            },
            Kirigami.Action {
                icon.name: "help-about"
                text: i18n("About")
                checked: page.currentTab === 5
                onTriggered: page.currentTab = 5
            }
        ]
    }

    property int cfg_updateInterval
    property int cfg_changeCheckInterval
    property int cfg_idleCheckInterval
    property int cfg_usageInterval
    property int cfg_logTailLines
    property string cfg_shellCommand
    property bool cfg_fetchOnStartup
    property bool cfg_refreshOnExpand
    property bool cfg_statsWhenCollapsed
    property bool cfg_useNotifications
    property bool cfg_confirmDestructive
    property bool cfg_showDiskUsage
    property bool cfg_notifyOnEngineChange
    property bool cfg_debugCommands
    property bool cfg_readOnly
    property string cfg_profiles
    property string cfg_activeProfile
    property string cfg_savedViews
    property bool cfg_notifyOnCrash
    property bool cfg_notifyOnRestartLoop
    property bool cfg_notifyOnUnhealthy
    property bool cfg_notifyOnRecovered
    property bool cfg_notifyOnStartStop
    property int cfg_notifyMuteAfterAction
    property int cfg_restartPolicyInterval
    property int cfg_alertCpu
    property int cfg_alertMem
    property int cfg_alertSeconds
    property bool cfg_checkImageUpdates
    property int cfg_updateCheckHours
    property bool cfg_notifyOnUpdate
    property string cfg_updateCache
    property string cfg_probes
    property int cfg_probeInterval
    property bool cfg_notifyOnProbe
    property string cfg_pinned
    property int cfg_historySamples
    property int cfg_middleClickAction
    property string cfg_terminalCommand
    property string cfg_editorCommand
    property string cfg_launchers
    property string cfg_shellList
    property string cfg_lanHost
    property string cfg_tailscaleHost
    property bool cfg_autoDetectHosts
    property bool cfg_enableBrowserLinks
    property bool cfg_allowLanLinks
    property bool cfg_allowTailscaleLinks
    property string cfg_httpsPorts
    property int cfg_defaultViewMode
    property int cfg_defaultDetailLevel
    property string cfg_sortRole
    property bool cfg_sortAscending
    property bool cfg_showHeader
    property bool cfg_showStatusBar
    property bool cfg_showActivityBar
    property bool cfg_showHealth
    property bool cfg_showResourceBars
    property int cfg_rowIconSize
    property bool cfg_separateResult
    property string cfg_separator
    property bool cfg_mainDot
    property int cfg_mainDotPosition
    property string cfg_mainDotColor
    property bool cfg_mainDotUseCustomColor
    property string cfg_iconColor
    property bool cfg_iconUseCustomColor
    property bool cfg_wrapText
    property bool cfg_widthFit
    property bool cfg_hideWhenInactive
    property int cfg_panelIndicator
    property int cfg_indicatorTarget
    property bool cfg_customStateColors
    property string cfg_stateOkColor
    property string cfg_stateBadColor
    property string cfg_statePausedColor
    property bool cfg_showRestartPolicy
    property string cfg_customIconFiles
    property string cfg_customIcons
    property string cfg_serviceIconDirectory
    property int cfg_iconVariant
    property bool cfg_coloredServiceIcons
    property alias cfg_activeContext: contextName.text
    property string cfg_activeContextDefault
    property string diagnosticOutput: ""
    Backend.CommandRunner { id: diagnosticRunner; timeout: 12000; maxConcurrent: 1 }
    function testConnection() {
        diagnosticOutput = i18n("Testing unsaved connection settings…")
        var base = engineCommand.text.trim()
        if (!base) { diagnosticOutput = i18n("Enter an engine command first."); return }
        var endpoint = base + (contextName.text.trim() ? (/podman$/.test(base) ? " --connection " : " --context ") + quote(contextName.text.trim()) : "")
        var compose = composeCmd.text.replace(/\{engine\}/g, endpoint)
        var cmd = "printf \"Engine CLI\\n\"; " + base + " --version; printf \"\\nServer connection\\n\"; " + endpoint + " version; printf \"\\nCompose (optional)\\n\"; " + (compose.trim() ? compose + " version" : "printf \"Not configured\\n\"") + "; printf \"\\nBuildx (optional)\\n\"; " + endpoint + " buildx version; printf \"\\nLocal optional tools\\n\"; for tool in git curl pkexec systemctl; do command -v \"$tool\" || printf \"%s unavailable\\n\" \"$tool\"; done"
        diagnosticRunner.run("sh -c " + quote(cmd), "settings-connection", function(code, out, err) {
            const timedOut = code === -1 && String(err || "").toLowerCase().indexOf("timed out") >= 0
            diagnosticOutput = String(out || "") + String(err || "")
                + (timedOut ? i18n("\nTest reached its 10 second limit.") : "")
        }, {timeout: 10000})
    }
    property string cfg_engineCommandDefault
    property string cfg_eventsCommandDefault
    property string cfg_restartPolicyCommandDefault
    property string cfg_setRestartPolicyCommandDefault
    property string cfg_listCommandDefault
    property string cfg_usageCommandDefault
    property string cfg_systemDfCommandDefault
    property string cfg_imagesCommandDefault
    property string cfg_volumesCommandDefault
    property string cfg_networksCommandDefault
    property string cfg_removeImageCommandDefault
    property string cfg_removeVolumeCommandDefault
    property string cfg_removeNetworkCommandDefault
    property string cfg_composeCommandDefault
    property string cfg_updateCheckCommandDefault
    property string cfg_contextListCommandDefault
    property string cfg_startOneCommandDefault
    property string cfg_stopOneCommandDefault
    property string cfg_restartOneCommandDefault
    property string cfg_killOneCommandDefault
    property string cfg_pauseOneCommandDefault
    property string cfg_unpauseOneCommandDefault
    property string cfg_removeOneCommandDefault
    property string cfg_renameOneCommandDefault
    property string cfg_pullImageCommandDefault
    property string cfg_logsCommandDefault
    property string cfg_logsFollowCommandDefault
    property string cfg_inspectCommandDefault
    property string cfg_groupStartCommandDefault
    property string cfg_groupStopCommandDefault
    property string cfg_groupRestartCommandDefault
    property string cfg_startCommandDefault
    property string cfg_stopServiceCommandDefault
    property string cfg_stopSocketCommandDefault
    property string cfg_pruneCommandDefault


    property alias cfg_engineCommand: engineCommand.text
    property alias cfg_eventsCommand: eventsCommand.text
    property alias cfg_restartPolicyCommand: policyRead.text
    property alias cfg_setRestartPolicyCommand: policySet.text
    property alias cfg_checkActiveCommand: checkActive.text
    property alias cfg_listCommand: list.text
    property alias cfg_usageCommand: usage.text
    property alias cfg_infoCommand: info.text
    property alias cfg_systemDfCommand: systemDf.text
    property alias cfg_imagesCommand: imagesCmd.text
    property alias cfg_volumesCommand: volumesCmd.text
    property alias cfg_networksCommand: networksCmd.text
    property alias cfg_removeImageCommand: rmImage.text
    property alias cfg_removeVolumeCommand: rmVolume.text
    property alias cfg_removeNetworkCommand: rmNetwork.text
    property alias cfg_composeCommand: composeCmd.text
    property alias cfg_updateCheckCommand: updateCmd.text
    property alias cfg_contextListCommand: contextCmd.text
    property string cfg_checkActiveCommandDefault
    property string cfg_infoCommandDefault

    property alias cfg_startOneCommand: startOne.text
    property alias cfg_stopOneCommand: stopOne.text
    property alias cfg_restartOneCommand: restartOne.text
    property alias cfg_killOneCommand: killOne.text
    property alias cfg_pauseOneCommand: pauseOne.text
    property alias cfg_unpauseOneCommand: unpauseOne.text
    property alias cfg_removeOneCommand: removeOne.text
    property alias cfg_renameOneCommand: renameOne.text
    property alias cfg_pullImageCommand: pullImage.text

    property alias cfg_logsCommand: logs.text
    property alias cfg_logsFollowCommand: logsFollow.text
    property alias cfg_inspectCommand: inspect.text

    property alias cfg_groupStartCommand: groupStart.text
    property alias cfg_groupStopCommand: groupStop.text
    property alias cfg_groupRestartCommand: groupRestart.text

    property alias cfg_startCommand: startService.text
    property alias cfg_stopServiceCommand: stopService.text
    property alias cfg_stopSocketCommand: stopSocket.text
    property alias cfg_pruneCommand: prune.text

    readonly property var readFields: [
        checkActive, list, usage, info, systemDf
    ]
    readonly property var controlFields: [
        startOne, stopOne, restartOne, killOne, pauseOne, unpauseOne,
        removeOne, renameOne, pullImage
    ]
    readonly property var diagnosticFields: [
        logs, logsFollow, inspect
    ]
    readonly property var groupFields: [
        groupStart, groupStop, groupRestart
    ]
    readonly property var engineFields: [
        startService, stopService, stopSocket, prune
    ]

    readonly property var profileData: Profiles.load(cfg_profiles)
    property string status: ""
    property bool allowCommands: false
    Backend.CommandRunner { id: jobs }

    function quote(value) { return "'" + String(value).replace(/'/g, "'\\''") + "'" }
    function path(url) {
        var text = String(url)
        if (!/^file:\/\/\//.test(text)) return ""
        return decodeURIComponent(text.slice(7))
    }
    function saveProfile() {
        if (profileName.text.trim() === "") return
        var next = Profiles.load(cfg_profiles)
        var current = next.profiles.find(function (p) { return p.id === page.cfg_activeProfile })
        var id = current && current.name === profileName.text.trim() ? current.id : "profile-" + Date.now()
        try {
            next = Profiles.upsert(next, {id: id, name: profileName.text.trim(), values: Profiles.capture(page)})
            cfg_profiles = JSON.stringify(next); cfg_activeProfile = id
            status = i18n("Profile saved in these settings. Press Apply to keep it.")
        } catch (e) {
            status = String(e)
        }
    }
    function activate() {
        var profile = profileData.profiles[selector.currentIndex]
        if (!profile) return
        Object.keys(profile.values).forEach(function (key) { page["cfg_" + key] = profile.values[key] })
        cfg_activeProfile = profile.id; profileName.text = profile.name
        status = i18n("Profile loaded into these settings. Press Apply to switch; Cancel discards the change.")
    }
    FileDialog {
        id: exportFile
        title: i18n("Export Dockmoid profiles")
        fileMode: FileDialog.SaveFile
        defaultSuffix: "json"
        nameFilters: [i18n("JSON files (*.json)")]
        onAccepted: {
            var dest = page.path(selectedFile)
            if (!dest) return
            let data = Profiles.prepareExport(Profiles.load(page.cfg_profiles), {
                id: "current-" + Date.now(), name: i18n("Current settings"), values: Profiles.capture(page)
            }, page.allowCommands)
            jobs.run("umask 077; printf '%s' " + page.quote(JSON.stringify(data.data, null, 2)) + " > " + page.quote(dest), "profile-export", function (code, out, err) {
                if (code !== 0) { page.status = String(err); return }
                page.status = data.includedCurrent
                    ? i18n("Profiles exported with a copy of current settings. Custom artwork files are stored separately.")
                    : i18n("Profiles exported. All 100 saved profiles were included; current settings were not added because the export limit is 100. Custom artwork files are stored separately.")
            })
        }
    }
    FileDialog {
        id: importFile
        title: i18n("Import Dockmoid profiles")
        nameFilters: [i18n("JSON files (*.json)")]
        onAccepted: {
            var src = page.path(selectedFile)
            if (!src) return
            jobs.run("test $(wc -c < " + page.quote(src) + ") -le 1048576 && cat " + page.quote(src), "profile-import", function (code, out, err) {
                try {
                    if (code !== 0) throw new Error(err || i18n("The file is too large or unreadable."))
                    const incoming = Profiles.parse(out, page.allowCommands)
                    const next = Profiles.load(page.cfg_profiles)
                    const merged = Profiles.merge(next, incoming, "import-" + Date.now() + "-")
                    page.cfg_profiles = JSON.stringify(merged)
                    page.status = i18n("Profiles imported. Select one and load it, then press Apply.")
                } catch (e) { page.status = String(e) }
            })
        }
    }

    ColumnLayout {
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
        }
        spacing: Kirigami.Units.smallSpacing
        ColumnLayout { Layout.fillWidth: true; visible: page.currentTab === 0
        // ---------------------------------------- engine presets ---------
        RowLayout {
            Kirigami.FormLayout {
                Layout.fillWidth: true
                wideMode: false
                Kirigami.Separator {
                    Kirigami.FormData.isSection: true
                    Kirigami.FormData.label: i18n("Container engine")
                }

                Controls.ComboBox {
                    id: preset
                    Kirigami.FormData.label: i18n("Preset: ")
                    textRole: "label"
                    model: [
                        { "label": i18n("Choose…") },
                        { "label": i18n("Docker (systemd service)"), "engine": "docker",
                          "start": "pkexec systemctl start docker", "stop": "pkexec systemctl stop docker",
                          "socket": "pkexec systemctl stop docker.socket" },
                        { "label": i18n("Docker, rootless"), "engine": "docker",
                          "start": "systemctl --user start docker", "stop": "systemctl --user stop docker",
                          "socket": "true" },
                        { "label": i18n("Podman (experimental)"), "engine": "podman",
                          "start": "systemctl --user start podman.socket", "stop": "systemctl --user stop podman.socket",
                          "socket": "true",
                          "check": "{engine} info --format {{.Version.Version}}", "info": "" },
                        { "label": i18n("Colima"), "engine": "docker",
                          "start": "colima start", "stop": "colima stop", "socket": "true" }
                    ]
                    onActivated: function (index) {
                        var p = model[index]
                        if (!p.engine) return
                        engineCommand.text = p.engine
                        startService.text = p.start
                        stopService.text = p.stop
                        stopSocket.text = p.socket
                        checkActive.text = p.check !== undefined ? p.check : page.cfg_checkActiveCommandDefault
                        info.text = p.info !== undefined ? p.info : page.cfg_infoCommandDefault
                        currentIndex = 0
                    }
                }

                Controls.TextField { Layout.preferredWidth: page.fieldWidth
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    id: engineCommand
                    Kirigami.FormData.label: i18n("Engine command: ")
                    placeholderText: "docker"
                }
            }
            QuestionHelp {
                helpText: i18n("Every default command starts with {engine}, which is replaced by the engine command. Use docker, podman, nerdctl, a full path or a command such as “sudo docker”. Presets also set service start/stop, socket stop, active check and engine summary; the first preset is the usual distribution setup. Other overrides stay unchanged. Apply saves edits. Commands support placeholders {engine}, {id} (short container id), {name}, {image}, {shell}, {tail}, {project} and {file}; names and image references are quoted. Subshells such as $(...) work. Podman is experimental.")
            }
        }


        Kirigami.FormLayout {
            Layout.fillWidth: true
            RowLayout {
                Controls.TextField { id: contextName; Layout.fillWidth: true; Layout.minimumWidth: 0; Kirigami.FormData.label: i18n("Context / connection:"); placeholderText: i18n("Current CLI context") }
                QuestionHelp { helpText: i18n("Uses the values on this page before Apply. Test only asks for versions and local tool paths; it does not start services or change containers. Optional capabilities can be unavailable independently. Podman remains experimental.") }
            }
            Controls.Button { text: i18n("Test connection and capabilities"); enabled: !diagnosticRunner.busy; icon.name: "network-connect"; onClicked: page.testConnection() }
            Controls.ScrollView { Layout.fillWidth: true; Layout.preferredHeight: Kirigami.Units.gridUnit * 10; visible: page.diagnosticOutput !== ""; Controls.TextArea { text: page.diagnosticOutput; readOnly: true; wrapMode: TextEdit.Wrap; selectByMouse: true; font.family: Kirigami.Theme.fixedWidthFont.family } }
        }
Controls.Button { text: i18n("Restore defaults"); icon.name: "edit-undo"; onClicked: { page.cfg_engineCommand = page.cfg_engineCommandDefault; page.cfg_activeContext = page.cfg_activeContextDefault } }
        }
        ColumnLayout { Layout.fillWidth: true; visible: page.currentTab === 1
        // ------------------------------------------ reads --------------
        Kirigami.FormLayout {
            Layout.fillWidth: true
            wideMode: false
            Kirigami.Separator {
                Kirigami.FormData.isSection: true
                Kirigami.FormData.label: i18n("Reading")
            }
        }

        Kirigami.FormLayout {
            Layout.fillWidth: true
            wideMode: false
            RowLayout {
                Kirigami.FormData.label: i18n("Is Docker running: ")
                Controls.TextField { Layout.preferredWidth: page.fieldWidth
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    id: checkActive
                }
                QuestionHelp {
                    helpText: i18n("Docker is running when this command exits with status 0. The default queries the daemon directly, including for rootless Docker, remote contexts and Podman. Output containing “inactive” or “failed” means it is down even if the command exits with status 0.")
                }
            }
            RowLayout {
                Kirigami.FormData.label: i18n("List containers: ")
                Controls.TextField { Layout.preferredWidth: page.fieldWidth; Layout.fillWidth: true; Layout.minimumWidth: 0; id: list }
                QuestionHelp {
                    helpText: i18n("The list and usage commands must emit JSON: one object per line for Docker 23 and newer, or a single array for Podman.")
                }
            }
            RowLayout {
                Kirigami.FormData.label: i18n("Container usage: ")
                Controls.TextField { Layout.preferredWidth: page.fieldWidth; Layout.fillWidth: true; Layout.minimumWidth: 0; id: usage }
                QuestionHelp {
                    helpText: i18n("Like the list command, this must emit JSON: one object per line for Docker 23 and newer, or a single array for Podman.")
                }
            }
            RowLayout {
                Kirigami.FormData.label: i18n("Engine summary: ")
                Controls.TextField { Layout.preferredWidth: page.fieldWidth; Layout.fillWidth: true; Layout.minimumWidth: 0; id: info }
                QuestionHelp {
                    helpText: i18n("Print pipe-separated values in the order shown by this command's format; print nothing to omit the summary.")
                }
            }
            Controls.TextField { Layout.preferredWidth: page.fieldWidth
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                id: systemDf
                Kirigami.FormData.label: i18n("Disk usage: ")
            }
            RowLayout {
                Kirigami.FormData.label: i18n("Look for changes: ")
                Controls.TextField { Layout.preferredWidth: page.fieldWidth; Layout.fillWidth: true; Layout.minimumWidth: 0; id: eventsCommand }
                QuestionHelp {
                    helpText: i18n("This command receives {since} and {until} as Unix timestamps and prints one line for each relevant event. When General → Refresh → Change events is on, the same command runs without {until} as one long-running listener. If it fails, Dockmoid falls back to interval polling.")
                }
            }
            Controls.TextField { Layout.preferredWidth: page.fieldWidth
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                id: policyRead
                Kirigami.FormData.label: i18n("Read autostart settings: ")
            }
            Controls.TextField { Layout.preferredWidth: page.fieldWidth
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                id: policySet
                Kirigami.FormData.label: i18n("Set autostart policy: ")
            }
        }

Controls.Button { text: i18n("Restore defaults"); icon.name: "edit-undo"; onClicked: { page.cfg_checkActiveCommand = page.cfg_checkActiveCommandDefault; page.cfg_listCommand = page.cfg_listCommandDefault; page.cfg_usageCommand = page.cfg_usageCommandDefault; page.cfg_infoCommand = page.cfg_infoCommandDefault; page.cfg_systemDfCommand = page.cfg_systemDfCommandDefault; page.cfg_eventsCommand = page.cfg_eventsCommandDefault; page.cfg_restartPolicyCommand = page.cfg_restartPolicyCommandDefault; page.cfg_setRestartPolicyCommand = page.cfg_setRestartPolicyCommandDefault } }
        }
        ColumnLayout { Layout.fillWidth: true; visible: page.currentTab === 2
        // --------------------------------------- container ------------
        Kirigami.FormLayout {
            Layout.fillWidth: true
            wideMode: false
            Kirigami.Separator {
                Kirigami.FormData.isSection: true
                Kirigami.FormData.label: i18n("Container actions")
            }
        }

        Kirigami.FormLayout {
            Layout.fillWidth: true
            wideMode: false
            Controls.TextField { Layout.preferredWidth: page.fieldWidth
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                id: startOne
                Kirigami.FormData.label: i18n("Start: ")
            }
            Controls.TextField { Layout.preferredWidth: page.fieldWidth
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                id: stopOne
                Kirigami.FormData.label: i18n("Stop: ")
            }
            Controls.TextField { Layout.preferredWidth: page.fieldWidth
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                id: restartOne
                Kirigami.FormData.label: i18n("Restart: ")
            }
            Controls.TextField { Layout.preferredWidth: page.fieldWidth
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                id: killOne
                Kirigami.FormData.label: i18n("Kill: ")
            }
            Controls.TextField { Layout.preferredWidth: page.fieldWidth
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                id: pauseOne
                Kirigami.FormData.label: i18n("Pause: ")
            }
            Controls.TextField { Layout.preferredWidth: page.fieldWidth
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                id: unpauseOne
                Kirigami.FormData.label: i18n("Unpause: ")
            }
            Controls.TextField { Layout.preferredWidth: page.fieldWidth
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                id: removeOne
                Kirigami.FormData.label: i18n("Remove: ")
            }
            Controls.TextField { Layout.preferredWidth: page.fieldWidth
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                id: renameOne
                Kirigami.FormData.label: i18n("Rename: ")
            }
            Controls.TextField { Layout.preferredWidth: page.fieldWidth
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                id: pullImage
                Kirigami.FormData.label: i18n("Pull image: ")
            }
        }

        // ------------------------------------------- groups -------------
        Kirigami.FormLayout {
            Layout.fillWidth: true
            wideMode: false
            Kirigami.Separator {
                Kirigami.FormData.isSection: true
                Kirigami.FormData.label: i18n("Compose project actions")
            }
        }

        Kirigami.FormLayout {
            Layout.fillWidth: true
            wideMode: false
            Controls.TextField { Layout.preferredWidth: page.fieldWidth
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                id: groupStart
                Kirigami.FormData.label: i18n("Start a project: ")
            }
            Controls.TextField { Layout.preferredWidth: page.fieldWidth
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                id: groupStop
                Kirigami.FormData.label: i18n("Stop a project: ")
            }
            RowLayout {
                Kirigami.FormData.label: i18n("Restart a project: ")
                Controls.TextField { Layout.preferredWidth: page.fieldWidth; Layout.fillWidth: true; Layout.minimumWidth: 0; id: groupRestart }
                QuestionHelp {
                    helpText: i18n("Project actions run on every container with the Compose project label through the Docker CLI, so the Compose plugin is not required. They are disabled while the list is filtered to avoid affecting containers you cannot see.")
                }
            }
        }

Controls.Button { text: i18n("Restore defaults"); icon.name: "edit-undo"; onClicked: { page.cfg_startOneCommand = page.cfg_startOneCommandDefault; page.cfg_stopOneCommand = page.cfg_stopOneCommandDefault; page.cfg_restartOneCommand = page.cfg_restartOneCommandDefault; page.cfg_killOneCommand = page.cfg_killOneCommandDefault; page.cfg_pauseOneCommand = page.cfg_pauseOneCommandDefault; page.cfg_unpauseOneCommand = page.cfg_unpauseOneCommandDefault; page.cfg_removeOneCommand = page.cfg_removeOneCommandDefault; page.cfg_renameOneCommand = page.cfg_renameOneCommandDefault; page.cfg_pullImageCommand = page.cfg_pullImageCommandDefault; page.cfg_groupStartCommand = page.cfg_groupStartCommandDefault; page.cfg_groupStopCommand = page.cfg_groupStopCommandDefault; page.cfg_groupRestartCommand = page.cfg_groupRestartCommandDefault } }
        }
        ColumnLayout { Layout.fillWidth: true; visible: page.currentTab === 3
        // -------------------------------------- diagnostics ------------
        Kirigami.FormLayout {
            Layout.fillWidth: true
            wideMode: false
            Kirigami.Separator {
                Kirigami.FormData.isSection: true
                Kirigami.FormData.label: i18n("Logs, shell and inspection")
            }
        }

        Kirigami.FormLayout {
            Layout.fillWidth: true
            wideMode: false
            Controls.TextField { Layout.preferredWidth: page.fieldWidth
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                id: logs
                Kirigami.FormData.label: i18n("Read logs: ")
            }
            Controls.TextField { Layout.preferredWidth: page.fieldWidth
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                id: logsFollow
                Kirigami.FormData.label: i18n("Follow logs: ")
            }
                        Controls.TextField { Layout.preferredWidth: page.fieldWidth
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                id: inspect
                Kirigami.FormData.label: i18n("Inspect: ")
            }
        }

        // ---------------------------------------- resources & more -------
        Kirigami.FormLayout {
            Layout.fillWidth: true
            wideMode: false
            Kirigami.Separator {
                Kirigami.FormData.isSection: true
                Kirigami.FormData.label: i18n("Images, volumes, networks, Compose")
            }
            Controls.TextField { Layout.preferredWidth: page.fieldWidth
                Layout.fillWidth: true
                Layout.minimumWidth: 0; id: imagesCmd; Kirigami.FormData.label: i18n("List images: ") }
            Controls.TextField { Layout.preferredWidth: page.fieldWidth
                Layout.fillWidth: true
                Layout.minimumWidth: 0; id: volumesCmd; Kirigami.FormData.label: i18n("List volumes: ") }
            Controls.TextField { Layout.preferredWidth: page.fieldWidth
                Layout.fillWidth: true
                Layout.minimumWidth: 0; id: networksCmd; Kirigami.FormData.label: i18n("List networks: ") }
            Controls.TextField { Layout.preferredWidth: page.fieldWidth
                Layout.fillWidth: true
                Layout.minimumWidth: 0; id: rmImage; Kirigami.FormData.label: i18n("Remove an image: ") }
            Controls.TextField { Layout.preferredWidth: page.fieldWidth
                Layout.fillWidth: true
                Layout.minimumWidth: 0; id: rmVolume; Kirigami.FormData.label: i18n("Remove a volume: ") }
            Controls.TextField { Layout.preferredWidth: page.fieldWidth
                Layout.fillWidth: true
                Layout.minimumWidth: 0; id: rmNetwork; Kirigami.FormData.label: i18n("Remove a network: ") }
            RowLayout {
                Kirigami.FormData.label: i18n("Compose command: ")
                Controls.TextField { Layout.preferredWidth: page.fieldWidth; Layout.fillWidth: true; Layout.minimumWidth: 0; id: composeCmd }
                QuestionHelp { helpText: i18n("Use “docker-compose” if you have only the old standalone Compose tool.") }
            }
            RowLayout {
                Kirigami.FormData.label: i18n("Check an image for updates: ")
                Controls.TextField { Layout.preferredWidth: page.fieldWidth; Layout.fillWidth: true; Layout.minimumWidth: 0; id: updateCmd }
                QuestionHelp { helpText: i18n("Print “local digests|remote digest”. The default command requires docker buildx.") }
            }
            RowLayout {
                Kirigami.FormData.label: i18n("List hosts (contexts): ")
                Controls.TextField { Layout.preferredWidth: page.fieldWidth; Layout.fillWidth: true; Layout.minimumWidth: 0; id: contextCmd }
                QuestionHelp { helpText: i18n("Hosts are Docker contexts, created with “docker context create”. Use a context to connect to another machine over SSH.") }
            }
        }

        // ------------------------------------------- engine -------------
        Kirigami.FormLayout {
            Layout.fillWidth: true
            wideMode: false
            Kirigami.Separator {
                Kirigami.FormData.isSection: true
                Kirigami.FormData.label: i18n("Docker service")
            }
        }

        Kirigami.FormLayout {
            Layout.fillWidth: true
            wideMode: false
            RowLayout {
                Kirigami.FormData.label: i18n("Start the service: ")
                Controls.TextField { Layout.preferredWidth: page.fieldWidth; Layout.fillWidth: true; Layout.minimumWidth: 0; id: startService }
                QuestionHelp {
                    helpText: i18n("System Docker services require elevated privileges, so the default uses pkexec and asks for your password. Rootless Docker, Podman and Colima need no elevation; select a preset above.")
                }
            }
            Controls.TextField { Layout.preferredWidth: page.fieldWidth
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                id: stopService
                Kirigami.FormData.label: i18n("Stop the service: ")
            }
            Controls.TextField { Layout.preferredWidth: page.fieldWidth
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                id: stopSocket
                Kirigami.FormData.label: i18n("Stop the socket: ")
            }
            RowLayout {
                Kirigami.FormData.label: i18n("Prune: ")
                Controls.TextField { Layout.preferredWidth: page.fieldWidth; Layout.fillWidth: true; Layout.minimumWidth: 0; id: prune; enabled: false; text: "{engine} image prune -f && {engine} builder prune -f" }
                QuestionHelp {
                    helpText: i18n("Cleanup uses fixed image and build-cache commands to preserve containers and volumes. Remove stopped containers is a separate unchecked option; legacy custom system-prune commands are not used.")
                }
            }
        }

Controls.Button { text: i18n("Restore defaults"); icon.name: "edit-undo"; onClicked: { page.cfg_logsCommand = page.cfg_logsCommandDefault; page.cfg_logsFollowCommand = page.cfg_logsFollowCommandDefault; page.cfg_inspectCommand = page.cfg_inspectCommandDefault; page.cfg_imagesCommand = page.cfg_imagesCommandDefault; page.cfg_volumesCommand = page.cfg_volumesCommandDefault; page.cfg_networksCommand = page.cfg_networksCommandDefault; page.cfg_removeImageCommand = page.cfg_removeImageCommandDefault; page.cfg_removeVolumeCommand = page.cfg_removeVolumeCommandDefault; page.cfg_removeNetworkCommand = page.cfg_removeNetworkCommandDefault; page.cfg_composeCommand = page.cfg_composeCommandDefault; page.cfg_updateCheckCommand = page.cfg_updateCheckCommandDefault; page.cfg_contextListCommand = page.cfg_contextListCommandDefault; page.cfg_startCommand = page.cfg_startCommandDefault; page.cfg_stopServiceCommand = page.cfg_stopServiceCommandDefault; page.cfg_stopSocketCommand = page.cfg_stopSocketCommandDefault; page.cfg_pruneCommand = page.cfg_pruneCommandDefault } }
        }
    ColumnLayout {
        Layout.fillWidth: true
        visible: page.currentTab === 4
        spacing: Kirigami.Units.largeSpacing
        Kirigami.FormLayout {
            RowLayout {
                Kirigami.FormData.label: i18n("Saved profile:")
                Controls.ComboBox { id: selector; Layout.fillWidth: true; textRole: "name"; model: page.profileData.profiles }
                QuestionHelp {
                    helpText: i18n("Profiles save independent settings for a desktop, rootless engine or remote host, including connection, rules, pins, appearance and notifications. Changes are saved by Apply and discarded by Cancel.")
                }
            }
            RowLayout {
                Controls.Button { text: i18n("Load profile"); enabled: selector.currentIndex >= 0; onClicked: page.activate() }
                Controls.Button { text: i18n("Delete profile"); enabled: selector.currentIndex >= 0; onClicked: { var next = Profiles.load(page.cfg_profiles); next.profiles.splice(selector.currentIndex, 1); page.cfg_profiles = JSON.stringify(next) } }
            }
            Controls.TextField { id: profileName; Layout.fillWidth: true; Kirigami.FormData.label: i18n("Profile name:"); placeholderText: i18n("Home server") }
            Controls.Button { text: i18n("Save current settings as profile"); enabled: profileName.text.trim() !== ""; onClicked: page.saveProfile() }
        }
        Kirigami.Separator { Layout.fillWidth: true }
        RowLayout {
            Controls.CheckBox { text: i18n("Include custom commands in import/export"); checked: page.allowCommands; onToggled: page.allowCommands = checked }
            QuestionHelp { helpText: i18n("Commands can execute programs on your computer. Only include commands from files you trust. Cache data is excluded. Imported custom icon mappings need their artwork files copied separately.") }
        }
        RowLayout {
            Controls.Button { text: i18n("Export…"); icon.name: "document-export"; onClicked: exportFile.open() }
            Controls.Button { text: i18n("Import…"); icon.name: "document-import"; onClicked: importFile.open() }
        }
        Kirigami.InlineMessage { Layout.fillWidth: true; visible: page.status !== ""; text: page.status }
    }

        Kirigami.FormLayout {
        visible: page.currentTab === 5
        Layout.fillWidth: true
        Layout.maximumWidth: Kirigami.Units.gridUnit * 42
        Layout.alignment: Qt.AlignHCenter

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Dockmoid")
        }

        Controls.Label {
            Kirigami.FormData.label: i18n("Version:")
            text: "2.4.0"
        }
        Controls.Label {
            Kirigami.FormData.label: i18n("Platform:")
            text: i18n("KDE Plasma 6")
        }
        Controls.Label {
            Kirigami.FormData.label: i18n("Purpose:")
            text: i18n("Container status, monitoring and management from your panel.")
            wrapMode: Text.WordWrap
            Layout.maximumWidth: Kirigami.Units.gridUnit * 30
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Project:")
            Controls.Button {
                text: i18n("Source code")
                icon.name: "code-context"
                onClicked: Qt.openUrlExternally("https://github.com/deathrashed/dockmoid")
            }
            Controls.Button {
                text: i18n("Report an issue")
                icon.name: "tools-report-bug"
                onClicked: Qt.openUrlExternally("https://github.com/deathrashed/dockmoid/issues")
            }
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Connection diagnostics")
        }
        Controls.Label {
            text: i18n("Open Advanced → Connection, then choose Test connection. The check uses the unsaved engine and context fields and reports optional tools separately.")
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
            Layout.maximumWidth: Kirigami.Units.gridUnit * 34
        }
        Controls.Label {
            text: i18n("The report is shown locally in the settings page. Review it before sharing; custom command text is not included.")
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
            Layout.maximumWidth: Kirigami.Units.gridUnit * 34
            color: Kirigami.Theme.disabledTextColor
        }

    }

        Item {
            Layout.fillHeight: true
        }
    }
}
