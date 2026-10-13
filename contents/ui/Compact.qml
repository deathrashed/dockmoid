pragma ComponentBehavior: Bound

import QtQuick

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

    required property var backend
    required property var applet

    readonly property var cfg: plasmoid.configuration

    readonly property bool isPanelVertical: plasmoid.formFactor === PlasmaCore.Types.Vertical
    readonly property real itemSize: Math.min(root.height, root.width)

    /* Panel label: a "3~12" badge, or just the running count. */
    readonly property string badgeText: {
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

    readonly property color dotColor: root.cfg.mainDotUseCustomColor
        ? root.cfg.mainDotColor
        : Kirigami.Theme.textColor

    /*
     * Swaps the mark for the spinner while a refresh is in flight. Kept as a
     * binding rather than assigned from a change handler, because a handler on
     * a `var` property only fires when the reference is replaced, never when a
     * property of the referenced object changes.
     */
    /*
     * The panel logo must never be swapped for the spinner.
     *
     * `refreshing` is true for the whole of every poll cycle, and with the
     * default intervals that is a few seconds every 30 — so the mark visibly
     * strobed between the Docker logo and a spinner forever, which read as the
     * applet reloading. Refresh state belongs in the popup, where there is room
     * to show it; on the panel the mark is stable and the state dot carries the
     * status instead.
     */
    readonly property string iconSource: "logo-docker.svg"

    // ------------------------------------------------------- container ----

    Item {
        id: container
        height: root.itemSize
        width: height
        anchors.centerIn: parent

        Components.PlasmoidIcon {
            id: icon
            height: container.height
            width: height
            source: root.iconSource
            hasTint: true
            tint: root.cfg.iconUseCustomColor ? root.cfg.iconColor : "white"
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
                visible: root.showDot && root.cfg.mainDotPosition === index

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
            visible: !root.isPanelVertical && !root.cfg.mainDot
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
            visible: root.isPanelVertical && !root.cfg.mainDot
            icon: icon
            wrapText: root.cfg.wrapText
            widthFit: root.cfg.widthFit
        }

        MouseArea {
            anchors.fill: container
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
            onClicked: function (mouse) {
                if (mouse.button === Qt.LeftButton) {
                    root.applet.toggleView()
                } else if (mouse.button === Qt.MiddleButton) {
                    root.backend.refresh({ "force": true, "withStats": true })
                }
            }
        }
    }
}
