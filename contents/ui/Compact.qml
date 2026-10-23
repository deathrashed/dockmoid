pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes

import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore

import "components" as Components

/*
 * Compact — the panel representation.
 *
 * Shows the Docker mark with a badge (running/total) or a corner dot, and
 * carries the panel's health signal through colour: red when the engine is
 * down, the highlight colour when a container reports unhealthy. That way the
 * state is readable from across the desk without opening anything.
 */
Item {
    id: root
    implicitWidth: Kirigami.Units.iconSizes.smallMedium
    implicitHeight: Kirigami.Units.iconSizes.smallMedium

    required property var backend
    required property var applet

    property var configuration: plasmoid ? plasmoid.configuration : ({})
    property bool previewMode: false
    readonly property var cfg: root.configuration
    readonly property int displayStyle: cfg.panelStyle >= 0 && cfg.panelStyle <= 6 ? Number(cfg.panelStyle) : 0

    readonly property bool isPanelVertical: plasmoid && plasmoid.formFactor === PlasmaCore.Types.Vertical
    readonly property real itemSize: Math.min(root.height, root.width)

    /* Panel label: a "3~12" badge, or just the running count. */
    readonly property string badgeText: {
        // 5: no badge; 6: only the number of containers needing attention.
        if (root.cfg.badgeStyle === 5)
            return ""
        if (root.cfg.badgeStyle === 6)
            return root.backend.problemCount > 0 ? " ! " + root.backend.problemCount + " " : ""
        if (root.cfg.badgeStyle === 1)
            return " " + root.backend.running + root.cfg.separator + root.backend.total + " "
        if (root.cfg.badgeStyle === 2)
            return " " + root.backend.running + " "
        if (root.cfg.badgeStyle === 3)
            return " " + (root.backend.total > 0 ? Math.round(root.backend.running * 100 / root.backend.total) : 0) + "% "
        if (root.cfg.badgeStyle === 4)
            return " " + root.backend.running + " running "
        if (root.cfg.separateResult) {
            return " " + root.backend.running + root.cfg.separator + root.backend.total + " "
        }
        return " " + root.backend.running + " "
    }

    /*
     * The dot only makes sense when there is something running to point at,
     * which is the behaviour the display config page documents.
     */
    readonly property bool showDot: root.cfg.mainDot && root.backend.running > 0

    /*
     * The mark is two layers — the ring and the whale with its stack of
     * containers — so state can be shown inside the logo itself. Two choices:
     *
     *   How the ring behaves (panelIndicator)
     *     gauge  the ring fills clockwise with running/total (default)
     *     solid  the whole ring is one colour
     *     plain  the ring never changes
     *   What takes the state colour (indicatorTarget)
     *     ring, whale, or both
     *
     * State colours: brand blue while things run normally, amber when something
     * is paused, red when something is wrong (unhealthy, crashed, restarting,
     * not answering). A paused or unhealthy stack fills the whole ring, because
     * "how many are running" stops being the point when something needs
     * attention. Nothing running, or Docker down, dims the mark.
     *
     * The logo is never swapped for a spinner while refreshing: that strobed on
     * every poll and read as the applet reloading.
     */
    readonly property int ringMode: Math.min(2, root.cfg.panelIndicator)   // 0 gauge, 1 solid, 2 plain
    readonly property int target: root.cfg.indicatorTarget                 // 0 ring, 1 whale, 2 both
    readonly property bool colourRing: root.target !== 1
    readonly property bool colourWhale: root.target !== 0

    readonly property string stateName: {
        if (!root.backend.engineKnown || !root.backend.engineActive) return "down"
        if (root.backend.unhealthy > 0 || root.backend.problemCount > root.backend.pausedCount) return "bad"
        if (root.backend.pausedCount > 0) return "paused"
        if (root.backend.running > 0) return "ok"
        return "idle"
    }

    readonly property color brandBlue: "#2560ff"

    readonly property color stateColor: {
        var custom = root.cfg.customStateColors
        switch (root.stateName) {
        case "bad": return custom ? root.cfg.stateBadColor : Kirigami.Theme.negativeTextColor
        case "paused": return custom ? root.cfg.statePausedColor : Kirigami.Theme.neutralTextColor
        case "ok": return custom ? root.cfg.stateOkColor : root.brandBlue
        default: return root.baseColor
        }
    }

    readonly property color baseColor: root.cfg.iconUseCustomColor ? root.cfg.iconColor : Kirigami.Theme.textColor
    readonly property bool coloured: root.stateName === "ok"
        || root.stateName === "bad" || root.stateName === "paused"

    /* How far round the gauge goes. Attention states fill the ring. */
    readonly property real fraction: {
        if (root.stateName === "bad" || root.stateName === "paused") return 1
        return root.backend.total > 0 ? Math.min(1, root.backend.running / root.backend.total) : 0
    }

    /* The arc is in the state colour only when the ring is what is coloured. */
    readonly property real gaugeFraction: root.colourRing ? root.fraction
        : (root.backend.total > 0 ? Math.min(1, root.backend.running / root.backend.total) : 0)

    readonly property color dotColor: root.cfg.mainDotUseCustomColor
        ? root.cfg.mainDotColor
        : (root.coloured ? root.stateColor : Kirigami.Theme.textColor)

    // ------------------------------------------------------- container ----

    Item {
        id: container
        height: root.itemSize
        width: height
        anchors.centerIn: parent

        // Ring: a track for the gauge, or the whole state colour.
        Components.PlasmoidIcon {
            id: ringLayer
            visible: root.displayStyle === 0 || root.displayStyle === 6
            height: container.height
            width: height
            source: "logo-dockmoid-ring.svg"
            hasTint: true
            tint: (root.displayStyle === 6 || root.ringMode === 1 && root.colourRing) && root.coloured
                ? root.stateColor : root.baseColor
            opacity: root.stateName === "down" ? 0.4 : (root.displayStyle === 0 && root.ringMode === 0 ? 0.3 : 1)
            Behavior on opacity { NumberAnimation { duration: Kirigami.Units.longDuration } }
        }

        // Whale and containers.
        Components.PlasmoidIcon {
            id: icon
            visible: root.displayStyle === 0 || root.displayStyle === 1 || root.displayStyle === 5 || root.displayStyle === 6
            anchors.centerIn: parent
            height: root.displayStyle === 5 ? container.height * 0.85 : container.height
            width: height
            source: "logo-dockmoid-whale.svg"
            hasTint: true
            tint: ((root.displayStyle !== 0 && root.displayStyle !== 6) || root.colourWhale) && root.coloured ? root.stateColor : root.baseColor
            opacity: root.stateName === "down" ? 0.4 : 1
            Behavior on opacity { NumberAnimation { duration: Kirigami.Units.longDuration } }
        }

        // Gauge: an arc over the ring, from twelve o'clock clockwise.
        Shape {
            id: gauge
            anchors.fill: parent
            visible: root.displayStyle === 0 && root.ringMode === 0 && root.gaugeFraction > 0 && root.stateName !== "down"
            preferredRendererType: Shape.CurveRenderer

            // The ring in the artwork is a 270.93-unit square drawing.
            readonly property real unit: container.height / 270.93331

            ShapePath {
                strokeColor: root.colourRing && root.coloured ? root.stateColor : root.baseColor
                strokeWidth: 15 * gauge.unit
                fillColor: "transparent"
                capStyle: ShapePath.FlatCap

                PathAngleArc {
                    centerX: 135.46666 * gauge.unit
                    centerY: 135.46666 * gauge.unit
                    radiusX: 114.5 * gauge.unit
                    radiusY: 114.5 * gauge.unit
                    startAngle: -90
                    sweepAngle: Math.min(359.9, 360 * root.gaugeFraction)
                    Behavior on sweepAngle { NumberAnimation { duration: Kirigami.Units.longDuration } }
                }
            }
        }

        Text {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: root.displayStyle === 4 ? -container.height * 0.13 : 0
            visible: root.displayStyle >= 2 && root.displayStyle <= 4
            text: root.displayStyle === 3 ? root.backend.running + "/" + root.backend.total : String(root.backend.running)
            font.family: Kirigami.Theme.defaultFont.family
            font.bold: true
            font.pixelSize: container.height * (root.displayStyle === 3 ? 0.34 : 0.58)
            color: root.coloured ? root.stateColor : root.baseColor
            renderType: Text.QtRendering
        }
        Rectangle {
            visible: root.displayStyle === 2 || root.displayStyle === 3
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: container.height * 0.04
            width: container.width * 0.65
            height: Math.max(2, container.height * 0.07)
            radius: height / 2
            color: root.coloured ? root.stateColor : Qt.alpha(root.baseColor, 0.35)
        }
        Row {
            visible: root.displayStyle === 4
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: container.height * 0.08
            spacing: Math.max(1, container.width * 0.025)
            Repeater {
                model: 10
                delegate: Rectangle {
                    required property int index
                    width: container.width * 0.065
                    height: container.height * 0.16
                    radius: 1
                    color: root.backend.total > 0 && index < Math.round(root.backend.running / root.backend.total * 10)
                        ? root.stateColor : Qt.alpha(root.baseColor, 0.2)
                }
            }
        }
        Rectangle {
            visible: root.displayStyle === 5
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: Math.max(3, container.height * 0.08)
            radius: height / 2
            color: Qt.alpha(root.baseColor, 0.2)
            Rectangle {
                width: parent.width * (root.backend.total > 0 ? Math.min(1, root.backend.running / root.backend.total) : 0)
                height: parent.height
                radius: height / 2
                color: root.stateColor
            }
        }

        // Ring mode has no routine count badge or status dot. Surface a small
        // warning only while the engine or a container needs attention.
        Components.PlasmoidIcon {
            visible: root.displayStyle === 6 && (root.stateName === "bad" || root.stateName === "paused" || root.stateName === "down")
            width: container.height * 0.36
            height: width
            anchors.right: parent.right
            anchors.top: parent.top
            source: "circle-alert.svg"
            hasTint: true
            tint: root.stateName === "bad" ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.neutralTextColor
        }

        // The dot can sit in any corner; four tiny rectangles are cheaper and
        // less fiddly than a single one whose anchors get rebound on every
        // config change.
        Repeater {
            model: 4

            delegate: Rectangle {
                required property int index
                readonly property bool rightSide: index === 0 || index === 2
                readonly property bool topSide: index === 0 || index === 1

                width: container.height / 2.5
                height: width
                radius: width / 2
                color: root.dotColor
                visible: (root.displayStyle === 0 || root.displayStyle === 1 || root.displayStyle === 5) && root.showDot && root.cfg.mainDotPosition === index

                // Positioned by hand rather than with conditional anchors:
                // four anchors where two are left undefined is exactly the
                // kind of thing that breaks when a panel resizes.
                x: rightSide ? container.width - width : 0
                y: topSide ? 0 : container.height - height
            }
        }

        // Horizontal panel: badge sits on the bottom-right corner.
        Components.BadgeOverlay {
            anchors {
                bottom: container.bottom
                right: container.right
            }
            text: root.badgeText
            visible: (root.displayStyle === 0 || root.displayStyle === 1 || root.displayStyle === 5) && !root.isPanelVertical && !root.cfg.mainDot && root.badgeText !== ""
            icon: icon
            wrapText: root.cfg.wrapText
            widthFit: root.cfg.widthFit
        }

        // Vertical panel: same badge, rotated to the side of the icon.
        Components.BadgeOverlay {
            anchors {
                verticalCenter: container.bottom
                right: container.right
            }
            text: root.badgeText
            visible: (root.displayStyle === 0 || root.displayStyle === 1 || root.displayStyle === 5) && root.isPanelVertical && !root.cfg.mainDot && root.badgeText !== ""
            icon: icon
            wrapText: root.cfg.wrapText
            widthFit: root.cfg.widthFit
        }

        MouseArea {
            parent: root
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
            enabled: !root.previewMode
            onClicked: function (mouse) {
                if (mouse.button === Qt.LeftButton) {
                    root.applet.toggleView()
                } else if (mouse.button === Qt.MiddleButton) {
                    switch (root.cfg.middleClickAction) {
                    case 1: root.applet.toggleDetached(); break
                    case 2: root.backend.restartUnhealthy(); break
                    case 3: break
                    default: root.backend.refresh({ "force": true, "withStats": true })
                    }
                }
            }
        }
    }
}
