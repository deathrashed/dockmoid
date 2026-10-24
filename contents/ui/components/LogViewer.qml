import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2

import org.kde.kirigami as Kirigami
import org.kde.kquickcontrolsaddons as KQuickControlsAddons
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.extras as PlasmaExtras
import "../../lib/style.js" as Style

/*
 * LogViewer — text with the things you want when reading logs: filter, errors
 * only, keep-scrolled-to-the-end, wrap and copy. Used for container logs and
 * for any other command output (inspect, pulls, compose).
 */
Item {
    id: root

    property string text: ""
    /* Offer the errors-only toggle and stick to the bottom as lines arrive. */
    property bool logMode: false
    property string emptyText: i18n("No output yet.")

    property string needle: ""
    property bool errorsOnly: false
    property bool follow: true
    property bool wrap: true
    property bool paused: false
    /* Room to name the toggles instead of showing icons only. */
    readonly property bool labelToggles: root.width >= Kirigami.Units.gridUnit * 34
    property string frozenText: ""
    readonly property string sourceText: root.paused ? root.frozenText : root.text
    property int timestampMode: Number(plasmoid.configuration.logTimestampMode) >= 0 ? Number(plasmoid.configuration.logTimestampMode) : 1
    property int timestampPrecision: Number(plasmoid.configuration.logTimestampPrecision) >= 0 ? Number(plasmoid.configuration.logTimestampPrecision) : 0

    function pad(n) { return n < 10 ? "0" + n : String(n) }
    function formatTimestampLine(line) {
        var match = /^(\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d)(\.\d+)?(Z|[+-]\d\d:\d\d)(\s+)(.*)$/.exec(line)
        if (!match) return line
        if (root.timestampMode === 0) return match[5]
        var fraction = match[2] || ""
        if (root.timestampPrecision === 0) fraction = ""
        else if (root.timestampPrecision === 1) fraction = fraction ? ("." + (fraction.slice(1) + "000").slice(0, 3)) : ""
        if (root.timestampMode === 1) return match[1] + fraction + match[3] + " " + match[5]
        var parsed = new Date(match[1] + (match[2] || "") + match[3])
        if (isNaN(parsed.getTime())) return line
        var stamp = parsed.getFullYear() + "-" + pad(parsed.getMonth() + 1) + "-" + pad(parsed.getDate())
            + "T" + pad(parsed.getHours()) + ":" + pad(parsed.getMinutes()) + ":" + pad(parsed.getSeconds())
        if (root.timestampPrecision === 1) stamp += "." + (fraction ? (fraction.slice(1) + "000").slice(0, 3) : "000")
        else if (root.timestampPrecision === 2 && fraction) stamp += fraction
        return stamp + " " + match[5]
    }

    function stripAnsi(value) { return String(value).replace(/\u001b\[[0-?]*[ -/]*[@-~]/g, "") }
    function escapeHtml(value) {
        return String(value).replace(/&/g, "&amp;").replace(/</g, "&lt;")
            .replace(/>/g, "&gt;").replace(/\"/g, "&quot;").replace(/'/g, "&#39;")
    }
    function ansi256(index) {
        const base = [0, 95, 135, 175, 215, 255]
        if (index < 16) return ["#000000", "#800000", "#008000", "#808000", "#000080", "#800080", "#008080", "#c0c0c0", "#808080", "#ff0000", "#00ff00", "#ffff00", "#0000ff", "#ff00ff", "#00ffff", "#ffffff"][index]
        if (index < 232) {
            const n = index - 16, r = base[Math.floor(n / 36)], g = base[Math.floor(n / 6) % 6], b = base[n % 6]
            return "rgb(" + r + "," + g + "," + b + ")"
        }
        const gray = 8 + (index - 232) * 10
        return "rgb(" + gray + "," + gray + "," + gray + ")"
    }
    function ansiHtml(line) {
        const parts = String(line).split(/(\u001b\[[0-?]*[ -/]*[@-~])/g)
        let color = "", out = "", bold = false
        const palette = root.ansiPalette
        for (let i = 0; i < parts.length; ++i) {
            const token = parts[i], match = /^\u001b\[([0-9;]*)m$/.exec(token)
            if (match) {
                const codes = (match[1] || "0").split(";")
                for (let c = 0; c < codes.length; ++c) {
                    const code = Number(codes[c])
                    if (code === 0) { color = ""; bold = false }
                    else if (code === 1) bold = true
                    else if (code === 22) bold = false
                    else if (code === 39) color = ""
                    else if (palette[code]) color = palette[code]
                    else if (code === 38 && Number(codes[c + 1]) === 5 && codes[c + 2] !== undefined) {
                        color = root.ansi256(Number(codes[c + 2])); c += 2
                    } else if (code === 38 && Number(codes[c + 1]) === 2 && codes[c + 4] !== undefined) {
                        color = "rgb(" + Number(codes[c + 2]) + "," + Number(codes[c + 3]) + "," + Number(codes[c + 4]) + ")"; c += 4
                    }
                }
                continue
            }
            let escaped = root.escapeHtml(token)
            if (color || bold) escaped = '<span style="' + (color ? "color:" + color + ";" : "") + (bold ? "font-weight:700;" : "") + '">' + escaped + '</span>'
            if (!color && !bold) {
                escaped = escaped.replace(/\b(ERROR|FATAL|PANIC|CRITICAL)\b/gi, '<span style=\"color:' + root.levelColors.error + ';font-weight:700\">$1</span>')
                escaped = escaped.replace(/\b(WARN(?:ING)?)\b/gi, '<span style=\"color:' + root.levelColors.warn + ';font-weight:700\">$1</span>')
                escaped = escaped.replace(/\b(INFO)\b/gi, '<span style=\"color:' + root.levelColors.info + ';font-weight:700\">$1</span>')
                escaped = escaped.replace(/\b(DEBUG|TRACE)\b/gi, '<span style=\"color:' + root.levelColors.debug + ';font-weight:700\">$1</span>')
            }
            out += escaped
        }
        return out
    }
    function formatAnsiLine(line) {
        const clean = root.stripAnsi(line)
        const match = /^(\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d)(\.\d+)?(Z|[+-]\d\d:\d\d)(\s+)(.*)$/.exec(clean)
        if (!match) return line
        const prefix = match[1] + (match[2] || "") + match[3] + match[4]
        return root.formatTimestampLine(clean).slice(0, root.formatTimestampLine(clean).length - match[5].length) + String(line).slice(prefix.length)
    }
    /* Pastel colours read well on a dark panel and vanish on a light one. */
    readonly property bool darkTheme: Kirigami.Theme.backgroundColor.hslLightness < 0.5
    readonly property var ansiPalette: root.darkTheme
        ? {30:"#667085",31:"#ff6b6b",32:"#51cf66",33:"#ffd43b",34:"#74c0fc",35:"#da77f2",36:"#66d9e8",37:"#e9ecef",90:"#9aa0a6",91:"#ff8787",92:"#8ce99a",93:"#ffe066",94:"#91caff",95:"#e599f7",96:"#99e9f2",97:"#ffffff"}
        : {30:"#343a40",31:"#c92a2a",32:"#2b8a3e",33:"#946200",34:"#1864ab",35:"#862e9c",36:"#0b7285",37:"#495057",90:"#6c757d",91:"#e03131",92:"#2f9e44",93:"#a66f00",94:"#1c7ed6",95:"#9c36b5",96:"#1098ad",97:"#212529"}
    readonly property var levelColors: root.darkTheme
        ? {error:"#ff8787",warn:"#ffd43b",info:"#74c0fc",debug:"#9aa0a6"}
        : {error:"#c92a2a",warn:"#946200",info:"#1864ab",debug:"#6c757d"}
    /*
     * Each line is cleaned (ANSI stripped, timestamp formatted) once and its
     * HTML built once, then reused while it stays in the tail: a new poll or a
     * filter keystroke no longer re-formats thousands of unchanged lines. The
     * cache lives in a holder that is never reassigned, so filling it does not
     * re-trigger these bindings; a timestamp or theme change starts it afresh.
     */
    readonly property var cacheHolder: ({map: ({}), key: ""})
    readonly property string formatKey: root.timestampMode + "|" + root.timestampPrecision + "|" + root.darkTheme
    readonly property var rawLines: String(root.sourceText).split("\n")
    readonly property var entries: {
        const holder = root.cacheHolder, key = root.formatKey
        const old = holder.key === key ? holder.map : ({}), next = {}
        const out = root.rawLines.map(function (raw) {
            let e = next[raw] || old[raw]
            if (!e) { const clean = root.formatTimestampLine(root.stripAnsi(raw)); e = {raw: raw, clean: clean, lower: clean.toLowerCase(), html: null} }
            next[raw] = e
            return e
        })
        holder.map = next; holder.key = key
        return out
    }
    /* The filter applies after a short pause in typing. */
    property string appliedNeedle: ""
    Timer { id: needleDebounce; interval: 120; onTriggered: root.appliedNeedle = root.needle }
    onNeedleChanged: if (root.needle === "") { needleDebounce.stop(); root.appliedNeedle = "" } else needleDebounce.restart()
    readonly property var matched: {
        const n = root.appliedNeedle.toLowerCase()
        const level = /\b(error|err|fatal|panic|crit|critical|warn|warning|exception|fail|failed|denied|refused)\b/i
        if (n === "" && !root.errorsOnly) return root.entries
        return root.entries.filter(function (e) { return (n === "" || e.lower.indexOf(n) !== -1) && (!root.errorsOnly || level.test(e.clean)) })
    }
    readonly property var shownLines: root.matched.map(function (e) { return e.clean })
    /* Rich text slows sharply with length: draw the newest lines, say how many are left out. */
    readonly property int renderLimit: 2000
    readonly property int hiddenLines: Math.max(0, root.matched.length - root.renderLimit)
    readonly property string renderedHtml: {
        const shown = root.hiddenLines > 0 ? root.matched.slice(-root.renderLimit) : root.matched
        const body = shown.map(function (e) { if (e.html === null) e.html = root.ansiHtml(root.formatAnsiLine(e.raw)); return e.html }).join("<br>")
        return root.hiddenLines > 0
            ? '<span style="color:' + root.levelColors.debug + '">' + root.escapeHtml(i18n("… %1 earlier lines not drawn; filter to find them, or copy to get every line.", root.hiddenLines)) + "</span><br>" + body
            : body
    }
    onPausedChanged: if (root.paused) root.frozenText = root.text

    readonly property string shown: root.shownLines.join("\n")

    /* The ScrollView's own Flickable, held as a plain var so it is duck-typed. */
    readonly property var flickable: scroll.contentItem

    function scrollToEnd() {
        var flick = root.flickable
        if (flick && flick.contentHeight !== undefined)
            flick.contentY = Math.max(0, flick.contentHeight - flick.height)
    }

    onShownChanged: if (root.logMode && root.follow) Qt.callLater(root.scrollToEnd)

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            Layout.margins: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.smallSpacing

            PlasmaExtras.SearchField {
                id: filterField
                Layout.fillWidth: true
                Layout.minimumWidth: Kirigami.Units.gridUnit * 5
                Layout.maximumWidth: Kirigami.Units.gridUnit * 16
                placeholderText: i18n("Filter lines")
                onTextChanged: root.needle = text
                Keys.onEscapePressed: clear()
            }
            DockButton {
                variant: "flat"
                visible: filterField.text !== ""
                iconOnly: true
                glyph: "edit-clear"
                text: i18n("Clear filter")
                onClicked: filterField.clear()
            }

            PlasmaComponents.Label {
                visible: root.needle !== "" || root.errorsOnly
                text: i18n("%1 of %2", root.shownLines.length, root.rawLines.length)
                font: Kirigami.Theme.smallFont
                opacity: 0.7
            }

            Item { Layout.fillWidth: true }

            DockButton {
                variant: "flat"
                id: errorsButton
                visible: root.logMode
                iconOnly: true
                glyph: "dialog-warning"
                text: i18n("Only errors and warnings")
                checkable: true
                checked: root.errorsOnly
                onClicked: root.errorsOnly = checked
            }

            /*
             * Timestamp options live in one menu rather than two combo boxes:
             * at tray-popup width those pushed the other tools off the edge,
             * and their content-sized widths fed back into the row's layout.
             */
            DockButton {
                variant: "flat"
                id: timestampButton
                visible: root.logMode
                iconOnly: true
                glyph: "clock"
                text: i18n("Timestamps")
                checked: timestampMenu.opened || root.timestampMode !== 0
                onClicked: timestampMenu.popup(timestampButton, 0, timestampButton.height)
            }
            PlasmaComponents.Menu {
                id: timestampMenu
                Repeater {
                    model: [i18n("Hide Timestamps"), i18n("Original UTC"), i18n("Local Time")]
                    delegate: PlasmaComponents.MenuItem {
                        required property int index
                        required property string modelData
                        text: modelData
                        checkable: true
                        checked: root.timestampMode === index
                        autoExclusive: true
                        onTriggered: plasmoid.configuration.logTimestampMode = index
                    }
                }
                PlasmaComponents.MenuSeparator { visible: root.timestampMode !== 0; height: visible ? implicitHeight : 0 }
                Repeater {
                    model: root.timestampMode !== 0 ? [i18n("Seconds"), i18n("Milliseconds"), i18n("Full Precision")] : []
                    delegate: PlasmaComponents.MenuItem {
                        required property int index
                        required property string modelData
                        text: modelData
                        checkable: true
                        checked: root.timestampPrecision === index
                        autoExclusive: true
                        onTriggered: plasmoid.configuration.logTimestampPrecision = index
                    }
                }
            }

            // Freeze, Follow and Wrap are toggles: named on a wide viewer, and
            // checked (highlighted) while on at any width.
            DockButton {
                variant: "flat"
                id: pauseButton
                visible: root.logMode
                iconOnly: !root.labelToggles
                glyph: "media-playback-pause"
                text: i18n("Freeze")
                checkable: true
                checked: root.paused
                onClicked: root.paused = checked
            }

            DockButton {
                variant: "flat"
                id: followButton
                visible: root.logMode
                iconOnly: !root.labelToggles
                glyph: "arrow-down-to-line"
                text: i18n("Follow")
                checkable: true
                checked: root.follow
                onClicked: { root.follow = checked; if (checked) root.scrollToEnd() }
            }

            DockButton {
                variant: "flat"
                id: wrapButton
                iconOnly: !root.labelToggles
                glyph: "text-wrap"
                text: i18n("Wrap")
                checkable: true
                checked: root.wrap
                onClicked: root.wrap = checked
            }

            DockButton {
                variant: "flat"
                id: copyButton
                iconOnly: true
                glyph: "edit-copy"
                text: i18n("Copy what is shown")
                onClicked: clipboard.content = root.shown
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Qt.alpha(Kirigami.Theme.textColor, Style.ALPHA.border)
        }

        // Frozen is easy to forget: say so above the text, with the way out.
        Kirigami.InlineMessage {
            Layout.fillWidth: true
            Layout.margins: Kirigami.Units.smallSpacing
            visible: root.logMode && root.paused
            type: Kirigami.MessageType.Information
            text: root.text !== root.frozenText ? i18n("Display frozen · newer lines are waiting") : i18n("Display frozen")
            actions: [
                Kirigami.Action {
                    text: i18n("Show New Lines")
                    icon.name: "media-playback-start"
                    onTriggered: root.paused = false
                }
            ]
        }

        QQC2.ScrollView {
            id: scroll
            Layout.fillWidth: true
            Layout.fillHeight: true
            background: null

            // A direct child, not a contentItem: ScrollView supplies its own Flickable.
            QQC2.TextArea {
                readOnly: true
                selectByMouse: true
                wrapMode: root.wrap ? TextEdit.WrapAnywhere : TextEdit.NoWrap
                font: Kirigami.Theme.fixedWidthFont
                textFormat: TextEdit.RichText
                text: root.shown !== "" ? root.renderedHtml : root.escapeHtml(root.emptyText)
                background: null
            }
        }
    }

    KQuickControlsAddons.Clipboard {
        id: clipboard
    }
}
