import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

/*
 * SizedComboBox — a Plasma ComboBox whose implicit size does not depend on its
 * own size. Plasma's version measures its text field's contentWidth and
 * contentHeight and its background's implicit height, all of which follow the
 * size the layout then gives it, so every resize re-enters the binding
 * ("Binding loop detected for implicitWidth/implicitHeight"). Here the width
 * is a fixed request (layouts may still stretch it) and the height comes from
 * the font.
 */
PlasmaComponents.ComboBox {
    id: control

    /* The width asked for when the layout does not stretch the box. */
    property real preferredTextWidth: Kirigami.Units.gridUnit * 8

    implicitWidth: preferredTextWidth
    // Not implicitBackgroundHeight: the background is a Loader filling the
    // box, so its implicit height follows the height as well.
    implicitHeight: Math.max(Math.ceil(metrics.height), implicitIndicatorHeight) + topPadding + bottomPadding

    FontMetrics { id: metrics; font: control.font }
}
