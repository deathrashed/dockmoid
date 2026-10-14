pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.extras as PlasmaExtras
import "../../lib/parsers.js" as Parsers
import "../../lib/status.js" as Status
import "../../lib/style.js" as Style

/*
 * ContainerTable — the dense, sortable view.
 *
 * Built as a ListView of row delegates rather than a TableView on purpose:
 *
 *   - The columns are a fixed, known set, so virtualising per column buys
 *     nothing — every row has the same cells.
 *   - A TableView delegate has to declare each model role as a `required`
 *     property, and there is no way for the linter to check that a given
 *     model actually supplies them. A ListView delegate injects roles into
 *     declared required properties reliably.
 *
 * Either way the row declares its roles one at a time. Declaring a property
 * literally named `model` must be avoided: it shadows the delegate's own model
 * context, so every binding that reads through it silently becomes undefined.
 *   - Proportional column widths let the same table look right in the narrow
 *     popup and in a wide detached window without any horizontal scrolling.
 *
 * Sort state lives on the shared proxy: clicking a header writes sortRoleName /
 * sortOrder directly, so this view needs no back channel to the toolbar.
 */
Item {
    id: root

    required property var backend
    required property var proxy
    required property var dialogs
    property int detailLevel: 1

    signal openDetail(string recordId)
    signal openOutput(string title, string content, bool live, string recordId)

    readonly property var cfg: plasmoid.configuration

    // The full catalog is stable so saved column keys survive detail-level changes.
    readonly property var allColumns: [
        {key:"name", title:i18n("Name"), min:150, sort:"name", level:0},
        {key:"actions", title:i18n("Actions"), min:112, sort:"", level:1},
        {key:"state", title:i18n("Status"), min:125, sort:"containerState", level:0},
        {key:"cpu", title:i18n("CPU"), min:120, sort:"cpuPct", level:1},
        {key:"mem", title:i18n("RAM"), min:120, sort:"memPct", level:1},
        {key:"image", title:i18n("Image"), min:180, sort:"image", level:2},
        {key:"ports", title:i18n("Ports"), min:150, sort:"ports", level:2},
        {key:"project", title:i18n("Project"), min:120, sort:"project", level:2},
        {key:"id", title:i18n("Container ID"), min:115, sort:"containerKey", level:3},
        {key:"networks", title:i18n("Networks"), min:140, sort:"networks", level:3},
        {key:"memU", title:i18n("Memory used"), min:130, sort:"memPct", level:3}
    ]
    function savedKeys() {
        try { const v = root.cfg.tableVisibleColumns || ""; return Array.isArray(JSON.parse(v)) ? JSON.parse(v) : String(v).split(",").filter(function(x){return x !== ""}) } catch (e) { return String(root.cfg.tableVisibleColumns || "").split(",").filter(function(x){return x !== ""}) }
    }
    function widthMap() {
        try { return JSON.parse(root.cfg.tableColumnWidths || "{}") } catch (e) { return ({}) }
    }
    readonly property var columns: {
        var saved = root.savedKeys()
        var result = []
        for (let i = 0; i < root.allColumns.length; i++) {
            const c = root.allColumns[i]
            if (saved.length === 0 && c.level > root.detailLevel) continue
            const defaultVisible = c.level <= root.detailLevel
            if (saved.length === 0 ? defaultVisible : saved.indexOf(c.key) >= 0)
                result.push(c)
        }
        return result
    }
    readonly property real minimumTableWidth: columns.reduce(function(sum,c){return sum+(Number(root.widthMap()[c.key]) || c.min)},0)
    readonly property real tableWidth: Math.max(scroll.availableWidth, minimumTableWidth)
    readonly property int headerHeight: Math.round(Kirigami.Units.gridUnit * 1.8)
    readonly property int rowHeight: Math.round(Kirigami.Units.gridUnit * (detailLevel === 0 ? 2.1 : 2.6))

    function columnWidth(index) {
        var c = root.columns[index]
        if (!c) return 0
        return Math.max(c.min, Number(root.widthMap()[c.key]) || c.min)
    }
    function resizeColumn(key, width) {
        var map = root.widthMap()
        map[key] = Math.round(width)
        root.cfg.tableColumnWidths = JSON.stringify(map)
    }
    function toggleColumn(key, checked) {
        var keys = root.savedKeys()
        if (keys.length === 0) keys = root.allColumns.filter(function(c){return c.level <= root.detailLevel}).map(function(c){return c.key})
        var at = keys.indexOf(key)
        if (checked && at < 0) keys.push(key)
        if (!checked && at >= 0) keys.splice(at, 1)
        root.cfg.tableVisibleColumns = keys.join(",")
    }
    function sortBy(role) {
        if (root.cfg.sortRole === role) root.cfg.sortAscending = !root.cfg.sortAscending
        else { root.cfg.sortRole = role; root.cfg.sortAscending = true }
    }
    function cellText(row, key) {
        if (!row) return "—"
        if (key === "state") return Status.compactStatus(row.status, row.containerState || row.state, row.runningFor)
        if (key === "cpu") return row.isRunning && row.cpu !== "" ? row.cpu : "—"
        if (key === "mem") return row.isRunning && row.mem !== "" ? row.mem : "—"
        if (key === "ports") return row.ports === "" ? "—" : row.ports.replace(/->.*$/, "")
        if (key === "project") return row.project !== "" ? row.project : "—"
        if (key === "name") return row.name
        if (key === "image") return row.image !== "" ? row.image : "—"
        if (key === "id") return String(row.id || "").slice(0,12)
        if (key === "networks" || key === "memU") return row[key] || "—"
        return "—"
    }

    // ---------------------------------------------------------- header ----

    Item {
        id: headerRow
        width: parent.width
        height: root.headerHeight
        clip: true

        Row {
            objectName: "containerTableHeader"
            x: -table.contentX
            width: root.tableWidth
            height: parent.height

            Repeater {
                model: root.columns

                delegate: Rectangle {
                    id: headerCell
                    required property var modelData
                    required property int index

                    width: root.columnWidth(index)
                    height: headerRow.height
                    color: headerHover.hovered
                        ? Qt.alpha(Kirigami.Theme.highlightColor, Style.ALPHA.tintHover)
                        : Qt.alpha(Kirigami.Theme.textColor, Style.ALPHA.surface3)

                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: 1
                        color: Qt.alpha(Kirigami.Theme.textColor, Style.ALPHA.border)
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Kirigami.Units.smallSpacing
                        anchors.rightMargin: Kirigami.Units.smallSpacing
                        spacing: 2

                        PlasmaComponents.Label {
                            Layout.fillWidth: true
                            text: headerCell.modelData.title
                            font.bold: true
                            elide: Text.ElideRight
                            font.pointSize: Kirigami.Theme.defaultFont.pointSize
                        }

                        PlasmaComponents.Label {
                            visible: root.proxy.sortRoleName === headerCell.modelData.sort
                            text: root.proxy.sortOrder === Qt.AscendingOrder ? "▲" : "▼"
                            font: Kirigami.Theme.smallFont
                        }
                    }

                    HoverHandler { id: headerHover }

                    TapHandler {
                        onTapped: if (headerCell.modelData.sort !== "") root.sortBy(headerCell.modelData.sort)
                    }

                    PlasmaComponents.ToolTip {
                        visible: headerHover.hovered && headerCell.modelData.sort !== ""
                        text: i18n("Sort by %1%2", headerCell.modelData.title,
                            root.proxy.sortRoleName === headerCell.modelData.sort
                                ? (root.proxy.sortOrder === Qt.AscendingOrder ? i18n(" · ascending") : i18n(" · descending")) : "")
                    }
                    MouseArea {
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: 7
                        cursorShape: Qt.SplitHCursor
                        property real startWidth: 0
                        property real pressX: 0
                        onPressed: function(mouse) { startWidth = root.columnWidth(headerCell.index); pressX = mapToItem(headerRow, mouse.x, mouse.y).x }
                        onPositionChanged: function(mouse) {
                            if (pressed) root.resizeColumn(headerCell.modelData.key, Math.max(headerCell.modelData.min, startWidth + mapToItem(headerRow, mouse.x, mouse.y).x - pressX))
                        }
                    }
                }
            }
        }
        PlasmaComponents.ToolButton {
            id: columnsButton
            anchors.right: parent.right
            anchors.top: parent.top
            height: parent.height
            icon.name: "configure"
            Accessible.name: i18n("Choose visible columns")
            z: 2
            PlasmaComponents.ToolTip.text: i18n("Choose visible columns")
            PlasmaComponents.ToolTip.visible: hovered
            onClicked: columnsMenu.popup(columnsButton, 0, height)
            PlasmaComponents.Menu {
                id: columnsMenu
                title: i18n("Visible columns")
                PlasmaComponents.MenuItem { text: i18n("Name"); checkable: true; checked: root.columns.some(function(c){return c.key === "name"}); onToggled: root.toggleColumn("name", checked) }
                PlasmaComponents.MenuItem { text: i18n("Actions"); checkable: true; checked: root.columns.some(function(c){return c.key === "actions"}); onToggled: root.toggleColumn("actions", checked) }
                PlasmaComponents.MenuItem { text: i18n("Status"); checkable: true; checked: root.columns.some(function(c){return c.key === "state"}); onToggled: root.toggleColumn("state", checked) }
                PlasmaComponents.MenuItem { text: i18n("CPU"); checkable: true; checked: root.columns.some(function(c){return c.key === "cpu"}); onToggled: root.toggleColumn("cpu", checked) }
                PlasmaComponents.MenuItem { text: i18n("RAM"); checkable: true; checked: root.columns.some(function(c){return c.key === "mem"}); onToggled: root.toggleColumn("mem", checked) }
                PlasmaComponents.MenuItem { text: i18n("Image"); checkable: true; checked: root.columns.some(function(c){return c.key === "image"}); onToggled: root.toggleColumn("image", checked) }
                PlasmaComponents.MenuItem { text: i18n("Ports"); checkable: true; checked: root.columns.some(function(c){return c.key === "ports"}); onToggled: root.toggleColumn("ports", checked) }
                PlasmaComponents.MenuItem { text: i18n("Project"); checkable: true; checked: root.columns.some(function(c){return c.key === "project"}); onToggled: root.toggleColumn("project", checked) }
                PlasmaComponents.MenuItem { text: i18n("Container ID"); checkable: true; checked: root.columns.some(function(c){return c.key === "id"}); onToggled: root.toggleColumn("id", checked) }
                PlasmaComponents.MenuItem { text: i18n("Networks"); checkable: true; checked: root.columns.some(function(c){return c.key === "networks"}); onToggled: root.toggleColumn("networks", checked) }
                PlasmaComponents.MenuItem { text: i18n("Memory used"); checkable: true; checked: root.columns.some(function(c){return c.key === "memU"}); onToggled: root.toggleColumn("memU", checked) }
            }
        }
    }

    // ----------------------------------------------------------- body -----

    PlasmaComponents.ScrollView {
        id: scroll
        anchors.top: headerRow.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        background: null
        Controls.ScrollBar.horizontal.policy: root.minimumTableWidth > scroll.availableWidth ? Controls.ScrollBar.AsNeeded : Controls.ScrollBar.AlwaysOff
        Controls.ScrollBar.vertical.policy: Controls.ScrollBar.AlwaysOn

        contentItem: ListView {
            id: table
            objectName: "containerTableBody"
            model: root.proxy
            width: scroll.availableWidth
            contentWidth: root.tableWidth
            flickableDirection: Flickable.AutoFlickIfNeeded
            currentIndex: -1
            reuseItems: true
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            delegate: Item {
                id: rowItem
                required property int index

                // Roles are declared individually: declaring a property called
                // `model` would shadow the delegate's own model context and
                // leave every binding below reading undefined.
                required property string containerKey
                required property string name
                required property string image
                required property string containerState
                required property string status
                required property string runningFor
                required property string health
                required property bool isRunning
                required property string cpu
                required property string mem
                required property real cpuPct
                required property real memPct
                required property string ports
                required property string project
                required property string composeFiles
                required property string composeWorkDir

                // cellText() and the actions both want a plain record.
                readonly property var record: {
        return root.backend.revision >= 0 ? root.backend.findRecord(rowItem.containerKey) || {id: rowItem.containerKey, name: rowItem.name, image: rowItem.image,
            state: rowItem.containerState, isRunning: rowItem.isRunning, pinned: false, updateAvailable: false,
            restartPolicy: "", probe: "", project: rowItem.project, service: "", ports: rowItem.ports,
            composeFiles: rowItem.composeFiles, composeWorkDir: rowItem.composeWorkDir} : null
    }
                readonly property var operation: {
                    const revision = root.backend.operationsRevision
                    return root.backend.operationFor(rowItem.containerKey)
                }
                readonly property string attention: Status.attentionKind(rowItem.record)

                width: root.tableWidth
                height: root.rowHeight

                Rectangle {
                    anchors.fill: parent
                    color: rowItem.index % 2 === 1
                        ? Qt.alpha(Kirigami.Theme.textColor, Style.ALPHA.surface1)
                        : "transparent"
                }

                Row {
                    anchors.fill: parent

                    Repeater {
                        model: root.columns

                        delegate: Item {
                            id: cell
                            required property var modelData
                            required property int index

                            width: root.columnWidth(index)
                            height: rowItem.height

                            ResourceMeter {
                                visible: root.cfg.showResourceBars && rowItem.isRunning && rowItem.cpu !== "" && (cell.modelData.key === "cpu" || cell.modelData.key === "mem")
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.leftMargin: Kirigami.Units.smallSpacing
                                anchors.rightMargin: Kirigami.Units.smallSpacing
                                compact: true
                                label: cell.modelData.key === "cpu" ? "CPU" : "RAM"
                                value: cell.modelData.key === "cpu" ? rowItem.cpuPct : rowItem.memPct
                                maximum: root.cfg.resourceBarMax
                            }
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: Kirigami.Units.smallSpacing
                                anchors.rightMargin: Kirigami.Units.smallSpacing
                                spacing: Kirigami.Units.smallSpacing

                                ActionIcon {
                                    visible: cell.modelData.key === "state" && ["failed", "unhealthy", "paused", "restarting"].indexOf(rowItem.attention) >= 0
                                    glyph: rowItem.attention === "failed" ? "circle-x" : rowItem.attention === "unhealthy" ? "dialog-warning" : rowItem.attention === "paused" ? "media-playback-pause" : "view-refresh"
                                    implicitWidth: Kirigami.Units.iconSizes.small
                                    implicitHeight: implicitWidth
                                    color: rowItem.attention === "failed" || rowItem.attention === "unhealthy" ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.neutralTextColor
                                }
                                StateDot {
                                    visible: cell.modelData.key === "state"
                                    containerState: rowItem.containerState
                                    health: root.cfg.showHealth ? rowItem.health : "none"
                                    failed: rowItem.attention === "failed"
                                }
                                PlasmaComponents.BusyIndicator {
                                    visible: cell.modelData.key === "state" && rowItem.operation.busy
                                    running: visible
                                    Layout.preferredWidth: Kirigami.Units.iconSizes.small
                                    Layout.preferredHeight: Layout.preferredWidth
                                }

                                ServiceIcon {
                                    visible: cell.modelData.key === "name"
                                    backend: root.backend
                                    record: rowItem.record
                                    iconSize: 24
                                }

                                PlasmaComponents.Label {
                                    Layout.fillWidth: true
                                    visible: cell.modelData.key !== "actions" && !(root.cfg.showResourceBars && rowItem.isRunning && rowItem.cpu !== "" && (cell.modelData.key === "cpu" || cell.modelData.key === "mem"))
                                    text: cell.modelData.key === "state"
                                        ? (rowItem.operation.label || ((rowItem.attention === "failed" ? i18n("Failed") + " · " : rowItem.attention === "unhealthy" ? i18n("Unhealthy") + " · " : rowItem.attention === "paused" ? i18n("Paused") + " · " : rowItem.attention === "restarting" ? i18n("Restarting") + " · " : "") + Status.compactStatus(rowItem.status, rowItem.containerState, rowItem.runningFor)))
                                        : root.cellText(rowItem.record, cell.modelData.key)
                                    PlasmaComponents.ToolTip.text: (cell.modelData.key === "state" ? (rowItem.status || rowItem.containerState) : cell.modelData.key === "id" ? String(rowItem.record.id || rowItem.containerKey) : root.cellText(rowItem.record, cell.modelData.key)) + (rowItem.operation.label ? "\n" + rowItem.operation.label : "")
                                    PlasmaComponents.ToolTip.visible: rowHover.hovered
                                    elide: Text.ElideRight
                                    font.pointSize: Kirigami.Theme.defaultFont.pointSize
                                    font.bold: cell.modelData.key === "name"
                                    horizontalAlignment: (cell.modelData.key === "cpu" || cell.modelData.key === "mem")
                                        ? Text.AlignRight
                                        : Text.AlignLeft
                                    color: cell.modelData.key === "state" && rowItem.operation.label
                                        ? (rowItem.operation.ok ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.negativeTextColor)
                                        : rowItem.attention === "failed" || rowItem.attention === "unhealthy"
                                            ? Kirigami.Theme.negativeTextColor
                                            : rowItem.attention === "paused" || rowItem.attention === "restarting"
                                                ? Kirigami.Theme.neutralTextColor
                                                : !rowItem.isRunning && (cell.modelData.key === "name" || cell.modelData.key === "state")
                                                    ? Kirigami.Theme.disabledTextColor : Kirigami.Theme.textColor
                                }

                                RowLayout {
                                    visible: cell.modelData.key === "actions"
                                    spacing: 0
                                    ActionToolButton { visible: root.detailLevel >= 2; glyph:"document-view"; text:i18n("Details"); onClicked:root.openDetail(rowItem.containerKey) }
                                    ActionToolButton {
                                        visible: root.detailLevel >= 1
                                        glyph: rowItem.isRunning ? "media-playback-stop" : "media-playback-start"
                                        text: rowItem.isRunning ? i18n("Stop") : i18n("Start")
                                        enabled: !root.backend.readOnly && !rowItem.operation.busy && (rowItem.isRunning ? Parsers.canStop(rowItem.containerState) : Parsers.canStart(rowItem.containerState))
                                        onClicked: rowItem.isRunning ? root.backend.stopContainer(rowItem.record) : root.backend.startContainer(rowItem.record)
                                    }
                                    ActionToolButton { glyph:"application-menu"; text:i18n("Container actions"); onClicked:actions.popup(this,0,height) }
                                }
                            }
                        }
                    }
                }

                // A hairline that survives column resizing, drawn last.
                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: 1
                    color: Qt.alpha(Kirigami.Theme.textColor, Style.ALPHA.divider)
                }

                TapHandler {
                    onDoubleTapped: root.openDetail(rowItem.containerKey)
                }

                TapHandler {
                    acceptedButtons: Qt.RightButton
                    onTapped: function (eventPoint) {
                        actions.popup(rowItem, eventPoint.position.x, eventPoint.position.y)
                    }
                }

                ContainerActions {
                    id: actions
                    backend: root.backend
                    record: rowItem.record
                    dialogs: root.dialogs
                    onOpenDetail: function (recordId) { root.openDetail(recordId) }
                    onOpenOutput: function (title, content, live, recordId) {
                        root.openOutput(title, content, live, recordId)
                    }
                }

                PlasmaComponents.ToolTip {
                    visible: rowHover.hovered
                    text: rowItem.name + "\n" + rowItem.image + "\n" + rowItem.containerKey
                }

                HoverHandler { id: rowHover;onHoveredChanged:if(hovered)root.backend.previewContainer(rowItem.containerKey,false) }
                TapHandler {onTapped:root.backend.previewContainer(rowItem.containerKey,true)}
            }
        }

        Kirigami.PlaceholderMessage {
            anchors.centerIn: parent
            width: parent.width - Kirigami.Units.largeSpacing * 2
            visible: table.count === 0
            text: !root.backend.engineActive
                ? i18n("%1 is not running", root.backend.engineName)
                : (root.backend.total === 0
                   ? i18n("No containers yet.")
                   : i18n("No container matches your search."))
        }
    }
}
