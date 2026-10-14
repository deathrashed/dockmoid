import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts

import org.kde.kirigami as Kirigami

/*
 * Hint — the grey explanatory line under a setting. Lives in the form's
 * second column, so it lines up with the controls it explains.
 */
Controls.Label {
    Layout.fillWidth: true
    Layout.maximumWidth: Kirigami.Units.gridUnit * 30
    wrapMode: Text.WordWrap
    font: Kirigami.Theme.smallFont
    opacity: 0.7
    textFormat: Text.PlainText
}
