import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import "../../lib/fuzzy.js" as Fuzzy

/*
 * SearchControl — search for the bottom strip, pinned to its right end.
 *
 * Looks (Settings → Appearance, or the search style):
 *   0  a button; pressing it opens a box above the strip (press it again to close)
 *   1  a button; pressing it slides a field out to its left (default)
 *   2  the field is always there
 * The field's icon at its left shows the scope and opens the scope choices:
 * Containers filters the list as you type; Go to lists pages and containers,
 * matched loosely (fuzzy); Images searches Docker Hub and opens the results
 * on Deploy. Enter acts, Escape closes. The button reads "Search" unless the
 * icon-only setting is on.
 */
Item {
    id: root

    required property var backend
    /* Owned by the list: what the Containers scope filters by. */
    property string containerText: ""
    /* The room the strip has: the field opens into what is left, never past the edge. */
    property real available: 0
    signal containerTextEdited(string text)
    signal pageRequested(string key)
    signal containerRequested(string recordId)
    signal imageSearchRequested(string query)

    readonly property int style: Math.max(0, Math.min(2, Number(plasmoid.configuration.searchStyle) || 0))
    /* No room for a usable field (a narrow strip): open the box instead, whatever the setting. */
    readonly property bool roomForField: root.available === 0 || root.available - Kirigami.Units.gridUnit * 20 >= Kirigami.Units.gridUnit * 6
    readonly property int look: root.style !== 0 && !root.roomForField ? 0 : root.style
    // The strip narrowed while the field was open: the field is gone, so is its open state.
    onLookChanged: if (root.look === 0 && root.fieldOpen) root.fieldOpen = false
    readonly property string scope: ["containers", "goto", "images"].indexOf(String(plasmoid.configuration.searchScope)) >= 0
        ? String(plasmoid.configuration.searchScope) : "containers"
    /* The label goes when asked, or when the strip is too narrow for it. */
    readonly property bool iconOnly: plasmoid.configuration.searchIconOnly === true || (root.available > 0 && root.available < Kirigami.Units.gridUnit * 34)
    /* Field open: pressed open (style 1) or always (style 2). */
    property bool fieldOpen: false
    readonly property bool expanded: root.look === 2 || (root.look === 1 && root.fieldOpen)
    property string otherText: ""
    readonly property string placeholder: root.scope === "goto" ? i18n("Go to…")
        : root.scope === "images" ? i18n("Search Docker Hub…") : i18n("Search containers…")
    readonly property string fieldText: root.scope === "containers" ? root.containerText : root.otherText
    readonly property string scopeGlyph: root.scope === "goto" ? "corner-down-right" : root.scope === "images" ? "layers" : "view-filter"
    readonly property string scopeLabel: root.scope === "goto" ? i18n("Go to") : root.scope === "images" ? i18n("Docker Hub images") : i18n("Containers")

    implicitWidth: row.implicitWidth
    implicitHeight: Kirigami.Units.gridUnit * 1.7

    function setScope(key) { plasmoid.configuration.searchScope = key }

    /* Ctrl+F and the button: open the search in its current look. */
    function open() {
        if (root.look === 0) { panel.open(); Qt.callLater(function () { panelField.forceActiveFocus(); panelField.selectAll() }); return }
        root.fieldOpen = true
        Qt.callLater(function () { inlineField.forceActiveFocus(); inlineField.selectAll() })
    }
    function close() {
        panel.close()
        if (root.look === 1) { root.fieldOpen = false; inlineField.focus = false }
    }
    function edited(text) {
        if (root.scope === "containers") root.containerTextEdited(text)
        else root.otherText = text
        if (root.scope !== "containers" && root.look !== 0) { if (text.trim() !== "") panel.open(); else panel.close() }
    }
    function submit() {
        if (root.scope === "goto") { root.runGoto(0); return }
        if (root.scope === "images") {
            const q = root.otherText.trim()
            if (q === "") return
            root.close()
            root.imageSearchRequested(q)
        }
    }

    /* Pages and containers for a Go to query, best match first. */
    readonly property var gotoResults: {
        if (root.scope !== "goto") return []
        const revision = root.backend.revision
        const q = root.otherText.trim()
        const pages = [
            {label: i18n("Containers"), glyph: "boxes", key: "containers"},
            {label: i18n("Deploy"), glyph: "package-plus", key: "deploy"},
            {label: i18n("Resources"), glyph: "drive-harddisk", key: "resources"},
            {label: i18n("Health"), glyph: "heart-pulse", key: "health"},
            {label: i18n("Doctor"), glyph: "stethoscope", key: "doctor"},
            {label: i18n("Activity"), glyph: "bell-ring", key: "activity"},
            {label: i18n("Problem Report"), glyph: "bug", key: "problem"},
            {label: i18n("Settings"), glyph: "configure", key: "settings"}
        ]
        if (q === "") return pages
        const containers = root.backend.records.map(function (r) {
            return {label: r.name, hint: r.project && r.project !== r.name ? r.project : "", glyph: r.isRunning ? "circle-play" : "circle-stop", recordId: r.id, text: r.name + " " + (r.project || "")}
        })
        const matched = Fuzzy.rank(q, pages.concat(containers), function (item) { return item.text || item.label })
        return matched.slice(0, 10)
    }
    function runGoto(index) {
        const item = root.gotoResults[index]
        if (!item) return
        root.close(); root.otherText = ""
        if (item.recordId) root.containerRequested(item.recordId)
        else root.pageRequested(item.key)
    }

    RowLayout {
        id: row
        anchors.fill: parent
        spacing: 0

        // The field slides out to the left of the button.
        Item {
            id: fieldSlot
            Layout.preferredWidth: root.expanded ? Math.max(Kirigami.Units.gridUnit * 3, Math.min(Kirigami.Units.gridUnit * 14, root.available - Kirigami.Units.gridUnit * 20)) : 0
            Layout.fillHeight: true
            clip: true
            visible: Layout.preferredWidth > 0
            Behavior on Layout.preferredWidth { NumberAnimation { duration: Kirigami.Units.shortDuration } }
            RowLayout {
                anchors.fill: parent
                spacing: Kirigami.Units.smallSpacing / 2
                DockButton {
                    id: scopeButton
                    objectName: "searchScopeButton"
                    iconOnly: true
                    flat: true
                    glyph: root.scopeGlyph
                    text: i18n("Search in: %1", root.scopeLabel)
                    onClicked: scopeMenu.popup(scopeButton, 0, scopeButton.height)
                }
                PlasmaComponents.TextField {
                    id: inlineField
                    objectName: "searchField"
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    placeholderText: root.placeholder
                    text: root.fieldText
                    onTextEdited: root.edited(text)
                    onAccepted: root.submit()
                    onActiveFocusChanged: if (!activeFocus && root.look === 1 && text === "" && !panel.opened) root.fieldOpen = false
                    Keys.onEscapePressed: { clear(); root.edited(""); root.close() }
                }
            }
        }

        DockButton {
            id: button
            objectName: "searchButton"
            visible: root.look !== 2
            iconOnly: root.iconOnly
            glyph: "search"
            text: i18n("Search")
            variant: panel.opened || root.fieldOpen ? "primary" : "flat"
            onClicked: {
                if (root.look === 0) { if (panel.opened) root.close(); else root.open() }
                else if (root.fieldOpen) root.close()
                else root.open()
            }
        }
    }

    PlasmaComponents.Menu {
        id: scopeMenu
        objectName: "searchScopeMenu"
        title: i18n("Search In")
        Repeater {
            model: [{key: "containers", label: i18n("Containers")}, {key: "goto", label: i18n("Go to")}, {key: "images", label: i18n("Docker Hub Images")}]
            delegate: PlasmaComponents.MenuItem {
                required property var modelData
                text: modelData.label
                checkable: true
                autoExclusive: true
                checked: root.scope === modelData.key
                onTriggered: root.setScope(modelData.key)
            }
        }
    }

    /* The box (style 0) and the results: Go to matches, or the Docker Hub hint. */
    QQC2.Popup {
        id: panel
        objectName: "searchPanel"
        parent: root
        // Clicks on the search control itself do not close it, so the button can toggle it.
        closePolicy: QQC2.Popup.CloseOnEscape | QQC2.Popup.CloseOnPressOutsideParent
        // Right-aligned to the button, opening leftwards; margins keep it inside the window.
        x: root.width - width
        margins: Kirigami.Units.smallSpacing
        y: -implicitHeight - Kirigami.Units.smallSpacing
        width: Math.min(Kirigami.Units.gridUnit * 24, Math.max(root.width, Kirigami.Units.gridUnit * 14))
        contentItem: ColumnLayout {
            spacing: Kirigami.Units.smallSpacing
            PlasmaComponents.TextField {
                id: panelField
                visible: root.look === 0
                Layout.fillWidth: true
                placeholderText: root.placeholder
                text: root.fieldText
                onTextEdited: root.edited(text)
                onAccepted: root.submit()
                Keys.onEscapePressed: { clear(); root.edited(""); root.close() }
            }
            Repeater {
                model: root.gotoResults
                delegate: DockButton {
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    variant: "flat"
                    glyph: modelData.glyph
                    text: modelData.hint ? i18nc("container (project)", "%1 (%2)", modelData.label, modelData.hint) : modelData.label
                    onClicked: root.runGoto(index)
                }
            }
            PlasmaComponents.Label {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                color: Kirigami.Theme.disabledTextColor
                font: Kirigami.Theme.smallFont
                text: root.scope === "images" ? i18n("Press Enter to search Docker Hub and open the results on Deploy.")
                    : root.scope === "goto" ? i18n("Letters in order will do: dpl finds Deploy. Enter opens the first match.")
                    : i18n("Filters the list by name, image, project, port or ID.")
            }
        }
    }
}
