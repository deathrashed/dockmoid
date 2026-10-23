pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Window

import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid

// Aliased relative directory imports: this is the form the QML engine
// resolves at runtime, and the only form qmllint can type-check.
import "Backend" as Backend
import "Views" as Views
import "components" as Components

PlasmoidItem {
    id: main

    Plasmoid.hasConfigurationInterface: true

    // Native keyboard activation toggles expansion; tray pointer clicks are
    // forwarded to Compact. Detached views bring their existing window forward.
    activationTogglesExpanded: true
    Plasmoid.onActivated: {
        if (main.detached) { main.expanded = false; detachedWindow.bringForward() }
    }

    readonly property var cfg: Plasmoid.configuration

    /*
     * The container list lives in the backend, not here, so the applet popup
     * and the detached window are two views onto exactly one set of data.
     *
     * QML ids are file scoped, so the views cannot see `dockerBackend` on their
     * own — it is handed to them as a property instead. That keeps the
     * dependency explicit rather than relying on ambient context.
     */
    readonly property var service: dockerBackend

    property bool detached: false
    property string lastStatusMessage: ""
    property bool notificationSupportInstalled: false

    readonly property bool viewOpen: main.detached || main.expanded

    // ========================================================= backend ====

    Backend.CommandRunner {
        id: commandRunner
        debug: main.cfg.debugCommands
    }

    Backend.DockerBackend {
        id: dockerBackend
        runner: commandRunner
        viewOpen: main.viewOpen

        onEngineStateChanged: function (active) {
            main.lastStatusMessage = active
                ? i18n("%1 is running", dockerBackend.engineName)
                : i18n("%1 is not running", dockerBackend.engineName)
            if (main.cfg.notifyOnEngineChange) {
                dockerBackend.notify(
                    dockerBackend.engineName,
                    active ? i18n("%1 is running", dockerBackend.engineName) : i18n("%1 is not running", dockerBackend.engineName)
                )
            }
        }
    }

    Backend.SharedSettings {
        id: sharedSettings
        cfg: main.cfg
        runner: commandRunner
        backend: dockerBackend
        instanceId: String(Plasmoid.id)
    }

    // ========================================================= timers ====

    Timer {
        id: pollTimer
        // A quick look for changes while the view is open, a relaxed one while
        // it is collapsed; either way it is a single cheap query.
        interval: Math.max(1, main.viewOpen ? main.cfg.changeCheckInterval
                                            : main.cfg.idleCheckInterval) * 1000
        repeat: true
        running: true
        triggeredOnStart: false
        onTriggered: { sharedSettings.check(); dockerBackend.tick() }
    }

    /*
     * `docker stats --no-stream` samples for a second or two, so it only runs
     * while somebody is actually looking at the list.
     */
    Timer {
        id: statsTimer
        // Pages that only show the status-bar totals sample less often.
        interval: Math.max(1, main.viewOpen && !dockerBackend.usageDetailShown
                              ? Math.max(main.cfg.usageInterval, main.cfg.usageQuietInterval)
                              : main.cfg.usageInterval) * 1000
        repeat: true
        running: main.viewOpen || main.cfg.statsWhenCollapsed
        triggeredOnStart: false
        onTriggered: {
            if (dockerBackend.engineActive && !dockerBackend.refreshing)
                dockerBackend.fetchStats()
        }
    }

    onExpandedChanged: function () {
        if (main.expanded) main.onViewOpened()
    }

    function onViewOpened() {
        sharedSettings.pull()
        if (!main.cfg.refreshOnExpand) return
        dockerBackend.refresh({
            "force": !dockerBackend.engineActive,
            "withStats": true,
            "withDisk": main.cfg.showDiskUsage
        })
    }

    function setDetached(value) {
        if (main.detached === value) return
        main.detached = value
        if (value) main.onViewOpened()
    }

    function toggleDetached() {
        main.setDetached(!main.detached)
    }

    /*
     * Panel click. When the view is detached, clicking the panel brings that
     * window back rather than opening a second copy of the same UI.
     */
    function toggleView() {
        if (main.detached) {
            detachedWindow.bringForward()
        } else {
            main.expanded = !main.expanded
        }
    }

    function openView() {
        if (main.detached) {
            detachedWindow.bringForward()
        } else {
            main.expanded = true
        }
    }

    // ======================================================= lifecycle ====

    Component.onCompleted: {
        if (main.cfg.listCommand === "{engine} ps --format json -a") main.cfg.listCommand = "{engine} ps --no-trunc --format json -a"
        main.lastStatusMessage = i18n("Checking %1…", dockerBackend.engineName)
        main.installNotificationSupport()
        main.installThemeIcon()
        sharedSettings.start()
        if (main.cfg.fetchOnStartup) startupTimer.start()
    }

    Timer {
        id: startupTimer
        interval: 400
        repeat: false
        onTriggered: dockerBackend.refresh({
            "withStats": main.cfg.statsWhenCollapsed,
            "withDisk": main.cfg.showDiskUsage
        })
    }

    /*
     * KDE needs a .notifyrc on disk before Notification can show anything, and
     * that file is not installed with the package, so it is written into the
     * user's notification directory. The version marker means it is rewritten
     * only when its content changes, not on every startup. Every line is
     * emitted inside single quotes and none of them contains a quote, so this
     * stays shell safe.
     *
     * One event per kind lets each be given its own sound or popup behaviour
     * under System Settings -> Notifications -> Dockmoid.
     */
    readonly property int notifyrcVersion: 4

    function installNotificationSupport() {
        if (main.notificationSupportInstalled) return
        main.notificationSupportInstalled = true
        var content = [
            "# dockmoid-notifyrc-v" + main.notifyrcVersion,
            "[Global]",
            "Name=Dockmoid",
            "Comment=Container and engine events",
            "IconName=dockmoid",
            "",
            "[Event/event]",
            "Name=Container action",
            "Comment=Result of a container or engine action",
            "Action=Popup",
            "",
            "[Event/crash]",
            "Name=Container crashed",
            "Comment=A container exited unexpectedly or is restarting in a loop",
            "Action=Popup|Sound",
            "Sound=dialog-warning-instant.oga",
            "",
            "[Event/unhealthy]",
            "Name=Container unhealthy",
            "Comment=A container failed its health check",
            "Action=Popup|Sound",
            "Sound=dialog-warning-instant.oga",
            "",
            "[Event/resource]",
            "Name=High resource use",
            "Comment=A container kept using a lot of CPU or memory",
            "Action=Popup",
            "",
            "[Event/probe]",
            "Name=Web page not answering",
            "Comment=A container stopped answering HTTP requests",
            "Action=Popup|Sound",
            "Sound=dialog-warning-instant.oga",
            "",
            "[Event/update]",
            "Name=Image update available",
            "Comment=A newer image exists in the registry",
            "Action=Popup"
        ]
        var dir = "\"${XDG_DATA_HOME:-$HOME/.local/share}/knotifications6\""
        var file = dir + "/dockmoid.notifyrc"
        var cmd = "mkdir -p " + dir + " && { grep -qs 'dockmoid-notifyrc-v" + main.notifyrcVersion
            + "' " + file + " || { rm -f " + file
        for (let i = 0; i < content.length; i++) {
            cmd += " && echo '" + content[i] + "' >> " + file
        }
        cmd += "; }; }"
        commandRunner.spawn(cmd)
    }

    /*
     * The Add Widgets dialog only shows an icon that lives in an icon theme, so
     * the package icon is copied into the user's hicolor theme the first time
     * the widget runs (install.sh does the same at install time).
     */
    function installThemeIcon() {
        var src = decodeURIComponent(String(Qt.resolvedUrl("../icons/dockmoid.png")).replace(/^file:\/\//, ""))
        if (!src || /[\x00-\x1f]/.test(src)) return
        var theme = "${XDG_DATA_HOME:-$HOME/.local/share}/icons/hicolor"
        var dir = theme + "/512x512/apps"
        commandRunner.spawn("mkdir -p \"" + dir + "\" && cp " + dockerBackend.shellQuote(src) + " \"" + dir
            + "/dockmoid.png\" && rm -f \"" + theme + "/scalable/apps/dockmoid.svg\" && { if command -v gtk-update-icon-cache >/dev/null 2>&1; then "
            + "gtk-update-icon-cache -f -t \"" + theme + "\"; fi; }")
    }

    // ================================================== representations ====

    Component {
        id: popupComponent
        Views.PopupView {
            backend: dockerBackend
            applet: main
        }
    }

    Component {
        id: detachedPlaceholderComponent
        Views.DetachedPlaceholder {
            backend: dockerBackend
            applet: main
        }
    }

    /*
     * Only one view instance exists at a time: while the window is detached the
     * applet popup shows a small "reopen" card instead of a second full UI.
     */
    fullRepresentation: Loader {
        id: popupLoader
        Layout.minimumWidth: Kirigami.Units.gridUnit * 22
        Layout.minimumHeight: Kirigami.Units.gridUnit * 14
        // Plasma clamps these to the current screen and persists drag resizing.
        // The former 40-unit height cap prevented taller attached popups.
        Layout.maximumWidth: 16777215
        Layout.maximumHeight: 16777215
        Layout.preferredWidth: Math.max(Kirigami.Units.gridUnit * 22, main.cfg.popupWidth)
        Layout.preferredHeight: Math.max(Kirigami.Units.gridUnit * 14, main.cfg.popupHeight)
        sourceComponent: main.detached ? detachedPlaceholderComponent : popupComponent
        Components.PopupResizeHandles {
            anchors.fill: parent
            z: 1000
            visible: !main.detached && Plasmoid.formFactor !== PlasmaCore.Types.Planar
        }
        Connections {
            target: main.cfg
            function onPopupWidthChanged() {
                if (!main.detached && popupLoader.Window.window)
                    popupLoader.Window.window.width = Math.max(popupLoader.Layout.minimumWidth, main.cfg.popupWidth)
            }
            function onPopupHeightChanged() {
                if (!main.detached && popupLoader.Window.window)
                    popupLoader.Window.window.height = Math.max(popupLoader.Layout.minimumHeight, main.cfg.popupHeight)
            }
        }
    }

    Views.DetachedWindow {
        id: detachedWindow
        visible: main.detached
        contentComponent: popupComponent
        // viewTitle intentionally left at DetachedWindow's own default: there is
        // no QML-accessible property holding the plugin name (Plasmoid exposes
        // status and formFactor, but no name).
        onClosing: function (close) {
            // Visibility is driven by the `detached` flag, so veto the
            // window's own close and let the binding do the work.
            close.accepted = false
            main.setDetached(false)
        }
    }

    // Plasma instantiates the compact representation itself, so unlike the
    // views below it does NOT inherit anything from this file's scope. The
    // required properties have to be handed over explicitly or Compact fails
    // to construct and the panel shows nothing at all.
    compactRepresentation: Compact {
        backend: dockerBackend
        applet: main
    }

    // The tray owns popup selection. A forced compact representation prevents
    // SystemTrayState.setActiveApplet() from opening its shared popup.
    // Only desktop instances require a permanently full representation.
    preferredRepresentation: Plasmoid.formFactor === PlasmaCore.Types.Planar
        ? fullRepresentation : null

    toolTipMainText: i18n("Dockmoid")
    toolTipSubText: dockerBackend.engineActive
        ? i18n("%1 running · %2 stopped · %3 total", dockerBackend.running, dockerBackend.stopped, dockerBackend.total)
        : (dockerBackend.engineKnown ? i18n("Container engine unavailable") : i18n("Connecting to container engine…"))

    toolTipItem: Loader {
        id: tooltipLoader
    /*
     * The Loader is created before its item exists, so the sizing bindings must
     * tolerate `item` being undefined: reading implicitSize off null threw
     * "Cannot read property 'width/height' of undefined" on every popup.
     */
    readonly property Item tooltipContent: item as Item
    readonly property size tooltipItemSize: tooltipContent ? Qt.size(tooltipContent.implicitWidth, tooltipContent.implicitHeight) : Qt.size(0, 0)
        Layout.minimumWidth: tooltipItemSize.width
        Layout.maximumWidth: tooltipItemSize.width
        Layout.minimumHeight: tooltipItemSize.height
        Layout.maximumHeight: tooltipItemSize.height
        sourceComponent: Tooltip { backend: dockerBackend; detached: main.detached }
    }

    // ============================================================= menu ====

    Plasmoid.status: {
        if (main.cfg.hideWhenInactive && dockerBackend.engineKnown && !dockerBackend.engineActive) {
            return PlasmaCore.Types.HiddenStatus
        }
        if (!dockerBackend.engineActive) return PlasmaCore.Types.PassiveStatus
        return PlasmaCore.Types.ActiveStatus
    }

    function configure() {
        var action = Plasmoid.internalAction("configure")
        if (action) action.trigger()
    }

    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: i18n("Refresh")
            icon.name: "view-refresh"
            onTriggered: dockerBackend.refresh({
                "force": true,
                "withStats": true,
                "withDisk": main.cfg.showDiskUsage
            })
        },
        PlasmaCore.Action {
            text: main.detached ? i18n("Reattach View") : i18n("Detach View")
            icon.name: main.detached ? "window-restore" : "window-pin"
            onTriggered: main.toggleDetached()
        },
        PlasmaCore.Action {
            text: i18n("Start %1", dockerBackend.engineName)
            icon.name: "media-playback-start"
            visible: !dockerBackend.engineActive && dockerBackend.canControlService && !dockerBackend.readOnly
            onTriggered: dockerBackend.startEngine()
        },
        PlasmaCore.Action {
            text: i18n("Stop %1", dockerBackend.engineName)
            icon.name: "media-playback-stop"
            visible: dockerBackend.engineActive && dockerBackend.canControlService && !dockerBackend.readOnly
            onTriggered: dockerBackend.stopEngine()
        }
    ]
}
