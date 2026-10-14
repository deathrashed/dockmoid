pragma ComponentBehavior: Bound

import QtQuick
import org.kde.kirigami as Kirigami

import org.kde.kquickcontrolsaddons as KQuickControlsAddons
import org.kde.plasma.components as PlasmaComponents

import "../../lib/parsers.js" as Parsers
import "../../lib/actionIcons.js" as ActionIcons

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
    delegate: ActionMenuDelegate { width: parent ? parent.width : implicitWidth }

    required property var backend
    required property var record
    required property var dialogs
    property bool browserOnly: false
    /* Empty means the complete menu; Details can open one shared section. */
    property string sectionOnly: ""
    property var excludedActions: []
    function isExcluded(label, key) {
        if (root.sectionOnly !== "") return false
        const normalized = String(label).toLowerCase().replace(/…|\.\.\./g, "").trim()
        const canonical = normalized === "inspect json" ? "inspect" : normalized === "run command" ? "run" : normalized
        return root.excludedActions.indexOf(key || canonical) >= 0
    }

    signal openDetail(string recordId)
    signal openOutput(string title, string content, bool live, string recordId)

    readonly property var links: root.backend.linksFor(root.record)

    function popupSection(section, anchor) {
        root.sectionOnly = section || ""
        root.rebuild()
        root.popup(anchor, 0, anchor.height)
    }

    /* Shared entry points for actions shown directly in the detail header.
       Keep state and read-only decisions here so the buttons and overflow
       menu follow the same rules. */
    function canPerform(action) {
        var rec = root.record
        if (!rec || !rec.id) return false
        var state = String(rec.state || "")
        if (action === "logs" || action === "inspect") return state !== "not-created"
        if (action === "start-stop")
            return !root.backend.readOnly && (Parsers.canStop(state) || Parsers.canStart(state))
        if (action === "start") return !root.backend.readOnly && Parsers.canStart(state)
        if (action === "stop") return !root.backend.readOnly && Parsers.canStop(state)
        if (action === "restart")
            return !root.backend.readOnly && (rec.isRunning === true || state === "exited")
        return false
    }

    function perform(action) {
        if (!root.canPerform(action)) return
        var rec = root.record
        if (action === "start-stop") {
            root.perform(Parsers.canStop(String(rec.state || "")) ? "stop" : "start")
        } else if (action === "start") {
            root.backend.startContainer(rec)
        } else if (action === "stop") {
            root.backend.stopContainer(rec)
        } else if (action === "restart") {
            root.backend.restartContainer(rec)
        } else if (action === "logs") {
            root.backend.newOutputRequest("logs", rec.id)
            root.openOutput(root.backend.logsTitle(rec), i18n("Loading…"), true, rec.id)
        } else if (action === "inspect") {
            root.showInspect(rec)
        }
    }

    // ============================================================= items ====

    /*
     * A menu entry is a MenuItem carrying its own label, glyph and callback.
     * Declared inline as a Component so every entry created below is identical.
     */
    component ActionMenuItem: ActionMenuDelegate {
        property bool isSectionHeader: false
        property string label: ""
        property string glyph: ""
        property string artwork: ""
        property string detail: ""
        PlasmaComponents.ToolTip { visible: hovered && detail !== ""; text: detail }
        property var run: null
        text: label
        icon.name: ""
        icon.source: artwork !== "" ? artwork : glyph !== "" ? Qt.resolvedUrl(ActionIcons.path(glyph)) : ""
        icon.color: Kirigami.Theme.textColor
        icon.width: Kirigami.Units.iconSizes.smallMedium
        icon.height: Kirigami.Units.iconSizes.smallMedium
        onTriggered: if (run) run()
    }
    Component { id: menuItemTemplate; ActionMenuItem {} }

    Component {
        id: menuSeparatorTemplate
        PlasmaComponents.MenuSeparator {}
    }

    component ActionMenu: PlasmaComponents.Menu {
        delegate: ActionMenuDelegate { width: parent ? parent.width : implicitWidth }
        property bool isSubmenu: true
        property string glyph: "internet-web-browser"
        icon.name: ""
        icon.source: Qt.resolvedUrl(ActionIcons.path(glyph))
        icon.color: Kirigami.Theme.textColor
        icon.width: Kirigami.Units.iconSizes.smallMedium
        icon.height: Kirigami.Units.iconSizes.smallMedium
    }
    Component { id: submenuTemplate; ActionMenu {} }

    /* Everything this menu owns, so rebuild() can tear it all down cleanly. */
    property var entries: []

    function clearEntries() {
        for (let i = 0; i < root.entries.length; i++) {
            if (!root.entries[i]) continue
            if (root.entries[i].isSubmenu) root.removeMenu(root.entries[i])
            else root.removeItem(root.entries[i])
            root.entries[i].destroy()
        }
        root.entries = []
    }

    function addEntry(label, glyph, action, artwork) {
        if (root.isExcluded(label)) return
        var item = menuItemTemplate.createObject(root.contentItem) as ActionMenuItem
        if (!item) return
        item.label = label
        item.glyph = glyph
        item.artwork = artwork || ""
        item.run = action
        root.addItem(item)
        root.entries.push(item)
    }

    function addHeading(label, parentMenu) {
        const menu = parentMenu || root
        const item = menuItemTemplate.createObject(menu.contentItem) as ActionMenuItem
        if (!item) return
        item.label = label
        item.enabled = false
        item.isSectionHeader = true
        menu.addItem(item)
        if (menu === root) root.entries.push(item)
    }

    function addSeparator(parentMenu) {
        var menu = parentMenu || root
        var sep = menuSeparatorTemplate.createObject(menu.contentItem)
        if (sep) {
            menu.addItem(sep)
            if (menu === root) root.entries.push(sep)
        }
    }

    function makeSubmenu(parentMenu, label, glyph, section) {
        if (parentMenu === root && root.isExcluded(label, section)) return null
        if (parentMenu === root && section && root.sectionOnly === section) return root
        var menu = submenuTemplate.createObject(parentMenu, { title: label, glyph: glyph }) as ActionMenu
        if (!menu) return null
        parentMenu.addMenu(menu)
        if (parentMenu === root) root.entries.push(menu)
        return menu
    }

    function addToMenu(menu, label, glyph, action, enabled) {
        if (!menu || root.isExcluded(label)) return null
        var item = menuItemTemplate.createObject(menu.contentItem) as ActionMenuItem
        if (!item) return
        item.label = label
        item.glyph = glyph
        item.run = action
        if (enabled !== undefined) item.enabled = enabled
        menu.addItem(item)
        if (menu === root) root.entries.push(item)
        return item
    }

    function addBrowserEntries(menu: PlasmaComponents.Menu, rec: var) {
        const links = root.backend.linksFor(rec)
        const all = root.backend.allLinksFor(rec)
        if (links.length === 0) addToMenu(menu, all.length ? i18n("All browser ports are hidden") : i18n("No published web addresses"), "insert-link", function(){}, false)
        links.forEach(function(link) {
            const item = addToMenu(menu, link.title || i18n("Web UI · %1", link.label), "insert-link", function() { root.backend.openLink(link) })
            if (item) item.detail = link.url || Parsers.linkUrl(link)
        })
        if (!all.length) return
        addSeparator(menu)
        const copy = links.length ? makeSubmenu(menu, i18n("Copy web address"), "edit-copy") : null
        if (copy) links.forEach(function(link) { addToMenu(copy, link.title, "edit-copy", function() { clipboard.content = link.url }) })
        const preferred = makeSubmenu(menu, i18n("Preferred link"), "bookmark")
        if (preferred) {
            const current = root.backend.browserSettings(root.backend.cfg.preferredBrowserLinks)[root.backend.browserKey(rec)] || ""
            all.forEach(function(link) {
                const item = addToMenu(preferred, link.title, "insert-link", function() { root.backend.preferBrowserLink(rec, link) })
                if (item) { item.checkable = true; item.checked = link.url === current; item.detail = link.url }
            })
        }
        const ports = makeSubmenu(menu, i18n("Visible browser ports"), "configure")
        const seen = {}
        if (ports) all.forEach(function(link) {
            if (seen[link.port]) return
            seen[link.port] = true
            const visible = root.backend.browserPortVisible(rec, link.port)
            const item = addToMenu(ports, String(link.port), "insert-link", function() { root.backend.showBrowserPort(rec, link.port, !visible) })
            if (item) { item.checkable = true; item.checked = visible }
        })
    }

    function addLauncherEntry(menu: PlasmaComponents.Menu, launcher: var, rec: var) {
        var item = menuItemTemplate.createObject(menu.contentItem) as ActionMenuItem
        item.label = launcher.label
        item.glyph = launcher.scope === "container" ? "utilities-terminal" : "document-open"
        item.nativeIconName = launcher.icon || ""
        item.run = function () { root.backend.launch(rec, launcher) }
        menu.addItem(item)
        if (menu === root) root.entries.push(item)
    }

    function addCopyMenu(rec) {
        var menu = makeSubmenu(root, i18n("Copy"), "edit-copy", "copy")
        if (!menu) return
        var values = [[i18n("Name"), rec.name, "copy-name"], [i18n("Container ID"), rec.id, "copy-id"], [i18n("Image"), rec.image, "copy-image"]]
        if (rec.project) values.push([i18n("Project"), rec.project, "copy-project"])
        if (rec.service) values.push([i18n("Service"), rec.service, "copy-service"])
        if (rec.composeFiles) values.push([i18n("Compose file path"), rec.composeFiles, "copy-compose"])
        for (let i = 0; i < values.length; i++) {
            let value = values[i]
            let item = menuItemTemplate.createObject(menu.contentItem) as ActionMenuItem
            item.label = value[0]
            item.glyph = value[2]
            item.run = function () { clipboard.content = value[1] }
            menu.addItem(item)
            if (menu === root) root.entries.push(item)
        }
    }

    /* Everything a Compose project can do as a whole. */
    function addComposeMenu(rec) {
        var menu = makeSubmenu(root, i18n("Compose"), "docker", "compose")
        if (!menu) return
        var verbs = [
            ["ps", i18n("Status"), "view-list-details", false],
            ["logs", i18n("Project logs"), "text-x-generic", false],
            ["up", i18n("Start"), "media-playback-start", false],
            ["restart", i18n("Restart"), "view-refresh", false],
            ["stop", i18n("Stop"), "media-playback-stop", false],
            ["pull", i18n("Pull images"), "system-download", false],
            ["update", i18n("Update and start"), "package-upgrade", false],
            ["recreate", i18n("Recreate and start"), "media-playlist-repeat", false],
            ["down", i18n("Remove project…"), "edit-delete", true]
        ]
        for (let i = 0; i < verbs.length; i++) {
            let v = verbs[i]
            if (i === 2 || i === 5 || i === 8) addSeparator(menu)
            if (i === 0) addHeading(i18n("Inspection"),menu)
            if (i === 2) addHeading(i18n("Lifecycle"),menu)
            if (i === 5) addHeading(i18n("Images"),menu)
            if (i === 8) addHeading(i18n("Removal"),menu)
            let item = menuItemTemplate.createObject(menu.contentItem) as ActionMenuItem
            item.label = v[1]
            item.glyph = v[2]
            item.run = function () { root.runCompose(rec, v[0], v[3]) }
            menu.addItem(item)
            if (menu === root) root.entries.push(item)
        }
        addSeparator(menu)
        if (rec.composeFiles !== "") addToMenu(menu, i18n("Edit Compose file…"), "document-edit", function () { root.backend.editCompose(rec) })
    }

    function composeLabel(verb) {
        return ({ps:i18n("Project status"),logs:i18n("Project logs"),up:i18n("Start project"),restart:i18n("Restart project"),stop:i18n("Stop project"),pull:i18n("Pull images"),update:i18n("Update project"),recreate:i18n("Recreate project"),down:i18n("Remove project")})[verb] || i18n("Compose")
    }

    function showInspect(rec) {
        var generation = root.backend.generation
        var requestId = root.backend.newOutputRequest("inspect", rec.id)
        root.openOutput(i18n("Inspect — %1", rec.name), i18n("Loading…"), false, rec.id)
        root.backend.fetchInspect(rec, requestId, generation)
    }

    function runCompose(rec, verb, destructive) {
        var go = function () {
            var generation = root.backend.generation
            var requestId = root.backend.newOutputRequest("compose", rec.id)
            root.openOutput(i18n("%1 · %2", root.composeLabel(verb), rec.project), i18n("Starting…"), false, rec.id)
            root.backend.composeRun(rec, verb, i18n("%1 · %2", root.composeLabel(verb), rec.project), null, requestId, generation)
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

        if (rec.state === "not-created") {
            if (root.sectionOnly === "copy") { addCopyMenu(rec); return }
            addEntry(i18n("Details"), "document-view", function() { root.openDetail(rec.id) })
            if (!root.backend.readOnly) addEntry(i18n("Create and start"), "media-playback-start", function() { root.backend.startContainer(rec) })
            addEntry(i18n("Open project folder"), "folder-open", function() { root.backend.openContainerFolder(rec) })
            addEntry(i18n("Edit Compose file…"), "document-edit", function() { root.backend.editCompose(rec) })
            return
        }
        if (root.browserOnly) {
            addBrowserEntries(root, rec)
            return
        }

        var state = String(rec.state || "")
        var running = rec.isRunning === true
        var fullMenu = root.sectionOnly === ""
        var wants = function (section) { return fullMenu || root.sectionOnly === section }

        var composeProject = !!rec.project && root.backend.canUseCompose
        var composeService = !!rec.service && composeProject

        var restarting = state.toLowerCase() === "restarting"
        if (fullMenu) {
            addHeading(i18n("Container"))
            addEntry(i18n("Details"), "document-view", function () { root.openDetail(rec.id) })
            addEntry(i18n("Logs"), "text-x-generic", function () { root.perform("logs") })
            if (!root.backend.readOnly && (running || state === "exited"))
                addEntry(i18n("Restart"), "view-refresh", function () { root.perform("restart") })
            if (!root.backend.readOnly && Parsers.canStop(state))
                addEntry(i18n("Stop"), "media-playback-stop", function () { root.perform("stop") })
            else if (!root.backend.readOnly && Parsers.canStart(state))
                addEntry(i18n("Start"), "media-playback-start", function () { root.perform("start") })
            addSeparator()
            addHeading(i18n("Management"))
        }

        if (wants("manage") && !root.backend.readOnly) {
            const manage = makeSubmenu(root, i18n("Manage"), "configure", "manage")
            if (manage) {
                addHeading(i18n("Lifecycle"), manage)
                addToMenu(manage, composeService ? i18n("Pull and recreate…") : i18n("Pull image only…"), "package-upgrade", function () { root.dialogs.confirmUpdate(rec) })
                if (Parsers.canStart(state)) addToMenu(manage, i18n("Start"), "media-playback-start", function () { root.perform("start") })
                if (Parsers.canStop(state)) addToMenu(manage, i18n("Stop"), "media-playback-stop", function () { root.perform("stop") })
                if (Parsers.canPause(state)) addToMenu(manage, i18n("Pause"), "media-playback-pause", function () { root.backend.pauseContainer(rec) })
                if (Parsers.canUnpause(state)) addToMenu(manage, i18n("Resume"), "media-playback-start", function () { root.backend.unpauseContainer(rec) })
                if (running || state === "paused") addToMenu(manage, i18n("Force stop"), "process-stop", function () { root.backend.killContainer(rec) })
                if (!root.backend.isPodman && rec.restartPolicy !== undefined && rec.restartPolicy !== "") {
                    addSeparator(manage)
                    const startup = makeSubmenu(manage, i18n("Startup policy"), "media-playlist-repeat")
                    const policies = ["no", "on-failure", "unless-stopped", "always"]
                    const labels = [i18n("Manual start"), i18n("On failure"), i18n("Unless stopped"), i18n("Always")]
                    const glyphs = ["startup-manual", "startup-failure", "startup-unless-stopped", "startup-always"]
                    for (let p = 0; startup && p < policies.length; p++) {
                        let policy = policies[p]
                        const option = addToMenu(startup, labels[p], glyphs[p], function () { root.backend.setRestartPolicy(rec, policy) }, rec.restartPolicy !== policy)
                        option.checkable = true
                        option.checked = rec.restartPolicy === policy
                    }
                }
                addSeparator(manage)
                addHeading(i18n("Removal"), manage)
                addToMenu(manage, i18n("Remove container…"), "edit-delete", function () { root.dialogs.confirmRemove(rec) })
            }
        }

        if (fullMenu) addSeparator()

        if (wants("customize")) {
        const customize = makeSubmenu(root, i18n("Customize"), "preferences-desktop-icons", "customize")
        if (customize) {
            const icons = makeSubmenu(customize, i18n("Service icon"), "image")
            addToMenu(icons, i18n("Choose icon…"), "edit-find", function () { root.dialogs.chooseIcon(rec) })
            addToMenu(icons, i18n("Use automatic icon"), "edit-undo", function () {
                root.backend.customIconStore.reset(root.backend.customIconStore.keyFor(rec))
                root.backend.customIconStore.reset(root.backend.customIconStore.keyForName(rec.name))
                root.backend.customIconStore.reset(root.backend.customIconStore.keyForImage(rec.image))
            })
            addSeparator(customize)
            if (!root.backend.readOnly) addToMenu(customize, i18n("Rename container…"), "edit-rename", function () { root.dialogs.promptRename(rec) })
            addToMenu(customize, rec.pinned ? i18n("Unpin from top") : i18n("Pin to top"), rec.pinned ? "window-unpin" : "window-pin", function () { root.backend.togglePin(rec) })
            if (rec.pinned) {
                addToMenu(customize, i18n("Move up"), "go-up", function () { root.backend.movePin(rec, -1) })
                addToMenu(customize, i18n("Move down"), "go-down", function () { root.backend.movePin(rec, 1) })
            }
        }

        }

        if (fullMenu) addSeparator()

        if (fullMenu) addHeading(i18n("Open and links"))
        var apps = root.backend.launchersFor(rec)
        if (wants("open") && (!root.backend.remoteEngine || (!root.backend.readOnly && apps.length > 0))) {
            const openInMenu = makeSubmenu(root, i18n("Open"), "document-open", "open")
            if (openInMenu && !root.backend.remoteEngine) addToMenu(openInMenu, i18n("Container folder"), "folder", function () { root.backend.openContainerFolder(rec) })
            if (openInMenu && !root.backend.readOnly && apps.length > 0) {
                if (!root.backend.remoteEngine) addSeparator(openInMenu)
                for (let n = 0; n < apps.length; n++) addLauncherEntry(openInMenu, apps[n], rec)
            }
        }

        if (wants("open") && (root.backend.allLinksFor(rec).length > 0)) {
            const linksMenu = makeSubmenu(root, i18n("Web links"), "insert-link")
            if (linksMenu) addBrowserEntries(linksMenu, rec)
        }
        if (fullMenu) addSeparator()
        if (fullMenu) addHeading(i18n("Project and tools"))
        if (wants("compose") && !root.backend.readOnly && root.backend.canUseCompose && rec.project !== "") addComposeMenu(rec)

        if (fullMenu) addSeparator()
        if (wants("diagnostics")) {
        const diagnostics = makeSubmenu(root, i18n("Diagnostics"), "utilities-system-monitor", "diagnostics")
        if (diagnostics) {
            addToMenu(diagnostics, i18n("Inspect JSON"), "document-properties", function () { root.showInspect(rec) })
            if (running && !root.backend.readOnly) addToMenu(diagnostics, i18n("Run command…"), "utilities-terminal", function () { root.dialogs.openRun(rec) })
            addToMenu(diagnostics, i18n("Refresh data"), "view-refresh", function () { root.backend.refresh({force:true,withStats:true}) })
            addToMenu(diagnostics, i18n("Follow logs in terminal"), "text-x-log", function () { root.backend.followLogs(rec) })
            if (!root.backend.readOnly && ((running && String(rec.health || "").toLowerCase() === "unhealthy") || restarting))
                addToMenu(diagnostics, i18n("Restart container…"), "dialog-warning", function () { root.dialogs.confirm(i18n("Restart %1?", rec.name), i18n("This will restart the container. Dockmoid will not attempt automatic repair."), function () { root.backend.restartContainer(rec) }) })
        }

        }

        if (fullMenu) {
            addSeparator()
            addCopyMenu(rec)
        } else if (wants("copy")) {
            addCopyMenu(rec)
        }
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

    // Build only when opened; closed row menus need no graphical entries.
}
