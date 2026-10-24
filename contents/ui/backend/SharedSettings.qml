import QtQuick

/*
 * SharedSettings — one set of settings for every Dockmoid widget.
 *
 * Plasma keeps a separate configuration per widget, so a panel widget and the
 * copy in the system tray drift apart (custom icons, views, commands). While
 * sharing is on, a change made in one widget is written to
 * ~/.local/share/dockmoid/shared-settings.json and the others take it at
 * start-up and whenever their view opens.
 *
 * Nothing is written until a setting actually changes here, or "Copy these
 * settings to all widgets" is pressed, so a freshly added widget with default
 * settings never overwrites a configured one.
 */
Item {
    id: root
    visible: false
    width: 0
    height: 0

    required property var cfg
    required property var runner
    /* For shellQuote and the data directory. */
    required property var backend
    /* Tells this widget's own writes apart from another widget's. */
    property string instanceId: ""

    readonly property string folder: backend.dataDir + "/dockmoid"
    readonly property string path: folder + "/shared-settings.json"
    /* Window size, per-view layout state and caches stay with each widget. */
    readonly property var localKeys: ["popupWidth", "popupHeight", "serviceSectionSettings", "updateCache",
        "shareSettings", "sharedSettingsPushAt"]

    property string lastSnapshot: ""
    property double appliedAt: 0
    property bool started: false

    function sharedKeys() {
        if (!cfg || typeof cfg.keys !== "function") return []
        return cfg.keys().filter(function (key) {
            return root.localKeys.indexOf(key) < 0 && !/Default$/.test(key)
        }).sort()
    }

    function snapshot() {
        const values = {}
        sharedKeys().forEach(function (key) { values[key] = root.cfg[key] })
        return JSON.stringify(values)
    }

    function start() {
        lastSnapshot = snapshot()
        started = true
        pull()
    }

    /* Take newer settings written by another widget. */
    function pull() {
        if (!started || cfg.shareSettings !== true || !runner) return
        runner.run("cat " + backend.shellQuote(path) + " 2>/dev/null", "shared-settings", function (code, out) {
            if (code !== 0 || String(out || "").trim() === "") return
            let data
            try { data = JSON.parse(out) } catch (e) { return }
            if (!data || data.version !== 1 || typeof data.values !== "object") return
            if (data.writer === root.instanceId || !(data.savedAt > root.appliedAt)) return
            root.appliedAt = data.savedAt
            root.apply(data.values)
        })
    }

    function apply(values) {
        const keys = sharedKeys()
        for (const key in values) {
            if (keys.indexOf(key) < 0) continue
            if (JSON.stringify(cfg[key]) !== JSON.stringify(values[key])) cfg[key] = values[key]
        }
        // What was just taken is not a local change to send back.
        lastSnapshot = snapshot()
    }

    /* Called on the regular tick: send local changes on. */
    function check() {
        if (!started || cfg.shareSettings !== true) return
        const current = snapshot()
        if (current === lastSnapshot) return
        lastSnapshot = current
        push()
    }

    function push() {
        if (!started || !runner) return
        const savedAt = Date.now()
        appliedAt = savedAt
        const text = JSON.stringify({version: 1, writer: instanceId, savedAt: savedAt, values: JSON.parse(lastSnapshot)})
        const temp = path + ".tmp"
        runner.run("mkdir -p " + backend.shellQuote(folder) + " && printf '%s' " + backend.shellQuote(text)
                   + " > " + backend.shellQuote(temp) + " && mv -f " + backend.shellQuote(temp) + " " + backend.shellQuote(path),
                   "shared-settings-write", function (code, out, err) {
            if (code !== 0) console.warn("[dockmoid] could not save shared settings:", err)
        })
    }

    /* "Copy these settings to all widgets" in the settings dialog. */
    Connections {
        target: root.cfg
        function onSharedSettingsPushAtChanged() {
            if (!root.started || String(root.cfg.sharedSettingsPushAt || "") === "") return
            root.lastSnapshot = root.snapshot()
            root.push()
        }
    }
}
