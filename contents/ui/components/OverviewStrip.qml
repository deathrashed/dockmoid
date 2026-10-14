import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "../../lib/style.js" as Style

/*
 * OverviewStrip — the numbers that matter, as filters, plus the controls people
 * reach for most: the view switcher, activity, read-only mode and view options.
 */
Item {
    id: root

    required property var backend
    required property var cfg
    property string stateFilter: "all"
    property bool problemsOnly: false
    property int viewMode: 0

    signal filterRequested(string state)
    signal attentionRequested()
    signal updatesRequested()
    signal viewRequested(int mode)
    signal optionsRequested(Item anchor)

    readonly property bool wide: width >= Kirigami.Units.gridUnit * 38
    readonly property bool noFilter: root.stateFilter === "all" && !root.problemsOnly
    readonly property var viewChoices: [
        {mode: 0, glyph: "layout-list", label: i18n("List view")},
        {mode: 1, glyph: "table-2", label: i18n("Table view")},
        {mode: 3, glyph: "layout-grid", label: i18n("Grid view")},
        {mode: 2, glyph: "folder-tree", label: i18n("Group by project")}
    ]

    implicitHeight: grid.implicitHeight

    RowLayout {
        id: grid
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Kirigami.Units.largeSpacing

        Flow {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            spacing: Kirigami.Units.smallSpacing
            StatTile { visible: root.wide; compact: !root.wide; glyph: "layers"; value: root.backend.total; label: i18n("All"); toneName: "indigo"; active: root.noFilter; onClicked: root.filterRequested("all") }
            StatTile { compact: !root.wide; glyph: "circle-play"; value: root.backend.running; label: i18n("Running"); toneName: "ok"; active: root.stateFilter === "running" && !root.problemsOnly; onClicked: root.filterRequested("running") }
            StatTile { compact: !root.wide; glyph: "circle-pause"; value: root.backend.stopped; label: i18n("Stopped"); toneName: "slate"; active: root.stateFilter === "stopped" && !root.problemsOnly; onClicked: root.filterRequested("stopped") }
            StatTile { compact: !root.wide; visible: root.backend.notCreated > 0; glyph: "package-plus"; value: root.backend.notCreated; label: i18n("Not created"); toneName: "sky"; active: root.stateFilter === "not-created" && !root.problemsOnly; onClicked: root.filterRequested("not-created") }
            StatTile { compact: !root.wide; glyph: "triangle-alert"; value: root.backend.problemCount; label: i18n("Attention"); toneName: root.backend.problemCount > 0 ? "rose" : "slate"; active: root.problemsOnly; onClicked: root.attentionRequested() }
            StatTile { compact: !root.wide; visible: root.backend.updateCount > 0; glyph: "cloud-download"; value: root.backend.updateCount; label: i18n("Updates"); toneName: "violet"; onClicked: root.updatesRequested() }
        }

        RowLayout {
            Layout.alignment: Qt.AlignTop | Qt.AlignRight
            spacing: Kirigami.Units.smallSpacing / 2

            Pill {
                visible: root.wide && root.cfg.readOnly
                text: i18n("Read-only")
                tone: "warn"
                glyph: "lock"
            }
            Rectangle {
                visible: root.wide
                implicitWidth: viewRow.implicitWidth + 4
                implicitHeight: viewRow.implicitHeight + 4
                radius: Kirigami.Units.smallSpacing * 1.5
                color: Qt.alpha(Kirigami.Theme.textColor, Style.ALPHA.surface2)
                border.color: Qt.alpha(Kirigami.Theme.textColor, Style.ALPHA.borderFaint)
                Row {
                    id: viewRow
                    anchors.centerIn: parent
                    Repeater {
                        model: root.viewChoices
                        delegate: ActionToolButton {
                            required property var modelData
                            glyph: modelData.glyph
                            text: modelData.label
                            checkable: true
                            checked: root.viewMode === modelData.mode
                            onClicked: root.viewRequested(modelData.mode)
                        }
                    }
                }
            }
            ActionToolButton {
                id: optionsButton
                glyph: "sliders-horizontal"
                text: i18n("Sort, detail and preview options")
                onClicked: root.optionsRequested(optionsButton)
            }
        }
    }
}
