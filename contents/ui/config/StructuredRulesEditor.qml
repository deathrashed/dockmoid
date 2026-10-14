import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts

import org.kde.kirigami as Kirigami

/* Small row editor for existing line based settings, with the source format
 * still available for advanced users and malformed/comment lines preserved. */
ColumnLayout {
    id: root

    property string value: ""
    property string title: ""
    property string delimiter: "="
    property var headers: [i18n("Match"), i18n("Value")]
    property string example: ""
    property string kind: "keyValue" // keyValue, probe, launcher
    property bool allowEmptyValue: false
    property bool rawMode: false
    property var rows: []
    property bool parsing: false

    function parse(text) {
        parsing = true
        var parsed = []
        String(text || "").split("\n").forEach(function(line) {
            if (line.trim() === "") return
            if (/^\s*#/.test(line)) {
                parsed.push({raw: line, fields: [], fixed: true})
                return
            }
            var fields = line.split(root.delimiter)
            if ((root.kind === "launcher" && fields.length !== 4)
                    || (root.kind !== "launcher" && fields.length < 1)) {
                parsed.push({raw: line, fields: [], fixed: true})
                return
            }
            while (fields.length < root.headers.length) fields.push("")
            parsed.push({raw: "", fields: fields, fixed: false})
        })
        rows = parsed
        parsing = false
    }

    function serialize() {
        var lines = []
        rows.forEach(function(row) {
            if (row.fixed) lines.push(row.raw)
            else lines.push(row.fields.join(root.delimiter))
        })
        parsing = true
        value = lines.join("\n")
        parsing = false
    }

    function setField(rowIndex, fieldIndex, text) {
        var next = rows.slice()
        var row = {raw: next[rowIndex].raw, fixed: next[rowIndex].fixed, fields: next[rowIndex].fields.slice()}
        row.fields[fieldIndex] = text
        next[rowIndex] = row
        rows = next
        serialize()
    }

    function addRow() {
        var fields = []
        for (let i = 0; i < headers.length; i++) fields.push("")
        var next = rows.slice()
        next.push({raw: "", fields: fields, fixed: false})
        rows = next
        serialize()
    }

    function removeRow(rowIndex) {
        var next = rows.slice()
        next.splice(rowIndex, 1)
        rows = next
        serialize()
    }

    function errorFor(row) {
        if (row.fixed) return i18n("This line is kept as written; edit it in advanced text mode.")
        var f = row.fields
        if (!String(f[0] || "").trim()) return i18n("Enter a match value.")
        if (kind === "probe" && !/^https?:\/\/[^\s]+$/i.test(String(f[1] || "").trim()))
            return i18n("Use a complete http:// or https:// address.")
        if (kind === "launcher") {
            if (!String(f[1] || "").trim()) return i18n("Enter an icon name.")
            if (["container", "project"].indexOf(String(f[2] || "").trim()) < 0)
                return i18n("Scope must be container or project.")
            if (!String(f[3] || "").trim()) return i18n("Enter a command.")
        } else if (!allowEmptyValue && !String(f[1] || "").trim()) {
            return i18n("Enter a value.")
        }
        return ""
    }

    onValueChanged: if (!parsing) parse(value)
    Component.onCompleted: parse(value)

    RowLayout {
        Layout.fillWidth: true
        Controls.Label { Layout.fillWidth: true; text: root.title; font.bold: true }
        Controls.Button {
            text: root.rawMode ? i18n("Structured rows") : i18n("Advanced text")
            icon.name: root.rawMode ? "view-list-details" : "accessories-text-editor"
            onClicked: root.rawMode = !root.rawMode
        }
        Controls.Button {
            visible: !root.rawMode
            text: i18n("Add row")
            icon.name: "list-add"
            onClicked: root.addRow()
        }
    }

    Controls.ScrollView {
        visible: !root.rawMode
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        Layout.preferredHeight: Math.min(Kirigami.Units.gridUnit * 9,
                                        Math.max(Kirigami.Units.gridUnit * 3, root.rows.length * Kirigami.Units.gridUnit * 2.2))
        ListView {
            id: ruleList
            model: root.rows
            clip: true
            spacing: Kirigami.Units.smallSpacing
            delegate: ColumnLayout {
                id: rowDelegate
                readonly property int rowIndex: index
                readonly property var rule: modelData
                width: ListView.view.width
                spacing: 2
                RowLayout {
                    Layout.fillWidth: true
                    visible: !modelData.fixed
                    Repeater {
                        model: root.headers.length
                        delegate: Controls.TextField {
                            readonly property int columnIndex: index
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            placeholderText: root.headers[columnIndex]
                            text: rowDelegate.rule.fields[columnIndex] || ""
                            onTextEdited: root.setField(rowDelegate.rowIndex, columnIndex, text)
                        }
                    }
                    Controls.Button {
                        text: i18n("Remove")
                        icon.name: "list-remove"
                        onClicked: root.removeRow(rowDelegate.rowIndex)
                    }
                }
                Controls.Label {
                    visible: modelData.fixed
                    Layout.fillWidth: true
                    text: modelData.raw
                    elide: Text.ElideMiddle
                    color: Kirigami.Theme.disabledTextColor
                }
                Controls.Label {
                    visible: !modelData.fixed && root.errorFor(modelData) !== ""
                    Layout.fillWidth: true
                    text: root.errorFor(modelData)
                    color: Kirigami.Theme.negativeTextColor
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                }
            }
        }
    }

    Controls.TextArea {
        visible: root.rawMode
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        Layout.preferredHeight: Kirigami.Units.gridUnit * 8
        wrapMode: TextEdit.NoWrap
        font.family: Kirigami.Theme.fixedWidthFont.family
        text: root.value
        selectByMouse: true
        onTextEdited: root.value = text
    }
    Controls.Label {
        visible: !root.rawMode && root.rows.length === 0
        text: root.example
        color: Kirigami.Theme.disabledTextColor
    }
}
