pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.extras as PlasmaExtras

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

    signal openDetail(string recordId)
    signal openOutput(string title, string content, bool live, string recordId)

    readonly property var cfg: plasmoid.configuration

    /* weight is a fraction of the available width; the columns sum to 1. */
    readonly property var columns: [
        { "key": "name",    "title": i18n("Name"),    "weight": 0.24, "sort": "sortKey", "align": Qt.AlignLeft },
        { "key": "state",   "title": i18n("State"),   "weight": 0.16, "sort": "containerState",   "align": Qt.AlignLeft },
        { "key": "cpu",     "title": i18n("CPU"),     "weight": 0.08, "sort": "cpuPct",  "align": Qt.AlignRight },
        { "key": "mem",     "title": i18n("MEM"),     "weight": 0.08, "sort": "memPct",  "align": Qt.AlignRight },
        { "key": "image",   "title": i18n("Image"),   "weight": 0.22, "sort": "image",   "align": Qt.AlignLeft },
        { "key": "ports",   "title": i18n("Ports"),   "weight": 0.14, "sort": "ports",   "align": Qt.AlignLeft },
        { "key": "project", "title": i18n("Project"), "weight": 0.08, "sort": "project", "align": Qt.AlignLeft }
    ]

    readonly property int headerHeight: Math.round(Kirigami.Units.gridUnit * 0.9)
    readonly property int rowHeight: Math.round(Kirigami.Units.gridUnit * 0.8)

    function columnWidth(index) {
        return root.width * root.columns[index].weight
    }

    function sortBy(role) {
        if (root.proxy.sortRoleName === role) {
            root.proxy.sortOrder = root.proxy.sortOrder === Qt.AscendingOrder
                ? Qt.DescendingOrder
                : Qt.AscendingOrder
        } else {
            root.proxy.sortRoleName = role
            root.proxy.sortOrder = Qt.AscendingOrder
        }
    }

    function cellText(row, key) {
        if (key === "state") return row.status !== "" ? row.status : row.state
        if (key === "cpu") return row.isRunning && row.cpu !== "" ? row.cpu : "—"
        if (key === "mem") return row.isRunning && row.mem !== "" ? row.mem : "—"
        // Full Docker port syntax ("0.0.0.0:80->80/tcp") is unreadable in a
        // narrow column; the host side is what a reader actually wants.
        if (key === "ports") return row.ports === "" ? "—" : row.ports.replace(/->.*$/, "")
        if (key === "project") return row.project !== "" ? row.project : "—"
        if (key === "name") return row.name
        if (key === "image") return row.image !== "" ? row.image : "—"
        return "—"
    }

    // ---------------------------------------------------------- header ----

    Item {
        id: headerRow
        width: parent.width
        height: root.headerHeight

        Row {
            anchors.fill: parent

            Repeater {
                model: root.columns

                delegate: Rectangle {
                    id: headerCell
                    required property var modelData
                    required property int index

                    width: root.columnWidth(index)
                    height: headerRow.height
                    color: headerHover.hovered
                        ? Qt.alpha(Kirigami.Theme.highlightColor, 0.25)
                        : Qt.alpha(Kirigami.Theme.textColor, 0.06)

                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: 1
                        color: Qt.alpha(Kirigami.Theme.textColor, 0.2)
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
                            font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                        }

                        PlasmaComponents.Label {
                            visible: root.proxy.sortRoleName === headerCell.modelData.sort
                            text: root.proxy.sortOrder === Qt.AscendingOrder ? "▲" : "▼"
                            font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                        }
                    }

                    HoverHandler { id: headerHover }

                    TapHandler {
                        onTapped: root.sortBy(headerCell.modelData.sort)
                    }

                    PlasmaComponents.ToolTip {
                        text: i18n("Sort by %1", headerCell.modelData.title)
                    }
                }
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

        contentItem: ListView {
            id: table
            model: root.proxy
            width: scroll.width
            currentIndex: -1
            reuseItems: true
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            highlight: PlasmaExtras.Highlight {}
            highlightMoveDuration: Kirigami.Units.shortDuration
            highlightResizeDuration: 0

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
                required property string health
                required property bool isRunning
                required property string cpu
                required property string mem
                required property string ports
                required property string project
                required property string composeFiles
                required property string composeWorkDir

                // cellText() and the actions both want a plain record.
                readonly property var record: ({
                    "id": rowItem.containerKey,
                    "name": rowItem.name,
                    "image": rowItem.image,
                    "state": rowItem.containerState,
                    "status": rowItem.status,
                    "health": rowItem.health,
                    "isRunning": rowItem.isRunning,
                    "cpu": rowItem.cpu,
                    "mem": rowItem.mem,
                    "ports": rowItem.ports,
                    "project": rowItem.project,
                    "composeFiles": rowItem.composeFiles,
                    "composeWorkDir": rowItem.composeWorkDir
                })

                width: table.width
                height: root.rowHeight

                Rectangle {
                    anchors.fill: parent
                    color: rowItem.index % 2 === 1
                        ? Qt.alpha(Kirigami.Theme.textColor, 0.03)
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

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: Kirigami.Units.smallSpacing
                                anchors.rightMargin: Kirigami.Units.smallSpacing
                                spacing: Kirigami.Units.smallSpacing

                                StateDot {
                                    visible: cell.modelData.key === "state"
                                    containerState: rowItem.state
                                    health: root.cfg.showHealth ? rowItem.health : "none"
                                }

                                PlasmaComponents.Label {
                                    Layout.fillWidth: true
                                    text: root.cellText(rowItem.record, cell.modelData.key)
                                    elide: Text.ElideRight
                                    font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                                    font.bold: cell.modelData.key === "name"
                                    horizontalAlignment: cell.modelData.align === Qt.AlignRight
                                        ? Text.AlignRight
                                        : Text.AlignLeft
                                    color: !rowItem.isRunning
                                        && (cell.modelData.key === "name" || cell.modelData.key === "state")
                                        ? Kirigami.Theme.disabledTextColor
                                        : Kirigami.Theme.textColor
                                }

                                PlasmaComponents.ToolButton {
                                    visible: cell.modelData.key === "name" && rowItem.isRunning
                                        && root.backend.linksFor(rowItem.record).length > 0
                                    display: PlasmaComponents.AbstractButton.IconOnly
                                    icon.name: "internet-web-browser"
                                    text: i18n("Web links")
                                    implicitHeight: rowItem.height
                                    onClicked: webActions.popup(this, 0, height)
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
                    color: Qt.alpha(Kirigami.Theme.textColor, 0.08)
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

                ContainerActions {
                    id: webActions
                    backend: root.backend
                    record: rowItem.record
                    dialogs: root.dialogs
                    browserOnly: true
                }

                PlasmaComponents.ToolTip {
                    visible: rowHover.hovered
                    text: rowItem.name + "\n" + rowItem.image + "\n" + rowItem.containerKey
                }

                HoverHandler { id: rowHover }
            }
        }

        Kirigami.PlaceholderMessage {
            anchors.centerIn: parent
            width: parent.width - Kirigami.Units.largeSpacing * 2
            visible: table.count === 0
            text: !root.backend.engineActive
                ? i18n("Docker is not running")
                : (root.backend.total === 0
                   ? i18n("No containers yet.")
                   : i18n("No container matches your search."))
        }
    }
}
