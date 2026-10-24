pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.kquickcontrolsaddons as KQuickControlsAddons
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.extras as PlasmaExtras

/* Searchable, expandable JSON tree with copy actions for values and paths. */
Item {
    id: root
    property string text: ""
    property string emptyText: i18n("No inspect output yet.")
    property string needle: ""
    property string viewMode: "tree"
    property var expandedPaths: ({"$": true})
    property var rows: []
    property string error: ""
    KQuickControlsAddons.Clipboard { id: clipboard }

    function typeName(v) {
        if (v === null) return "null"
        if (Array.isArray(v)) return "array"
        return typeof v === "object" ? "object" : typeof v
    }
    function childrenOf(v) {
        if (Array.isArray(v)) return v.map(function (_, i) { return String(i) })
        if (v && typeof v === "object") return Object.keys(v).sort()
        return []
    }
    function childValue(v, k) { return Array.isArray(v) ? v[Number(k)] : v[k] }
    function valueText(v) {
        return v !== null && typeof v === "object" ? (Array.isArray(v) ? "[ … ]" : "{ … }") : JSON.stringify(v)
    }
    function childPath(parentPath, key, arrayValue) {
        if (arrayValue) return parentPath + "[" + key + "]"
        return /^[A-Za-z_$][A-Za-z0-9_$]*$/.test(key)
            ? parentPath + "." + key : parentPath + "[" + JSON.stringify(key) + "]"
    }
    function copyJson() { clipboard.content = root.formatted() || root.text }
    function copyValue(index) { clipboard.content = root.rawAt(index) }
    function copyPath(path) { clipboard.content = path }

    /*
     * The text is parsed once per change; rows are built by walking only the
     * open branches (a search walks everything, but never serialises it).
     * A row's JSON is produced only when its tooltip or Copy asks for it, and
     * the list view creates delegates only for rows on screen.
     */
    property var parsed: undefined
    property var nodeValues: []
    function rawAt(index) { const v = root.nodeValues[index]; return v === undefined ? "" : JSON.stringify(v, null, 2) }
    function formatted() { return root.parsed === undefined ? "" : JSON.stringify(root.parsed, null, 2) }
    readonly property string formattedJson: root.viewMode === "raw" && root.parsed !== undefined ? root.formatted() : ""
    function parse() {
        root.parsed = undefined
        if (root.text.trim() === "") { root.error = ""; return }
        try { root.parsed = JSON.parse(root.text); root.error = "" } catch (e) { root.error = String(e) }
    }
    function setAllExpanded(expanded) {
        if (root.parsed === undefined) return
        if (!expanded) { root.expandedPaths = ({"$": true}); root.rebuild(); return }
        const next = {}
        function collect(value, path) {
            if (value === null || typeof value !== "object") return
            next[path] = true
            const array = Array.isArray(value)
            const keys = array ? null : Object.keys(value)
            const n = array ? value.length : keys.length
            for (let i = 0; i < n; i++) {
                const k = array ? String(i) : keys[i]
                collect(array ? value[i] : value[k], root.childPath(path, k, array))
            }
        }
        collect(root.parsed, "$")
        root.expandedPaths = next
        root.rebuild()
    }
    function valueColor(type) {
        if (type === "string") return Kirigami.Theme.linkColor
        if (type === "boolean") return Kirigami.Theme.neutralTextColor
        if (type === "null") return Kirigami.Theme.disabledTextColor
        return Kirigami.Theme.textColor
    }
    function rebuild() {
        if (root.parsed === undefined) { root.rows = []; root.nodeValues = []; return }
        const query = root.appliedNeedle.toLowerCase(), values = [], expanded = root.expandedPaths
        function makeRow(value, key, path, depth, open) {
            const type = root.typeName(value)
            values.push(value)
            return {key: String(key), path: path, depth: depth, value: root.valueText(value), index: values.length - 1,
                    expandable: value !== null && typeof value === "object" && root.childrenOf(value).length > 0,
                    expanded: open, type: type, valueColor: root.valueColor(type)}
        }
        // Browsing: rows for open branches only.
        function browse(value, key, path, depth, out) {
            const open = !!expanded[path]
            out.push(makeRow(value, key, path, depth, open))
            if (!open) return
            const array = Array.isArray(value)
            root.childrenOf(value).forEach(function (k) { browse(array ? value[Number(k)] : value[k], k, root.childPath(path, k, array), depth + 1, out) })
        }
        // Searching: a branch shows when it or anything below it matches.
        function search(value, key, path, depth, out) {
            const own = String(key).toLowerCase().indexOf(query) >= 0 || path.toLowerCase().indexOf(query) >= 0
            const below = []
            const array = Array.isArray(value)
            root.childrenOf(value).forEach(function (k) { search(array ? value[Number(k)] : value[k], k, root.childPath(path, k, array), depth + 1, below) })
            if (!own && below.length === 0) return
            out.push(makeRow(value, key, path, depth, below.length > 0))
            for (let i = 0; i < below.length; i++) out.push(below[i])
        }
        const out = []
        if (query === "") browse(root.parsed, "$", "$", 0, out); else search(root.parsed, "$", "$", 0, out)
        root.nodeValues = values
        root.rows = out
    }
    function toggle(path) {
        var next = Object.assign({}, root.expandedPaths)
        next[path] = !next[path]
        root.expandedPaths = next
        root.rebuild()
    }
    property string appliedNeedle: ""
    Timer { id: needleDebounce; interval: 150; onTriggered: { root.appliedNeedle = root.needle; root.rebuild() } }
    onNeedleChanged: if (root.needle === "") { needleDebounce.stop(); root.appliedNeedle = ""; root.rebuild() } else needleDebounce.restart()
    onTextChanged: { root.parse(); root.rebuild() }
    Component.onCompleted: { root.parse(); root.rebuild() }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0
        RowLayout {
            Layout.fillWidth: true
            Layout.margins: Kirigami.Units.smallSpacing
            PlasmaExtras.SearchField { Layout.fillWidth: true; enabled: root.viewMode === "tree"; placeholderText: i18n("Search tree keys"); onTextChanged: root.needle = text; Keys.onEscapePressed: clear() }
            QQC2.Button { objectName: "inspectTreeMode"; text: i18n("Tree"); checkable: true; checked: root.viewMode === "tree"; onClicked: root.viewMode = "tree" }
            QQC2.Button { objectName: "inspectRawMode"; text: i18n("Raw"); checkable: true; checked: root.viewMode === "raw"; onClicked: root.viewMode = "raw" }
        }
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.smallSpacing
            Layout.rightMargin: Kirigami.Units.smallSpacing
            Layout.bottomMargin: Kirigami.Units.smallSpacing
            QQC2.Button { objectName: "inspectExpandAll"; text: i18n("Expand all"); icon.name: "list-add"; enabled: root.viewMode === "tree" && root.error === "" && root.text.trim() !== ""; onClicked: root.setAllExpanded(true) }
            QQC2.Button { objectName: "inspectCollapseAll"; text: i18n("Collapse all"); icon.name: "list-remove"; enabled: root.viewMode === "tree" && root.error === "" && root.text.trim() !== ""; onClicked: root.setAllExpanded(false) }
            Item { Layout.fillWidth: true }
            PlasmaComponents.ToolButton { objectName: "inspectCopyJson"; text: i18n("Copy JSON"); icon.name: "edit-copy"; onClicked: root.copyJson() }
        }
        PlasmaComponents.Label {
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.smallSpacing
            visible: root.error !== ""
            wrapMode: Text.Wrap
            text: i18n("Inspect output is not valid JSON: %1", root.error)
            color: Kirigami.Theme.negativeTextColor
        }
        ListView {
            id: treeList
            visible: root.viewMode === "tree"
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: root.rows
            reuseItems: true
            boundsBehavior: Flickable.StopAtBounds
            QQC2.ScrollBar.vertical: QQC2.ScrollBar {}
            delegate: RowLayout {
                required property var modelData
                width: treeList.width
                spacing: Kirigami.Units.smallSpacing
                PlasmaComponents.ToolButton {
                    Layout.leftMargin: modelData.depth * Kirigami.Units.largeSpacing
                    visible: modelData.expandable
                    text: modelData.expanded ? "▾" : "▸"
                    display: PlasmaComponents.AbstractButton.TextOnly
                    onClicked: root.toggle(modelData.path)
                }
                Item { visible: !modelData.expandable; Layout.preferredWidth: Kirigami.Units.iconSizes.small + modelData.depth * Kirigami.Units.largeSpacing }
                PlasmaComponents.Label { text: modelData.key; font.bold: true; color: Kirigami.Theme.linkColor; elide: Text.ElideRight }
                PlasmaComponents.Label { text: ":"; opacity: 0.6 }
                PlasmaComponents.Label {
                    Layout.fillWidth: true; Layout.minimumWidth: 0
                    text: modelData.value; color: modelData.valueColor
                    font.family: Kirigami.Theme.fixedWidthFont.family; elide: Text.ElideRight
                    // Built only when the pointer rests here: a branch's JSON can be large.
                    HoverHandler { id: valueHover }
                    PlasmaComponents.ToolTip { visible: valueHover.hovered; delay: 600; text: visible ? root.rawAt(modelData.index).slice(0, 2000) : "" }
                }
                PlasmaComponents.ToolButton { text: i18n("Value"); onClicked: root.copyValue(modelData.index) }
                PlasmaComponents.ToolButton { text: i18n("Path"); onClicked: root.copyPath(modelData.path) }
            }
            PlasmaComponents.Label { anchors.centerIn: parent; visible: root.rows.length === 0 && root.error === ""; text: root.needle ? i18n("No matching keys.") : root.emptyText; opacity: 0.7 }
        }
        QQC2.TextArea {
            objectName: "inspectRawJson"
            visible: root.viewMode === "raw"
            Layout.fillWidth: true
            Layout.fillHeight: true
            text: root.formattedJson || (root.viewMode === "raw" ? root.text : "")
            readOnly: true
            selectByMouse: true
            wrapMode: TextEdit.NoWrap
            font.family: Kirigami.Theme.fixedWidthFont.family
            Accessible.name: i18n("Raw JSON inspect output")
        }
    }
}
