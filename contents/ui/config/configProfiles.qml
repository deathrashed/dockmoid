import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import "../Backend" as Backend
import "../../lib/profiles.js" as Profiles

KCM.SimpleKCM {
    id: page
    property string cfg_engineCommand
    property string cfg_eventsCommand
    property int cfg_updateInterval
    property int cfg_changeCheckInterval
    property int cfg_idleCheckInterval
    property int cfg_usageInterval
    property int cfg_logTailLines
    property string cfg_checkActiveCommand
    property string cfg_listCommand
    property string cfg_usageCommand
    property string cfg_infoCommand
    property string cfg_systemDfCommand
    property string cfg_startOneCommand
    property string cfg_stopOneCommand
    property string cfg_restartOneCommand
    property string cfg_killOneCommand
    property string cfg_pauseOneCommand
    property string cfg_unpauseOneCommand
    property string cfg_removeOneCommand
    property string cfg_renameOneCommand
    property string cfg_pullImageCommand
    property string cfg_logsCommand
    property string cfg_logsFollowCommand
    property string cfg_shellCommand
    property string cfg_inspectCommand
    property string cfg_groupStartCommand
    property string cfg_groupStopCommand
    property string cfg_groupRestartCommand
    property string cfg_startCommand
    property string cfg_stopServiceCommand
    property string cfg_stopSocketCommand
    property string cfg_imagesCommand
    property string cfg_volumesCommand
    property string cfg_networksCommand
    property string cfg_removeImageCommand
    property string cfg_removeVolumeCommand
    property string cfg_removeNetworkCommand
    property string cfg_composeCommand
    property string cfg_updateCheckCommand
    property string cfg_contextListCommand
    property string cfg_restartPolicyCommand
    property string cfg_setRestartPolicyCommand
    property string cfg_pruneCommand
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
    property string cfg_activeContext
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
        spacing: Kirigami.Units.largeSpacing
        Kirigami.InlineMessage { Layout.fillWidth: true; visible: true; text: i18n("Save independent settings for your desktop, rootless engine or remote host. Profiles preserve connection, rules, pins, appearance and notifications. Changes follow Apply and Cancel.") }
        Kirigami.FormLayout {
            Controls.ComboBox { id: selector; Layout.fillWidth: true; Kirigami.FormData.label: i18n("Saved profile:"); textRole: "name"; model: page.profileData.profiles }
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
}
