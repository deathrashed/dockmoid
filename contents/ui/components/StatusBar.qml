import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import "../../lib/style.js" as Style

/*
 * StatusBar — the footer: how many containers are in each state (tap one to
 * filter), and the host's CPU and RAM. Coloured icons, plain numbers.
 */
Item {
    id: root
    required property var backend
    signal countFilter(string state)
    signal attentionFilterRequested()
    /* Home: back to the default view, with nothing filtered and nothing open. */
    signal homeRequested()
    /* Refresh, at the far left before the counts. */
    signal refreshRequested()
    property string refreshTip: ""
    readonly property var cfg: plasmoid.configuration
    readonly property bool compact: width < 560
    /*
     * The last refresh failed: the counts and colours are the last known
     * state, not a fresh check. A clock and the data's age replace CPU/RAM
     * (just as old), the counts dim, and a click retries. The age is re-read
     * every 30 s while stale.
     */
    readonly property bool stale: root.backend.dataStale && root.backend.lastUpdatedMs > 0
    property double now: Date.now()
    Timer { interval: 30000; repeat: true; running: root.stale && root.visible; onTriggered: root.now = Date.now() }
    onStaleChanged: root.now = Date.now()
    readonly property int staleSecs: Math.max(0, Math.round((root.now - root.backend.lastUpdatedMs) / 1000))
    readonly property string staleAge: root.staleSecs < 90 ? i18nc("seconds", "%1s", root.staleSecs)
        : root.staleSecs < 5400 ? i18nc("minutes", "%1m", Math.round(root.staleSecs / 60))
        : i18nc("hours", "%1h", Math.round(root.staleSecs / 3600))

    implicitHeight: Math.max(row.implicitHeight, Kirigami.Units.gridUnit * 1.5) + Kirigami.Units.smallSpacing * 2

    Tones { id: tones }

    Rectangle { anchors.fill: parent; color: Qt.alpha(Kirigami.Theme.textColor, Style.ALPHA.surface1) }

    component Count: Item {
        id: count
        property int value: 0
        property string glyph: "layers"
        property string description: ""
        property string toneName: "muted"
        property string filterState: "all"
        property bool attention: false
        implicitWidth: line.implicitWidth
        implicitHeight: line.implicitHeight
        RowLayout {
            id: line
            anchors.fill: parent
            spacing: Kirigami.Units.smallSpacing / 2
            ActionIcon { glyph: count.glyph; color: tones.color(count.toneName); implicitWidth: root.compact ? 12 : Kirigami.Units.iconSizes.small; implicitHeight: implicitWidth }
            PlasmaComponents.Label { text: String(count.value); font.pointSize: root.compact ? Kirigami.Theme.smallFont.pointSize : Kirigami.Theme.defaultFont.pointSize + 1; font.bold: true; font.features: ({"tnum": 1}) }
        }
        HoverHandler { cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: count.attention ? root.attentionFilterRequested() : root.countFilter(count.filterState) }
        Tip { text: count.description }
        Accessible.name: description
        Accessible.role: Accessible.Button
    }

    RowLayout {
        id: row
        anchors.fill: parent
        anchors.margins: Kirigami.Units.smallSpacing
        spacing: Kirigami.Units.smallSpacing

        DockButton {
            objectName: "refreshButton"
            iconOnly: true
            glyph: "view-refresh"
            text: root.refreshTip !== "" ? root.refreshTip : i18n("Refresh")
            onClicked: root.refreshRequested()
        }
        RowLayout {
            id: counts
            objectName: "footerCounts"
            opacity: root.stale ? 0.55 : 1
            spacing: root.compact ? 3 : Kirigami.Units.smallSpacing * 2
            Count { value: root.backend.running; glyph: "circle-play"; toneName: "ok"; description: i18n("%1 running containers · click to filter", String(value)); filterState: "running" }
            Count { value: root.backend.stopped; glyph: "circle-stop"; toneName: "rose"; description: i18n("%1 stopped containers · click to filter", String(value)); filterState: "stopped" }
            Count { value: root.backend.notCreated; glyph: "circle-plus"; toneName: "blue"; description: i18n("%1 Compose services pending deployment · click to filter", String(value)); filterState: "not-created" }
            Count { value: root.backend.problemCount; glyph: "circle-alert"; toneName: "yellow"; description: i18n("%1 containers need attention · click to filter", String(value)); attention: true }
            Count { value: root.backend.total; glyph: "circle-ellipsis"; toneName: "slate"; description: i18n("%1 containers and configured services · show all", String(value)); filterState: "all" }
        }

        Item { Layout.fillWidth: true; Layout.minimumWidth: 0 }

        Item {
            id: staleNote
            objectName: "footerStale"
            visible: root.stale
            implicitWidth: staleLine.implicitWidth
            implicitHeight: staleLine.implicitHeight
            RowLayout {
                id: staleLine
                anchors.fill: parent
                spacing: Kirigami.Units.smallSpacing / 2
                ActionIcon { glyph: "clock-alert"; color: tones.color("amber"); implicitWidth: Kirigami.Units.iconSizes.small; implicitHeight: implicitWidth }
                PlasmaComponents.Label { text: root.staleAge; font: Kirigami.Theme.smallFont; color: tones.color("amber") }
            }
            HoverHandler { cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: root.backend.refresh({force: true}) }
            Tip { text: i18n("Could not refresh: %1\nShowing what was known %2 ago. Click to try again.", root.backend.lastError || i18n("no answer"), root.staleAge) }
            Accessible.name: i18n("Data is %1 old; refresh", root.staleAge)
            Accessible.role: Accessible.Button
        }

        RowLayout {
            id: meters
            objectName: "footerResourceMeters"
            visible: root.backend.running > 0 && !root.compact && !root.stale
            spacing: Kirigami.Units.smallSpacing * 2
            ResourceMeter { label: "CPU"; value: root.backend.cpuSum; maximum: 20; bold: true; barWidth: 36; numberColumnText: "1000.00%" }
            ResourceMeter { label: "RAM"; value: root.backend.memSum; maximum: 20; bold: true; barWidth: 36; numberColumnText: "1000.00%" }
        }
        // A narrow popup has no room for bars, so the totals are plain words.
        RowLayout {
            visible: root.backend.running > 0 && root.compact && !root.stale
            spacing: Kirigami.Units.smallSpacing
            PlasmaComponents.Label {
                text: i18n("CPU %1%", root.backend.cpuSum.toFixed(1))
                font: Kirigami.Theme.smallFont
                color: Style.HUE.cyan
            }
            PlasmaComponents.Label { text: "·"; font: Kirigami.Theme.smallFont; color: Kirigami.Theme.disabledTextColor }
            PlasmaComponents.Label {
                text: i18n("RAM %1%", root.backend.memSum.toFixed(1))
                font: Kirigami.Theme.smallFont
                color: Style.HUE.fuchsia
            }
            Tip { text: i18n("CPU and memory used by all running containers") }
        }
        DockButton {
            objectName: "homeButton"
            iconOnly: true
            glyph: "house"
            text: i18n("Home: the default view, with no filter or selection")
            onClicked: root.homeRequested()
        }
    }
}
