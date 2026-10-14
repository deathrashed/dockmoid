pragma ComponentBehavior: Bound

import QtQuick

import org.kde.kquickcontrolsaddons as KQuickControlsAddons
import org.kde.plasma.components as PlasmaComponents

import "../../lib/parsers.js" as Parsers

/*
 * ContainerActions — the per-container overflow menu.
 *
 * One implementation shared by the row delegate, the table delegate and the
 * detail page, so a feature is never available in one view and missing from
 * another.
 *
 * The entries are built imperatively rather than declared, for two reasons
 * that both bite hard if you declare them instead:
 *
 *  1. A Qt Quick Controls Menu lays out a ListView keyed on the count of
 *     declared children. `visible: false` removes an item's glyph but leaves its
 *     row behind, which is what put blank gaps down the menu whenever the
 *     container's state made an entry irrelevant. Creating only the entries
 *     that apply removes the gaps at the source. (A Repeater inside a Menu does
 *     not work either — same ListView reason.)
 *
 *  2. The shell and published-port groups are variable-length, so they have to
 *     be created at runtime regardless. Making the whole menu follow the same
 *     path keeps one mechanism instead of two.
 */
PlasmaComponents.Menu {
    id: root

    required property var backend
    required property var record
    required property var dialogs
    property bool browserOnly: false

    signal openDetail(string recordId)
    signal openOutput(string title, string content, bool live, string recordId)

    readonly property var links: root.backend.linksFor(root.record)

    // ============================================================= items ====

    /*
     * A menu entry is a MenuItem carrying its own label, glyph and callback.
     * Declared inline as a Component so every entry created below is identical.
     */
    Component {
        id: menuItemTemplate
        PlasmaComponents.MenuItem {
            property string label: ""
            property string glyph: ""
            property string artwork: ""
            // `action` is a final member of QQuickAbstractButton, so the
            // callback is called `run` instead of shadowing it.
            property var run: null
            text: label
            icon.name: artwork === "" ? glyph : ""
            icon.source: artwork
            onTriggered: if (run) run()
        }
    }

    Component {
        id: menuSeparatorTemplate
        PlasmaComponents.MenuSeparator {}
    }

    Component {
        id: submenuTemplate
        PlasmaComponents.Menu {
            property bool isSubmenu: true
            property string glyph: "internet-web-browser"
            icon.name: glyph
        }
    }

    /* Everything this menu owns, so rebuild() can tear it all down cleanly. */
    property var entries: []

    function clearEntries() {
        for (var i = 0; i < root.entries.length; i++) {
            if (!root.entries[i]) continue
            if (root.entries[i].isSubmenu) root.removeMenu(root.entries[i])
            else root.removeItem(root.entries[i])
            root.entries[i].destroy()
        }
        root.entries = []
    }

    function addEntry(label, glyph, action, artwork) {
        var item = menuItemTemplate.createObject(root)
        if (!item) return
        item.label = label
        item.glyph = glyph
        item.artwork = artwork || ""
        item.run = action
        root.addItem(item)
        root.entries.push(item)
    }

    function addSeparator() {
        var sep = menuSeparatorTemplate.createObject(root)
        if (sep) {
            root.addItem(sep)
            root.entries.push(sep)
        }
    }

    function addBrowserEntries(menu, rec) {
        var browserLinks = root.backend.linksFor(rec)
        if (browserLinks.length === 0) {
            var empty = menuItemTemplate.createObject(menu)
            empty.label = i18n("No published web addresses")
            empty.enabled = false
            menu.addItem(empty)
            if (menu === root) root.entries.push(empty)
            return
        }
        for (var l = 0; l < browserLinks.length; l++) {
            let link = browserLinks[l]
            let address = link.host + ":" + link.port
            var open = menuItemTemplate.createObject(menu)
            open.label = i18n("Open %1", address)
            open.glyph = "internet-web-browser"
            open.run = function () { root.backend.openLink(link) }
            menu.addItem(open)
            if (menu === root) root.entries.push(open)
            var copy = menuItemTemplate.createObject(menu)
            copy.label = i18n("Copy URL %1", address)
            copy.glyph = "edit-copy"
            copy.run = function () { clipboard.content = Parsers.linkUrl(link) }
            menu.addItem(copy)
            if (menu === root) root.entries.push(copy)
        }
    }

    function addLauncherEntry(menu, launcher, rec) {
        var item = menuItemTemplate.createObject(menu)
        item.label = launcher.label
        item.glyph = launcher.icon !== "" ? launcher.icon : "document-open"
        item.run = function () { root.backend.launch(rec, launcher) }
        menu.addItem(item)
    }

    /* What Docker does with this container when the daemon (re)starts. */
    function addRestartPolicyMenu(rec) {
        var menu = submenuTemplate.createObject(root)
        menu.title = i18n("Start automatically")
        menu.glyph = "media-playlist-repeat"
        var policies = ["no", "on-failure", "unless-stopped", "always"]
        for (var i = 0; i < policies.length; i++) {
            let policy = policies[i]
            var item = menuItemTemplate.createObject(menu)
            var current = rec.restartPolicy === policy
            item.label = (current ? "● " : "    ") + root.backend.policyLabel(policy)
            item.glyph = ""
            item.enabled = !current
            item.run = function () { root.backend.setRestartPolicy(rec, policy) }
            menu.addItem(item)
        }
        root.addMenu(menu)
        root.entries.push(menu)
    }

    /* Everything a Compose project can do as a whole. */
    function addComposeMenu(rec) {
        var menu = submenuTemplate.createObject(root)
        menu.title = i18n("Compose project “%1”", rec.project)
        menu.glyph = "folder"
        var verbs = [
            ["up", i18n("Up (create and start)"), "media-playback-start", false],
            ["pull", i18n("Pull images"), "system-download", false],
            ["update", i18n("Pull and recreate"), "package-upgrade", false],
            ["recreate", i18n("Force recreate"), "view-refresh", false],
            ["down", i18n("Down (remove containers)"), "edit-delete", true]
        ]
        for (var i = 0; i < verbs.length; i++) {
            let v = verbs[i]
            var item = menuItemTemplate.createObject(menu)
            item.label = v[1]
            item.glyph = v[2]
            item.run = function () { root.runCompose(rec, v[0], v[3]) }
            menu.addItem(item)
        }
        root.addMenu(menu)
        root.entries.push(menu)
    }

    function runCompose(rec, verb, destructive) {
        var go = function () {
            root.openOutput(i18n("Compose %1 — %2", verb, rec.project), i18n("Starting…"), false, rec.id)
            root.backend.composeRun(rec, verb, rec.project)
        }
        if (destructive) {
            root.dialogs.confirm(i18n("Take down %1?", rec.project),
                i18n("Every container in this Compose project is stopped and removed, and its networks too. Volumes are kept."), go)
        } else {
            go()
        }
    }

    // ============================================================= build ====

    function rebuild() {
        clearEntries()
        var rec = root.record
        if (!rec || !rec.id) return

        if (root.browserOnly) {
            addBrowserEntries(root, rec)
            return
        }

        var state = String(rec.state || "")
        var running = rec.isRunning === true

        addEntry(i18n("Details"), "document-view", function () { root.openDetail(rec.id) })

        if (rec.updateAvailable) {
            addEntry(i18n("Update image and recreate"), "package-upgrade", function () {
                if (rec.project !== "") root.openOutput(i18n("Compose update — %1", rec.project), i18n("Starting…"), false, rec.id)
                root.backend.updateContainer(rec)
            })
            addSeparator()
        }

        if (Parsers.canStart(state)) {
            addEntry(i18n("Start"), "media-playback-start", function () { root.backend.startContainer(rec) })
        }
        if (Parsers.canStop(state)) {
            addEntry(i18n("Stop"), "media-playback-stop", function () { root.backend.stopContainer(rec) })
        }
        if (running || state === "exited") {
            addEntry(i18n("Restart"), "view-refresh", function () { root.backend.restartContainer(rec) })
        }

        /* Only draw the separator when something follows it that can appear. */
        if (Parsers.canPause(state) || Parsers.canUnpause(state) || running || state === "paused") {
            addSeparator()
        }

        if (Parsers.canPause(state)) {
            addEntry(i18n("Pause"), "media-playback-pause", function () { root.backend.pauseContainer(rec) })
        }
        if (Parsers.canUnpause(state)) {
            addEntry(i18n("Unpause"), "media-playback-start", function () { root.backend.unpauseContainer(rec) })
        }
        if (running || state === "paused") {
            addEntry(i18n("Kill"), "media-record", function () { root.backend.killContainer(rec) })
        }

        addSeparator()

        var apps = root.backend.launchersFor(rec)
        if (apps.length > 0) {
            var openInMenu = submenuTemplate.createObject(root)
            openInMenu.title = i18n("Open in")
            openInMenu.glyph = "document-open"
            for (var n = 0; n < apps.length; n++) addLauncherEntry(openInMenu, apps[n], rec)
            root.addMenu(openInMenu)
            root.entries.push(openInMenu)
        }

        addEntry(i18n("Follow Logs in Terminal"), "text-x-log", function () { root.backend.followLogs(rec) })
        addEntry(i18n("View Logs"), "text-x-generic", function () {
            root.backend.fetchLogs(rec, plasmoid.configuration.logTailLines)
            root.openOutput(root.backend.logsTitle(rec), i18n("Loading…"), true, rec.id)
        })

        addSeparator()

        addEntry(i18n("Pull Image"), "system-download", function () {
            root.backend.pullImage(rec)
            root.openOutput(i18n("Pulling %1", rec.image), i18n("Starting…"), false, rec.id)
        })
        addEntry(i18n("Rename"), "edit-rename", function () { root.dialogs.promptRename(rec) })
        addEntry(rec.pinned ? i18n("Unpin") : i18n("Pin to top"), rec.pinned ? "window-unpin" : "window-pin",
                 function () { root.backend.togglePin(rec) })
        if (rec.pinned) {
            addEntry(i18n("Move up in pinned"), "go-up", function () { root.backend.movePin(rec, -1) })
            addEntry(i18n("Move down in pinned"), "go-down", function () { root.backend.movePin(rec, 1) })
        }
        if (rec.project !== "") addComposeMenu(rec)
        if (rec.restartPolicy !== undefined && rec.restartPolicy !== "") addRestartPolicyMenu(rec)
        if (rec.composeFiles !== "") {
            addEntry(i18n("Edit Compose File"), "document-edit", function () { root.backend.editCompose(rec) })
        }
        addEntry(i18n("Inspect"), "utilities-system-monitor", function () {
            root.backend.fetchInspect(rec)
            root.openOutput(i18n("Inspect — %1", rec.name), i18n("Loading…"), false, rec.id)
        })

        if (running && root.backend.linksFor(rec).length > 0) {
            var linksMenu = submenuTemplate.createObject(root)
            linksMenu.title = i18n("Web links")
            addBrowserEntries(linksMenu, rec)
            root.addMenu(linksMenu)
            root.entries.push(linksMenu)
        }

        addSeparator()

        addEntry(i18n("Copy Name"), "edit-copy", function () { clipboard.content = rec.name })
        addEntry(i18n("Copy ID"), "edit-copy", function () { clipboard.content = rec.id })
        addEntry(i18n("Copy Image"), "edit-copy", function () { clipboard.content = rec.image })
        addEntry(i18n("Remove"), "edit-delete", function () { root.dialogs.confirmRemove(rec) })
    }

    /*
     * Rebuild whenever the menu is about to be shown: the delegate is reused by
     * the view, so without this a menu can describe whichever container last
     * occupied it.
     */
    onVisibleChanged: if (visible) root.rebuild()

    Connections {
        target: root.backend
        function onRefreshed() {
            if (!root.visible) return
            var current = root.record ? root.record.id : ""
            if (current === "") return
            var fresh = root.backend.findRecord(current)
            if (fresh) root.record = fresh
        }
    }

    KQuickControlsAddons.Clipboard {
        id: clipboard
    }

    Component.onCompleted: root.rebuild()
}
