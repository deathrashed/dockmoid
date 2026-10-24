import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import org.kde.kirigami as Kirigami
import "../backend" as Backend
import "../../lib/iconCatalog.js" as Catalog

Controls.Dialog {
    id: dialog
    parent: Controls.Overlay.overlay
    required property var backend
    property var record: null
    property string mappingKey: ""
    property string mappingLabel: ""
    property url selectedFile
    property var selectedEntry: null
    property var matches: []
    property string message: ""
    property bool importing: false
    signal iconSaved()
    title: i18n("Choose icon — %1", mappingLabel)
    modal: true
    anchors.centerIn: parent
    width: Math.min(parent ? parent.width - 24 : 660, 660)
    height: Math.min(parent ? parent.height - 24 : 600, 600)

    function choose(rec) {
        record = rec
        mappingKey = ""
        mappingLabel = rec.name
        begin(rec.service || rec.name)
    }
    function chooseForKey(key, label, query) {
        record = null
        mappingKey = key
        mappingLabel = label
        begin(query || "")
    }
    function begin(query) {
        selectedFile = ""
        selectedEntry = null
        message = ""
        importing = false
        scope.currentIndex = 0
        original.checked = true
        searchField.text = query
        open()
        catalog.load(false)
        filterTimer.restart()
        searchField.forceActiveFocus()
        searchField.selectAll()
    }
    function applyIcon() {
        var store = backend.customIconStore
        var rec = record
        var key = mappingKey !== "" ? mappingKey : scope.currentIndex === 1 ? store.keyForName(rec.name)
            : scope.currentIndex === 2 ? store.keyForImage(rec.image) : store.keyFor(rec)
        var completed = function(ok, error) {
            dialog.importing = false
            if (ok) { dialog.iconSaved(); dialog.close() }
            else dialog.message = error
        }
        importing = true
        if (selectedEntry) store.importRemote(key, selectedEntry.url, original.checked, mappingLabel, completed)
        else store.importFile(key, selectedFile, original.checked, mappingLabel, completed)
    }

    Backend.IconCatalog { id: catalog; onEntriesChanged: filterTimer.restart() }
    Timer {
        id: filterTimer
        interval: 150
        onTriggered: dialog.matches = Catalog.search(catalog.entries, searchField.text,
            provider.currentIndex === 1 ? "dashboard" : provider.currentIndex === 2 ? "selfhst" : "all")
    }
    FileDialog {
        id: picker
        title: i18n("Choose a local service icon")
        nameFilters: [i18n("Images (*.svg *.png *.webp)")]
        onAccepted: { dialog.selectedEntry = null; dialog.selectedFile = selectedFile; dialog.message = "" }
    }

    contentItem: ColumnLayout {
        spacing: Kirigami.Units.smallSpacing
        RowLayout {
            Layout.fillWidth: true
            Controls.TextField {
                id: searchField
                Layout.fillWidth: true
                placeholderText: i18n("Search service icons…")
                enabled: !dialog.importing
                onTextChanged: filterTimer.restart()
            }
            Controls.ComboBox {
                id: provider
                model: [i18n("Both libraries"), i18n("Dashboard Icons"), i18n("selfh.st")]
                enabled: !dialog.importing
                onCurrentIndexChanged: filterTimer.restart()
            }
            ActionToolButton {
                glyph: "view-refresh"
                text: i18n("Refresh icon catalogs")
                enabled: !catalog.busy && !dialog.importing
                onClicked: catalog.load(true)
            }
        }
        RowLayout {
            Controls.BusyIndicator { visible: catalog.busy; running: visible; implicitWidth: 20; implicitHeight: 20 }
            Controls.Label {
                Layout.fillWidth: true
                text: catalog.busy ? i18n("Loading icon catalogs…") : i18np("%1 icon found", "%1 icons found", dialog.matches.length)
                color: Kirigami.Theme.disabledTextColor
                font: Kirigami.Theme.smallFont
            }
        }
        Controls.ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: Kirigami.Units.gridUnit * 4
            contentItem: GridView {
                id: results
                clip: true
                model: dialog.matches
                cellWidth: width / Math.max(1, Math.floor(width / 100))
                cellHeight: 94
                cacheBuffer: cellHeight
                boundsBehavior: Flickable.StopAtBounds
                delegate: Controls.ItemDelegate {
                    id: result
                    required property var modelData
                    width: results.cellWidth - 4
                    height: results.cellHeight - 4
                    enabled: !dialog.importing
                    highlighted: dialog.selectedEntry !== null && dialog.selectedEntry.id === modelData.id
                    onClicked: { dialog.selectedEntry = modelData; dialog.selectedFile = modelData.url; dialog.message = "" }
                    contentItem: ColumnLayout {
                        spacing: 1
                        Image {
                            source: result.modelData.url
                            Layout.alignment: Qt.AlignHCenter
                            Layout.preferredWidth: 40
                            Layout.preferredHeight: 40
                            sourceSize.width: 80
                            sourceSize.height: 80
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                        }
                        Controls.Label { Layout.fillWidth: true; text: result.modelData.displayName; elide: Text.ElideRight; horizontalAlignment: Text.AlignHCenter }
                        Controls.Label { Layout.fillWidth: true; text: result.modelData.providerName; color: Kirigami.Theme.disabledTextColor; font: Kirigami.Theme.smallFont; horizontalAlignment: Text.AlignHCenter }
                    }
                    Controls.ToolTip.visible: hovered
                    Controls.ToolTip.text: modelData.displayName + " — " + modelData.providerName
                }
                Controls.Label {
                    anchors.centerIn: parent
                    visible: !catalog.busy && results.count === 0
                    text: catalog.entries.length > 0 ? i18n("No matching icons. Try another name or browse files.") : i18n("The catalogs are unavailable. You can still browse local files.")
                    width: parent.width - 24
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            Image { id: originalImage; source: dialog.selectedFile; visible: false }
            Kirigami.Icon {
                visible: String(dialog.selectedFile) !== ""
                implicitWidth: 40; implicitHeight: 40
                source: dialog.selectedFile
                isMask: !original.checked
                color: Kirigami.Theme.textColor
            }
            Controls.Label {
                Layout.fillWidth: true
                text: dialog.selectedEntry ? dialog.selectedEntry.displayName + " — " + dialog.selectedEntry.providerName
                    : String(dialog.selectedFile) !== "" ? i18n("Local file: %1", String(dialog.selectedFile).split("/").pop()) : i18n("Choose an icon above or browse your files.")
                elide: Text.ElideRight
            }
            ActionButton {
                text: i18n("Browse files…")
                glyph: "document-open"
                enabled: !dialog.importing
                onClicked: picker.open()
            }
        }
        Controls.ComboBox {
            id: scope
            Layout.fillWidth: true
            visible: dialog.mappingKey === ""
            enabled: !dialog.importing
            model: [i18n("Apply to this Compose service or container name"), i18n("Apply to this container name"), i18n("Apply to any container using this image")]
        }
        Controls.CheckBox { id: original; text: i18n("Keep original colours"); checked: true; enabled: !dialog.importing }
        Controls.Label {
            Layout.fillWidth: true
            text: i18n("Online previews need internet. Chosen artwork is saved locally, with its source and license, and survives widget updates.")
            color: Kirigami.Theme.disabledTextColor
            font: Kirigami.Theme.smallFont
            wrapMode: Text.WordWrap
        }
        Kirigami.InlineMessage {
            Layout.fillWidth: true
            visible: catalog.error !== "" || dialog.message !== ""
            text: dialog.message !== "" ? dialog.message : catalog.error
            type: Kirigami.MessageType.Warning
        }
        Controls.Label {
            Layout.fillWidth: true
            visible: originalImage.status === Image.Error
            text: i18n("This preview could not load. Try another icon or browse a local file.")
            wrapMode: Text.WordWrap
            color: Kirigami.Theme.negativeTextColor
        }
    }
    footer: Controls.DialogButtonBox {
        Controls.Button { text: i18n("Cancel"); enabled: !dialog.importing; Controls.DialogButtonBox.buttonRole: Controls.DialogButtonBox.RejectRole }
        Controls.Button {
            text: dialog.importing ? i18n("Saving…") : i18n("Use this icon")
            enabled: !dialog.importing && originalImage.status === Image.Ready
            Controls.DialogButtonBox.buttonRole: Controls.DialogButtonBox.ActionRole
            onClicked: dialog.applyIcon()
        }
        onRejected: dialog.close()
    }
}
