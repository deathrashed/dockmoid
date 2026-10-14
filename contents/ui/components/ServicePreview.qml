pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import "../../lib/style.js" as Style

Rectangle {
    id:root
    objectName:"servicePreview"
    required property var backend
    signal openDetail(string recordId)
    readonly property var record: {const revision=backend.revision;return backend.findRecord(backend.previewRecordId)}
    color:Qt.alpha(Kirigami.Theme.highlightColor,Style.ALPHA.surface2)
    border.color:Qt.alpha(Kirigami.Theme.textColor,Style.ALPHA.border)
    radius:Kirigami.Units.smallSpacing
    Controls.ScrollView {
        id:previewScroll
        contentWidth:availableWidth
        Controls.ScrollBar.horizontal.policy:Controls.ScrollBar.AlwaysOff
        anchors.fill:parent;anchors.margins:8;clip:true
        ColumnLayout {
            width:previewScroll.availableWidth;spacing:8
            PlasmaComponents.Label {Layout.fillWidth:true;text:i18n("Service preview");font.bold:true}
            ServiceIcon {visible:!!root.record;backend:root.backend;record:root.record || ({});iconSize:32}
            PlasmaComponents.Label {Layout.fillWidth:true;text:root.record?root.record.name:i18n("Hover over or select a service");font.bold:true;wrapMode:Text.WrapAnywhere}
            Repeater {
                model:root.record?[
                    [i18n("Status"),root.record.state==="not-created"?i18n("Not created"):root.record.status || root.record.state],
                    [i18n("Image"),root.record.image],
                    [i18n("Project / service"),[root.record.project,root.record.service].filter(Boolean).join(" / ")],
                    [i18n("Ports"),root.record.ports],
                    [i18n("Mounts"),root.record.mounts],
                    [i18n("CPU / RAM"),[root.record.cpu,root.record.mem].filter(Boolean).join(" / ")]
                ]:[]
                delegate:ColumnLayout {
                    required property var modelData
                    Layout.fillWidth:true;spacing:2
                    PlasmaComponents.Label {text:parent.modelData[0];color:Kirigami.Theme.disabledTextColor;font:Kirigami.Theme.smallFont}
                    PlasmaComponents.Label {Layout.fillWidth:true;text:String(parent.modelData[1] || i18n("Unavailable"));textFormat:Text.PlainText;wrapMode:Text.WrapAnywhere}
                }
            }
            ActionButton {visible:!!root.record;text:i18n("Open details");glyph:"document-view";onClicked:root.openDetail(root.record.id)}
        }
    }
}
