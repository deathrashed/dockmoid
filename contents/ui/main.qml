pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid

// Aliased relative directory imports: this is the form the QML engine
// resolves at runtime, and the only form qmllint can type-check.
import "Backend" as Backend
import "Views" as Views

PlasmoidItem {
    id: main

    readonly property var cfg: plasmoid.configuration

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

        onEngineStateChanged: function (active) {
            main.lastStatusMessage = active
                ? i18n("Docker is running")
                : i18n("Docker is not running")
            if (main.cfg.notifyOnEngineChange) {
                dockerBackend.notify(
                    i18n("Docker"),
                    active ? i18n("Docker is running") : i18n("Docker is not running")
                )
            }
        }
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
        onTriggered: dockerBackend.tick()
    }

    /*
     * `docker stats --no-stream` samples for a second or two, so it only runs
     * while somebody is actually looking at the list.
     */
    Timer {
        id: statsTimer
        interval: Math.max(1, main.cfg.usageInterval) * 1000
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
            detachedWindow.raise()
            detachedWindow.requestActivate()
        } else {
            main.expanded = !main.expanded
        }
    }

    // ======================================================= lifecycle ====

    Component.onCompleted: {
        main.lastStatusMessage = i18n("Checking Docker…")
        main.installNotificationSupport()
        main.installThemeIcon()
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
    readonly property int notifyrcVersion: 3

    function installNotificationSupport() {
        if (main.notificationSupportInstalled) return
        main.notificationSupportInstalled = true
        var content = [
            "# dockmoid-notifyrc-v" + main.notifyrcVersion,
            "[Global]",
            "Name=Dockmoid",
            "Comment=Container and engine events",
            "IconName=docker",
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
        var dir = "~/.local/share/knotifications6"
        var file = dir + "/dockmoid.notifyrc"
        var cmd = "mkdir -p " + dir + " && { grep -qs 'dockmoid-notifyrc-v" + main.notifyrcVersion
            + "' " + file + " || { rm -f " + file
        for (var i = 0; i < content.length; i++) {
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
        var src = String(Qt.resolvedUrl("../../docs/assets/icon.png")).replace(/^file:\/\//, "")
        if (!/^[\/A-Za-z0-9._~ -]+$/.test(src)) return
        var theme = "${XDG_DATA_HOME:-$HOME/.local/share}/icons/hicolor"
        var dir = theme + "/512x512/apps"
        commandRunner.spawn("mkdir -p \"" + dir + "\" && cp '" + src + "' \"" + dir
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
        Layout.minimumWidth: Kirigami.Units.gridUnit * 22
        Layout.minimumHeight: Kirigami.Units.gridUnit * 14
        Layout.maximumWidth: Kirigami.Units.gridUnit * 70
        Layout.maximumHeight: Kirigami.Units.gridUnit * 40
        sourceComponent: main.detached ? detachedPlaceholderComponent : popupComponent
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

    // On the desktop there is no panel to collapse into, so show the full view.
    preferredRepresentation: Plasmoid.formFactor === PlasmaCore.Types.Planar
        ? fullRepresentation : compactRepresentation

    toolTipMainText: i18n("Dockmoid")
    toolTipSubText: main.lastStatusMessage

    toolTipItem: Loader {
        id: tooltipLoader
    /*
     * The Loader is created before its item exists, so the sizing bindings must
     * tolerate `item` being undefined: reading implicitSize off null threw
     * "Cannot read property 'width/height' of undefined" on every popup.
     */
    readonly property var tooltipItemSize: (item && item.implicitSize)
            ? item.implicitSize
            : Qt.size(0, 0)
        Layout.minimumWidth: tooltipItemSize.width
        Layout.maximumWidth: tooltipItemSize.width
        Layout.minimumHeight: tooltipItemSize.height
        Layout.maximumHeight: tooltipItemSize.height
        sourceComponent: Tooltip { backend: dockerBackend }
    }

    // ============================================================= menu ====

    Plasmoid.status: {
        if (main.cfg.hideWhenInactive && dockerBackend.engineKnown && !dockerBackend.engineActive) {
            return PlasmaCore.Types.HiddenStatus
        }
        if (!dockerBackend.engineActive) return PlasmaCore.Types.PassiveStatus
        return PlasmaCore.Types.ActiveStatus
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
            text: i18n("Start Docker")
            icon.name: "media-playback-start"
            visible: !dockerBackend.engineActive
            onTriggered: dockerBackend.startEngine()
        },
        PlasmaCore.Action {
            text: i18n("Stop Docker")
            icon.name: "media-playback-stop"
            visible: dockerBackend.engineActive
            onTriggered: dockerBackend.stopEngine()
        }
    ]
}
