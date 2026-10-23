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

    /* The detail header's buttons and this menu ask the same rules
       (lib/actions.js through the backend), so they cannot disagree. */
    function canPerform(action) {
        var rec = root.record
        if (!rec || !rec.id) return false
        if (action === "start-stop") return root.backend.primaryActionFor(rec).enabled
        return root.backend.actionsFor(rec)[action] === true
    }

    function perform(action) {
        var rec = root.record
        if (!root.canPerform(action)) return
        if (action === "start-stop") {
            root.backend.runAction(rec, root.backend.primaryActionFor(rec).action)
        } else if (action === "logs") {
            root.backend.newOutputRequest("logs", rec.id)
            root.openOutput(root.backend.logsTitle(rec), i18n("Loading…"), true, rec.id)
        } else if (action === "inspect") {
            root.showInspect(rec)
        } else {
            root.backend.runAction(rec, action)
        }
    }

    /*
     * A menu entry for one action: listed when the container's state allows
     * it, and greyed out while something else is running on it.
     */
    function offer(menu, label, glyph, action, run) {
        if (root.backend.stateActionsFor(root.record)[action] !== true) return null
        return addToMenu(menu, label, glyph, run || function () { root.perform(action) }, root.canPerform(action))
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

    function addEntry(label, glyph, action, artwork, key) {
        if (root.isExcluded(label, key)) return
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

    /* The container's web addresses, to open or copy. */
    function addUrlEntries(menu: PlasmaComponents.Menu, rec: var) {
        const links = root.backend.linksFor(rec)
        const all = root.backend.allLinksFor(rec)
        if (links.length === 0) addToMenu(menu, all.length ? i18n("All browser ports are hidden") : i18n("No published web addresses"), "insert-link", function(){}, false)
        links.forEach(function(link) {
            const item = addToMenu(menu, link.title || i18n("Web UI · %1", link.label), "insert-link", function() { root.backend.openLink(link) })
            if (item) item.detail = link.url || Parsers.linkUrl(link)
        })
        const copy = links.length ? makeSubmenu(menu, i18n("Copy URL"), "edit-copy") : null
        if (copy) links.forEach(function(link) { addToMenu(copy, link.title, "edit-copy", function() { clipboard.content = link.url }) })
    }

    /* Which address opens first, and which ports are offered at all. */
    function addUrlSettings(menu: PlasmaComponents.Menu, rec: var) {
        const all = root.backend.allLinksFor(rec)
        if (!all.length) return
        const preferred = makeSubmenu(menu, i18n("Preferred URL"), "bookmark")
        if (preferred) {
            const current = root.backend.browserSettings(root.backend.cfg.preferredBrowserLinks)[root.backend.browserKey(rec)] || ""
            all.forEach(function(link) {
                const item = addToMenu(preferred, link.title, "insert-link", function() { root.backend.preferBrowserLink(rec, link) })
                if (item) { item.checkable = true; item.checked = link.url === current; item.detail = link.url }
            })
        }
        const ports = makeSubmenu(menu, i18n("Visible Ports"), "configure")
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
        var values = [[i18n("Name"), rec.name, "copy-name"], [i18n("Container ID"), rec.id, "copy-id"], [i18n("Image"), rec.image, "copy-image"],
            [i18n("Shell Command"), root.backend.engineBinary + " exec -it " + rec.name + " sh", "square-terminal"],
            [i18n("Logs Command"), root.backend.engineBinary + " logs -f --tail 200 " + rec.name, "scroll-text"]]
        if (rec.project) values.push([i18n("Project"), rec.project, "copy-project"])
        if (rec.service) values.push([i18n("Service"), rec.service, "copy-service"])
        if (rec.composeFiles) values.push([i18n("Compose File Path"), rec.composeFiles, "copy-compose"])
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

    /* A Compose verb as a menu entry; destructive ones ask first. */
    function addComposeItem(menu, verb, label, glyph, destructive) {
        return addToMenu(menu, label, glyph, function () { root.runCompose(root.record, verb, destructive === true) })
    }

    /*
     * Compose: read-only looks first, then what can be done to the whole
     * project and to this one service, then its files.
     */
    function addComposeMenu(rec) {
        var menu = makeSubmenu(root, i18n("Compose"), "layers", "compose")
        if (!menu) return
        addHeading(i18n("Inspect"), menu)
        addComposeItem(menu, "ps", i18n("Status"), "view-list-details")
        addComposeItem(menu, "logs", i18n("Logs"), "text-x-generic")
        addComposeItem(menu, "images", i18n("Images"), "layers")
        addComposeItem(menu, "top", i18n("Processes"), "activity")
        addComposeItem(menu, "config", i18n("Validate Configuration"), "badge-check")

        if (!root.backend.readOnly) {
            addSeparator(menu)
            const project = makeSubmenu(menu, i18n("Whole Project"), "boxes")
            addHeading(i18n("Lifecycle"), project)
            addComposeItem(project, "up", i18n("Up (Create and Start)"), "media-playback-start")
            addComposeItem(project, "start", i18n("Start"), "play")
            addComposeItem(project, "stop", i18n("Stop"), "media-playback-stop")
            addComposeItem(project, "restart", i18n("Restart"), "view-refresh")
            addComposeItem(project, "pause", i18n("Pause"), "media-playback-pause")
            addComposeItem(project, "unpause", i18n("Resume"), "media-playback-start")
            addSeparator(project)
            addHeading(i18n("Images"), project)
            addComposeItem(project, "pull", i18n("Pull Images"), "system-download")
            addComposeItem(project, "update", i18n("Update (Pull and Up)"), "package-upgrade")
            addComposeItem(project, "recreate", i18n("Force Recreate"), "media-playlist-repeat")
            addSeparator(project)
            addComposeItem(project, "down", i18n("Take Down…"), "edit-delete", true)

            if (rec.service) {
                const service = makeSubmenu(menu, i18n("This Service · %1", rec.service), "workflow")
                addComposeItem(service, "service-logs", i18n("Logs"), "text-x-generic")
                addComposeItem(service, "service-restart", i18n("Restart"), "view-refresh")
                addComposeItem(service, "service-pull", i18n("Pull Image"), "system-download")
                addComposeItem(service, "service-recreate", i18n("Force Recreate"), "media-playlist-repeat")
            }
        }

        addSeparator(menu)
        addHeading(i18n("Files"), menu)
        if (rec.composeFiles !== "") addToMenu(menu, i18n("Edit Compose File…"), "document-edit", function () { root.backend.editCompose(rec) })
        if (!root.backend.remoteEngine && rec.composeWorkDir) addToMenu(menu, i18n("Open Project Folder"), "folder-open", function () { root.backend.openContainerFolder(rec) })
    }

    /* A read-only look at the container, on the output page. */
    function showDiagnostic(rec, what) {
        var generation = root.backend.generation
        var requestId = root.backend.newOutputRequest("diagnostics", rec.id)
        root.openOutput(root.backend.diagnosticTitle(what, rec), i18n("Loading…"), false, rec.id)
        root.backend.diagnose(rec, what, requestId, generation)
    }

    function composeLabel(verb) {
        return ({ps:i18n("Project Status"),logs:i18n("Project Logs"),up:i18n("Start Project"),restart:i18n("Restart Project"),stop:i18n("Stop Project"),
                 pull:i18n("Pull Images"),update:i18n("Update Project"),recreate:i18n("Recreate Project"),down:i18n("Take Down Project"),
                 start:i18n("Start Project"),pause:i18n("Pause Project"),unpause:i18n("Resume Project"),images:i18n("Project Images"),
                 top:i18n("Project Processes"),config:i18n("Validate Configuration"),"service-logs":i18n("Service Logs"),
                 "service-restart":i18n("Restart Service"),"service-pull":i18n("Pull Service Image"),"service-recreate":i18n("Recreate Service")})[verb] || i18n("Compose")
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
            addEntry(i18n("Details"), "badge-info", function() { root.openDetail(rec.id) }, "", "details")
            if (root.backend.actionsFor(rec).create) addEntry(i18n("Create and Start"), "rocket", function() { root.backend.runAction(rec, "create") })
            addEntry(i18n("Open Project Folder"), "folder-open", function() { root.backend.openContainerFolder(rec) })
            addEntry(i18n("Edit Compose File…"), "document-edit", function() { root.backend.editCompose(rec) })
            return
        }
        if (root.browserOnly) {
            addUrlEntries(root, rec)
            if (root.backend.allLinksFor(rec).length > 0) { addSeparator(); addUrlSettings(root, rec) }
            return
        }

        var state = String(rec.state || "")
        var running = rec.isRunning === true
        var fullMenu = root.sectionOnly === ""
        var wants = function (section) { return fullMenu || root.sectionOnly === section }

        var composeProject = !!rec.project && root.backend.canUseCompose
        var composeService = !!rec.service && composeProject

        var restarting = state.toLowerCase() === "restarting"
        var paused = state === "paused"
        var web = running ? root.backend.linksFor(rec) : []
        var hasUrls = root.backend.allLinksFor(rec).length > 0

        // ---- the container: look at it, then act on it -----------------------
        if (fullMenu) {
            addHeading(i18n("Container"))
            addEntry(i18n("Details"), "badge-info", function () { root.openDetail(rec.id) }, "", "details")
            if (web.length > 0)
                addEntry(i18n("Web"), "globe", function () { root.backend.openLink(web[0]) }, "", "open web ui")
            addEntry(i18n("Logs"), "scroll-text", function () { root.perform("logs") }, "", "logs")
        }

        if (wants("manage") && !root.backend.readOnly) {
            const manage = makeSubmenu(root, i18n("Manage"), "settings-2", "manage")
            if (manage) {
                offer(manage, i18n("Start"), "media-playback-start", "start")
                offer(manage, i18n("Stop"), "media-playback-stop", "stop")
                offer(manage, i18n("Pause"), "media-playback-pause", "pause")
                offer(manage, i18n("Resume"), "media-playback-start", "resume")
                offer(manage, i18n("Restart"), "view-refresh", "restart")
                offer(manage, i18n("Kill"), "process-stop", "kill")
                offer(manage, i18n("Update…"), "cloud-download", "update", function () { root.dialogs.confirmUpdate(rec) })

                // Force: the same actions without waiting for a clean shutdown.
                const force = makeSubmenu(manage, i18n("Force"), "zap")
                if (force) {
                    offer(force, i18n("Restart Now"), "view-refresh", "forceRestart")
                    offer(force, i18n("Recreate"), "media-playlist-repeat", "recreate", function () { root.runCompose(rec, "service-recreate", false) })
                    offer(force, i18n("Remove…"), "trash", "remove", function () { root.dialogs.confirmRemove(rec) })
                }

                if (!root.backend.isPodman && rec.restartPolicy !== undefined && rec.restartPolicy !== "") {
                    addSeparator(manage)
                    const startup = makeSubmenu(manage, i18n("Autostart"), "media-playlist-repeat")
                    const policies = ["no", "on-failure", "unless-stopped", "always"]
                    const labels = [i18n("Manual Start"), i18n("On Failure"), i18n("Unless Stopped"), i18n("Always")]
                    const glyphs = ["startup-manual", "startup-failure", "startup-unless-stopped", "startup-always"]
                    for (let p = 0; startup && p < policies.length; p++) {
                        let policy = policies[p]
                        const option = addToMenu(startup, labels[p], glyphs[p], function () { root.backend.setRestartPolicy(rec, policy) }, rec.restartPolicy !== policy)
                        option.checkable = true
                        option.checked = rec.restartPolicy === policy
                    }
                }
            }
        }

        if (wants("open") && hasUrls) {
            const links = makeSubmenu(root, i18n("Links"), "insert-link", "links")
            if (links) addUrlEntries(links, rec)
        }

        // ---- where it comes from --------------------------------------------
        if (fullMenu) { addSeparator(); addHeading(i18n("Project")) }

        var apps = root.backend.launchersFor(rec)
        if (wants("open") && (!root.backend.remoteEngine || (!root.backend.readOnly && apps.length > 0))) {
            const openInMenu = makeSubmenu(root, i18n("Open"), "document-open", "open")
            if (openInMenu && !root.backend.remoteEngine) addToMenu(openInMenu, i18n("Container Folder"), "folder", function () { root.backend.openContainerFolder(rec) })
            if (openInMenu && !root.backend.readOnly && apps.length > 0) {
                if (!root.backend.remoteEngine) addSeparator(openInMenu)
                for (let n = 0; n < apps.length; n++) addLauncherEntry(openInMenu, apps[n], rec)
            }
        }
        if (wants("compose") && root.backend.canUseCompose && rec.project !== "") addComposeMenu(rec)
        if (fullMenu || wants("copy")) addCopyMenu(rec)

        // ---- tools ----------------------------------------------------------
        if (fullMenu) { addSeparator(); addHeading(i18n("Tools")) }

        if (wants("customize")) {
            const customize = makeSubmenu(root, i18n("Customize"), "palette", "customize")
            if (customize) {
                const icons = makeSubmenu(customize, i18n("Service Icon"), "image")
                addToMenu(icons, i18n("Choose Icon…"), "edit-find", function () { root.dialogs.chooseIcon(rec) })
                addToMenu(icons, i18n("Use Automatic Icon"), "edit-undo", function () {
                    root.backend.customIconStore.reset(root.backend.customIconStore.keyFor(rec))
                    root.backend.customIconStore.reset(root.backend.customIconStore.keyForName(rec.name))
                    root.backend.customIconStore.reset(root.backend.customIconStore.keyForImage(rec.image))
                })
                offer(customize, i18n("Rename Container…"), "edit-rename", "rename", function () { root.dialogs.promptRename(rec) })
                addSeparator(customize)
                addToMenu(customize, rec.pinned ? i18n("Unpin from Top") : i18n("Pin to Top"), rec.pinned ? "window-unpin" : "window-pin", function () { root.backend.togglePin(rec) })
                if (rec.pinned) {
                    addToMenu(customize, i18n("Move Up"), "go-up", function () { root.backend.movePin(rec, -1) })
                    addToMenu(customize, i18n("Move Down"), "go-down", function () { root.backend.movePin(rec, 1) })
                }
                if (hasUrls) {
                    addSeparator(customize)
                    addUrlSettings(customize, rec)
                }
            }
        }

        if (wants("diagnostics")) {
            const inspect = makeSubmenu(root, i18n("Inspect"), "stethoscope", "diagnostics")
            if (inspect) {
                addToMenu(inspect, i18n("Configuration (JSON)"), "document-properties", function () { root.showInspect(rec) })
                if (running || paused) addToMenu(inspect, i18n("Processes"), "activity", function () { root.showDiagnostic(rec, "top") })
                if (running) addToMenu(inspect, i18n("Usage Snapshot"), "gauge", function () { root.showDiagnostic(rec, "stats") })
                if (running && rec.health && rec.health !== "none") addToMenu(inspect, i18n("Health Checks"), "heart-pulse", function () { root.showDiagnostic(rec, "health") })
                if (running) addToMenu(inspect, i18n("Port Mappings"), "plug", function () { root.showDiagnostic(rec, "port") })
                addToMenu(inspect, i18n("Filesystem Changes"), "file-diff", function () { root.showDiagnostic(rec, "diff") })
                addToMenu(inspect, i18n("Recent Events"), "clock", function () { root.showDiagnostic(rec, "events") })
            }
            const terminal = makeSubmenu(root, i18n("Terminal"), "square-terminal", "terminal")
            if (terminal) {
                offer(terminal, i18n("Run Command…"), "square-terminal", "exec", function () { root.dialogs.openRun(rec) })
                addToMenu(terminal, i18n("Follow Logs in Terminal"), "terminal", function () { root.backend.followLogs(rec) })
                if (running) addToMenu(terminal, i18n("Copy Shell Command"), "edit-copy", function () { clipboard.content = root.backend.engineBinary + " exec -it " + rec.name + " sh" })
            }
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
