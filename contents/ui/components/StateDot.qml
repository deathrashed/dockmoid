import QtQuick

import org.kde.kirigami as Kirigami

/*
 * StateDot — a single glanceable indicator for a container.
 *
 * Colour answers "is it up?" and the ring answers "is it well?". Health is
 * only shown when the container declares a healthcheck, otherwise every
 * container would be marked "unknown" and the signal would be worthless.
 */
Rectangle {
    id: root

    /* "running" | "exited" | "paused" | "created" | "restarting" | ... */
    property string containerState: ""
    /* "healthy" | "unhealthy" | "starting" | "none" */
    property string health: "none"
    property bool showHealth: true
    property bool failed: false

    implicitWidth: 8
    implicitHeight: implicitWidth

    radius: width / 2
    border.width: height > Kirigami.Units.iconSizes.small ? 2 : 1
    border.color: healthColor
    color: fillColor

    readonly property bool healthy: health === "healthy"
    readonly property bool unhealthy: health === "unhealthy"
    readonly property bool starting: health === "starting"
    readonly property bool hasHealth: health !== "" && health !== "none"

    readonly property color fillColor: {
        if (root.failed) return Kirigami.Theme.negativeTextColor
        if (containerState === "running") return root.unhealthy && showHealth ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.positiveTextColor
        if (containerState === "paused") return Kirigami.Theme.neutralTextColor
        if (containerState === "restarting" || containerState === "removing") {
            return Kirigami.Theme.neutralTextColor
        }
        if (containerState === "dead") return Kirigami.Theme.negativeTextColor
        return Kirigami.Theme.disabledTextColor
    }

    /*
     * Health is drawn as a ring so the dot still reads as "state" at a glance;
     * a solid unhealthy dot would just look like a different state.
     */
    readonly property color healthColor: {
        if (!showHealth || !root.hasHealth || ["running","restarting"].indexOf(containerState) < 0) return Qt.rgba(0, 0, 0, 0)
        if (root.unhealthy) return Kirigami.Theme.negativeTextColor
        if (root.starting) return Kirigami.Theme.highlightColor
        return Qt.rgba(0, 0, 0, 0)
    }
}
