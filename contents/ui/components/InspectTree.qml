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
    property string formattedJson: ""
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
    function copyJson() { clipboard.content = root.formattedJson || root.text }
    function copyValue(serializedValue) { clipboard.content = serializedValue }
    function copyPath(path) { clipboard.content = path }
    function setAllExpanded(expanded) {
        if (root.text.trim() === "") return
        var parsed
        try { parsed = JSON.parse(root.text) } catch (e) { return }
        var next = ({})
        function collect(value, path) {
            var keys = root.childrenOf(value)
            if (keys.length === 0) return
            next[path] = expanded
            keys.forEach(function (key) {
                collect(root.childValue(value, key), root.childPath(path, key, Array.isArray(value)))
            })
        }
        collect(parsed, "$")
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
        if (root.text.trim() === "") { root.error = ""; root.formattedJson = ""; root.rows = []; return }
        var parsed
        try {
            parsed = JSON.parse(root.text)
            root.error = ""
            root.formattedJson = JSON.stringify(parsed, null, 2)
        } catch (e) { root.error = String(e); root.formattedJson = root.text; root.rows = []; return }
        var out = [], query = root.needle.toLowerCase()
        function walk(value, key, path, depth, parentOpen) {
            var kids = root.childrenOf(value), expandable = kids.length > 0
            var ownMatch = query === "" || String(key).toLowerCase().indexOf(query) >= 0 || path.toLowerCase().indexOf(query) >= 0
            var childRows = []
            if (expandable) {
                kids.forEach(function (k) {
                    var childPath = root.childPath(path, k, Array.isArray(value))
                    childRows.push.apply(childRows, walk(root.childValue(value, k), k, childPath, depth + 1, true))
                })
            }
            var hasMatch = ownMatch || childRows.length > 0
            var showChildren = query !== "" ? hasMatch : !!root.expandedPaths[path]
            var type = root.typeName(value)
            var row = { key:String(key), path:path, depth:depth, value:root.valueText(value), raw:JSON.stringify(value, null, 2), expandable:expandable, expanded:showChildren, type:type, valueColor:root.valueColor(type) }
            if (!parentOpen || (query !== "" && !hasMatch)) return []
            return [row].concat(showChildren ? childRows : [])
        }
        out = walk(parsed, "$", "$", 0, true)
        root.rows = out
    }
    function toggle(path) {
        var next = Object.assign({}, root.expandedPaths)
        next[path] = !next[path]
        root.expandedPaths = next
        root.rebuild()
    }
    onTextChanged: rebuild()
    onNeedleChanged: rebuild()
    Component.onCompleted: rebuild()

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
        QQC2.ScrollView {
            visible: root.viewMode === "tree"
            Layout.fillWidth: true
            Layout.fillHeight: true
            background: null
            ColumnLayout {
                width: parent.width
                spacing: 0
                Repeater {
                    model: root.rows
                    delegate: RowLayout {
                        required property var modelData
                        Layout.fillWidth: true
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
                        PlasmaComponents.Label { id: valueLabel; Layout.fillWidth: true; Layout.minimumWidth: 0; text: modelData.value; color: modelData.valueColor; font.family: Kirigami.Theme.fixedWidthFont.family; elide: Text.ElideRight; PlasmaComponents.ToolTip { text: modelData.raw } }
                        PlasmaComponents.ToolButton { text: i18n("Value"); onClicked: root.copyValue(modelData.raw); PlasmaComponents.ToolTip { text: i18n("Copy value") } }
                        PlasmaComponents.ToolButton { text: i18n("Path"); onClicked: root.copyPath(modelData.path); PlasmaComponents.ToolTip { text: i18n("Copy JSON path") } }
                    }
                }
                PlasmaComponents.Label { visible: root.rows.length === 0 && root.error === ""; Layout.margins: Kirigami.Units.largeSpacing; text: root.needle ? i18n("No matching keys.") : root.emptyText; opacity: 0.7 }
            }
        }
        QQC2.TextArea {
            objectName: "inspectRawJson"
            visible: root.viewMode === "raw"
            Layout.fillWidth: true
            Layout.fillHeight: true
            text: root.formattedJson || root.text
            readOnly: true
            selectByMouse: true
            wrapMode: TextEdit.NoWrap
            font.family: Kirigami.Theme.fixedWidthFont.family
            Accessible.name: i18n("Raw JSON inspect output")
        }
    }
}
