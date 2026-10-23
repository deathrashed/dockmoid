import QtQuick
import QtQuick.Window
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.extras as PlasmaExtras

// The panel hover card uses bundled artwork and labels cached data explicitly.
ColumnLayout {
    id: root

    required property var backend
    property bool detached: false
    readonly property var cfg: plasmoid.configuration
    readonly property var info: root.backend.engineInfo || ({})
    readonly property string engineName: root.backend.isPodman ? i18n("Podman") : i18n("Docker")
    property double now: Date.now()
    readonly property bool usageKnown: {
        var revision = root.backend.revision
        return root.backend.records.some(function (rec) { return rec.isRunning && rec.cpu !== "" })
    }
    readonly property string connectionText: {
        if (!root.backend.engineKnown) return i18n("Connecting to %1…", root.engineName)
        if (!root.backend.engineActive) return i18n("%1 is unavailable", root.engineName)
        return root.backend.contextName !== ""
            ? i18n("%1 · %2", root.engineName, root.backend.contextName)
            : (root.backend.remoteEngine ? i18n("%1 · Remote host", root.engineName) : i18n("%1 · Local host", root.engineName))
    }

    readonly property var problemNames: {
        var revision = root.backend.revision
        return root.backend.records.filter(function (rec) { return root.backend.isProblem(rec) }).map(function (rec) { return rec.name })
    }
    readonly property string problemText: root.problemNames.length === 0 ? ""
        : root.problemNames.slice(0, 3).join(", ") + (root.problemNames.length > 3 ? i18n(" and %1 more", root.problemNames.length - 3) : "")

    function ageText(timestamp) {
        if (!timestamp) return i18n("Not refreshed yet")
        var seconds = Math.max(0, Math.floor((root.now - timestamp) / 1000))
        if (seconds < 10) return i18n("Just now")
        if (seconds < 60) return i18np("%1 second ago", "%1 seconds ago", seconds)
        var minutes = Math.floor(seconds / 60)
        if (minutes < 60) return i18np("%1 minute ago", "%1 minutes ago", minutes)
        var hours = Math.floor(minutes / 60)
        if (hours < 24) return i18np("%1 hour ago", "%1 hours ago", hours)
        return Qt.formatDateTime(new Date(timestamp), Qt.locale().dateTimeFormat(Locale.ShortFormat))
    }

    implicitWidth: Kirigami.Units.gridUnit * 19
    spacing: Kirigami.Units.smallSpacing

    // Do not keep a clock running while the hover window is hidden.
    Timer {
        interval: 5000
        repeat: true
        triggeredOnStart: true
        running: root.visible && root.Window.window !== null && root.Window.window.visible
        onTriggered: root.now = Date.now()
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Kirigami.Units.smallSpacing * 2
        Image {
            source: "../icons/dockmoid.png"
            sourceSize: Qt.size(64 * Screen.devicePixelRatio, 64 * Screen.devicePixelRatio)
            smooth: true
            mipmap: true
            Layout.preferredWidth: 32
            Layout.preferredHeight: 32
            fillMode: Image.PreserveAspectFit
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            PlasmaExtras.Heading {
                Layout.fillWidth: true
                level: 3
                text: i18n("Dockmoid")
            }
            PlasmaComponents.Label {
                Layout.fillWidth: true
                text: root.connectionText
                wrapMode: Text.Wrap
                color: root.backend.engineKnown && !root.backend.engineActive
                    ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.textColor
            }
        }
    }

    PlasmaComponents.Label {
        Layout.fillWidth: true
        visible: root.backend.engineKnown && (root.backend.engineActive || root.backend.total > 0)
        text: i18n("%1 running · %2 stopped · %3 total", root.backend.running, root.backend.stopped, root.backend.total)
        wrapMode: Text.Wrap
        font.bold: true
    }
    PlasmaComponents.Label {
        Layout.fillWidth: true
        visible: root.backend.dataStale || (root.backend.engineKnown && !root.backend.engineActive && root.backend.total > 0)
        text: i18n("Showing the last known container state")
        wrapMode: Text.Wrap
        color: Kirigami.Theme.neutralTextColor
    }

    PlasmaComponents.Label {
        Layout.fillWidth: true
        visible: root.problemText !== ""
        text: i18n("Needs attention: %1", root.problemText)
        wrapMode: Text.Wrap
        color: Kirigami.Theme.negativeTextColor
    }

    GridLayout {
        Layout.fillWidth: true
        columns: 2
        columnSpacing: Kirigami.Units.largeSpacing
        rowSpacing: Kirigami.Units.smallSpacing
        Repeater {
            model: [
                {label: i18n("Paused containers"), value: String(root.backend.pausedCount), show: root.backend.pausedCount > 0},
                {label: i18n("Unhealthy containers"), value: String(root.backend.unhealthy), show: root.cfg.showHealth && root.backend.unhealthy > 0, warning: true},
                {label: i18n("Image updates available"), value: String(root.backend.updateCount), show: root.cfg.checkImageUpdates && root.backend.updateCount > 0},
                {label: i18n("Local images"), value: String(root.info.images || 0), show: root.info.images !== undefined},
                {label: i18n("Container CPU usage"), value: i18n("%1%", root.backend.cpuSum.toFixed(1)), show: root.usageKnown},
                {label: i18n("Container memory usage"), value: i18n("%1% of host RAM", root.backend.memSum.toFixed(1)), show: root.usageKnown},
                {label: i18n("Engine version"), value: String(root.info.serverVersion || ""), show: !!root.info.serverVersion},
                {label: i18n("Containers refreshed"), value: root.ageText(root.backend.lastUpdatedMs), show: root.backend.lastUpdatedMs > 0},
                {label: i18n("Usage sampled"), value: root.ageText(root.backend.statsUpdatedMs), show: root.usageKnown && root.backend.statsUpdatedMs > 0}
            ]
            delegate: RowLayout {
                required property var modelData
                // Each row spans the grid so optional entries leave no holes.
                Layout.columnSpan: 2
                Layout.fillWidth: true
                visible: modelData.show
                PlasmaComponents.Label {
                    Layout.fillWidth: true
                    text: modelData.label
                    color: Kirigami.Theme.textColor
                }
                PlasmaComponents.Label {
                    text: modelData.value
                    color: parent.modelData.warning ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.textColor
                }
            }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 1
        color: Kirigami.Theme.textColor
        opacity: 0.2
    }
    PlasmaComponents.Label {
        Layout.fillWidth: true
        text: root.detached ? i18n("Click to bring the Dockmoid window forward") : i18n("Click to open your containers")
        wrapMode: Text.Wrap
    }
    PlasmaComponents.Label {
        Layout.fillWidth: true
        visible: Number(root.cfg.middleClickAction) !== 3
        text: {
            switch (Number(root.cfg.middleClickAction)) {
            case 1: return i18n("Middle-click to attach or detach the window")
            case 2: return i18n("Middle-click to restart unhealthy containers")
            default: return i18n("Middle-click to refresh containers and usage")
            }
        }
        wrapMode: Text.Wrap
        color: Kirigami.Theme.disabledTextColor
    }
}
