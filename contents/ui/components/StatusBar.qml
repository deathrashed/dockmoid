import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import "../../lib/style.js" as Style

/*
 * StatusBar — the footer: how many containers are in each state (tap one to
 * filter), and the host's CPU and RAM. Each count says what it counts
 * ("8 running") when there is room: all of them on a wide popup, running and
 * stopped on a narrower one, icons and numbers only when even that does
 * not fit. The words are measured once by hidden labels, never by the row
 * they change, so the choice cannot feed back into itself.
 */
Item {
    id: root
    required property var backend
    signal countFilter(string state)
    signal attentionFilterRequested()
    readonly property var cfg: plasmoid.configuration
    readonly property bool compact: width < 560
    /* Narrow: the total (the sum of the rest) and a zero attention count give their room to words. */
    readonly property bool showTotal: !root.compact
    readonly property bool showAttention: !root.compact || root.backend.problemCount > 0
    readonly property int shownCounts: 3 + (root.showTotal ? 1 : 0) + (root.showAttention ? 1 : 0)
    readonly property real countFont: root.compact ? Kirigami.Theme.smallFont.pointSize : Kirigami.Theme.defaultFont.pointSize + 1
    /* Room left for words: the bare counts and the CPU/RAM side are fixed. */
    readonly property real spare: row.width - bareWidth.width - (meters.visible ? meters.implicitWidth : 0)
        - (compactMeters.visible ? compactMeters.implicitWidth : 0) - (staleNote.visible ? staleNote.implicitWidth : 0)
        - Kirigami.Units.smallSpacing * 2
    /*
     * The last refresh failed: the counts and colours are the last known
     * state, not a fresh check. Say how old they are, keep them readable but
     * dimmed, and offer a retry. The age is re-read every 30 s while stale.
     */
    readonly property bool stale: root.backend.dataStale && root.backend.lastUpdatedMs > 0
    property double now: Date.now()
    Timer { interval: 30000; repeat: true; running: root.stale && root.visible; onTriggered: root.now = Date.now() }
    onStaleChanged: root.now = Date.now()
    readonly property string staleAge: {
        const secs = Math.max(0, Math.round((root.now - root.backend.lastUpdatedMs) / 1000))
        return secs < 90 ? i18np("%1 second", "%1 seconds", secs)
            : secs < 5400 ? i18np("%1 minute", "%1 minutes", Math.round(secs / 60))
            : i18np("%1 hour", "%1 hours", Math.round(secs / 3600))
    }
    readonly property int wordLevel: spare >= allWords.width ? 2 : spare >= mainWords.width ? 1 : 0

    // Hidden measures: the bare counts shown, and the words each level adds.
    Row {
        id: bareWidth
        visible: false
        spacing: root.compact ? 3 : Kirigami.Units.smallSpacing * 2
        Repeater { model: root.shownCounts; Item { width: (root.compact ? 12 : Kirigami.Units.iconSizes.small) + Kirigami.Units.smallSpacing / 2 + bareDigits.width; height: 1 } }
    }
    PlasmaComponents.Label { id: bareDigits; visible: false; text: "88"; font.pointSize: root.countFont; font.bold: true }
    Row {
        id: mainWords
        visible: false
        spacing: Kirigami.Units.smallSpacing
        Repeater { model: [i18n("running"), i18n("stopped")]; PlasmaComponents.Label { required property string modelData; text: modelData; font: Kirigami.Theme.smallFont } }
    }
    Row {
        id: allWords
        visible: false
        spacing: Kirigami.Units.smallSpacing
        Repeater { model: [i18n("running"), i18n("stopped"), i18n("undeployed"), i18n("attention"), i18n("total")]; PlasmaComponents.Label { required property string modelData; text: modelData; font: Kirigami.Theme.smallFont } }
    }

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
        /* Shown after the number at word level `wordAt` and above. */
        property string word: ""
        property int wordAt: 2
        implicitWidth: line.implicitWidth
        implicitHeight: line.implicitHeight
        RowLayout {
            id: line
            anchors.fill: parent
            spacing: Kirigami.Units.smallSpacing / 2
            ActionIcon { glyph: count.glyph; color: tones.color(count.toneName); implicitWidth: root.compact ? 12 : Kirigami.Units.iconSizes.small; implicitHeight: implicitWidth }
            PlasmaComponents.Label { text: String(count.value); font.pointSize: root.countFont; font.bold: true; font.features: ({"tnum": 1}) }
            PlasmaComponents.Label {
                visible: count.word !== "" && root.wordLevel >= count.wordAt
                text: count.word
                font: Kirigami.Theme.smallFont
                color: Kirigami.Theme.disabledTextColor
            }
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

        RowLayout {
            id: counts
            objectName: "footerCounts"
            opacity: root.stale ? 0.55 : 1
            spacing: root.compact ? 3 : Kirigami.Units.smallSpacing * 2
            Count { value: root.backend.running; glyph: "circle-play"; toneName: "ok"; word: i18n("running"); wordAt: 1; description: i18n("%1 running containers · click to filter", String(value)); filterState: "running" }
            Count { value: root.backend.stopped; glyph: "circle-stop"; toneName: "rose"; word: i18n("stopped"); wordAt: 1; description: i18n("%1 stopped containers · click to filter", String(value)); filterState: "stopped" }
            Count { value: root.backend.notCreated; glyph: "circle-plus"; toneName: "blue"; word: i18n("undeployed"); description: i18n("%1 Compose services pending deployment · click to filter", String(value)); filterState: "not-created" }
            Count { value: root.backend.problemCount; glyph: "circle-alert"; toneName: "yellow"; visible: root.showAttention; word: i18n("attention"); description: i18n("%1 containers need attention · click to filter", String(value)); attention: true }
            Count { value: root.backend.total; glyph: "circle-ellipsis"; toneName: "slate"; visible: root.showTotal; word: i18n("total"); description: i18n("%1 containers and configured services · show all", String(value)); filterState: "all" }
        }

        Item { Layout.fillWidth: true; Layout.minimumWidth: 0 }

        // Replaces CPU/RAM while stale: those numbers are just as old.
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
                ActionIcon { glyph: "clock"; color: tones.color("amber"); implicitWidth: Kirigami.Units.iconSizes.small; implicitHeight: implicitWidth }
                PlasmaComponents.Label {
                    text: root.compact ? i18n("%1 old", root.staleAge) : i18n("Last known · %1 old", root.staleAge)
                    font: Kirigami.Theme.smallFont
                    color: tones.color("amber")
                }
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
            id: compactMeters
            visible: root.backend.running > 0 && root.compact && !root.stale
            spacing: Kirigami.Units.smallSpacing
            PlasmaComponents.Label {
                text: i18n("CPU %1%", root.backend.cpuSum.toFixed(0))
                font: Kirigami.Theme.smallFont
                color: Style.HUE.cyan
            }
            PlasmaComponents.Label { text: "·"; font: Kirigami.Theme.smallFont; color: Kirigami.Theme.disabledTextColor }
            PlasmaComponents.Label {
                text: i18n("RAM %1%", root.backend.memSum.toFixed(0))
                font: Kirigami.Theme.smallFont
                color: Style.HUE.fuchsia
            }
            Tip { text: i18n("CPU and memory used by all running containers") }
        }
    }
}
