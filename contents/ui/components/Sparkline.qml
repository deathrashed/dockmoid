import QtQuick
import QtQuick.Shapes
import "../../lib/style.js" as Style

/*
 * Sparkline — a tiny line graph of recent samples.
 *
 * Autoscales to the data (never below `floor`, so a flat 0.1% does not look
 * like a mountain), draws nothing until there are two points.
 */
Item {
    id: root

    property var samples: []
    property color color: "steelblue"
    /* The smallest top of the scale, in the samples' own unit. */
    property real floor: 5

    implicitWidth: 80
    implicitHeight: 22

    readonly property real chartTop: {
        var m = root.floor
        for (let i = 0; i < root.samples.length; i++) if (root.samples[i] > m) m = root.samples[i]
        return m
    }

    readonly property var points: {
        var n = root.samples.length
        var out = []
        if (n < 2) return out
        for (let i = 0; i < n; i++) {
            out.push(Qt.point(i * root.width / (n - 1),
                              root.height - 1 - (root.height - 2) * root.samples[i] / root.chartTop))
        }
        return out
    }

    Rectangle {
        anchors.fill: parent
        radius: 2
        color: Qt.alpha(root.color, Style.ALPHA.tintWeak)
    }

    Shape {
        anchors.fill: parent
        visible: root.points.length > 1
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: root.color
            strokeWidth: 1.5
            fillColor: "transparent"
            joinStyle: ShapePath.RoundJoin
            PathPolyline { path: root.points }
        }
    }
}
