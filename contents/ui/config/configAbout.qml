import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    id: page

    Kirigami.FormLayout {
        Layout.fillWidth: true
        Layout.maximumWidth: Kirigami.Units.gridUnit * 42
        Layout.alignment: Qt.AlignHCenter

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Dockmoid")
        }

        Controls.Label {
            Kirigami.FormData.label: i18n("Version:")
            text: "2.4.0"
        }
        Controls.Label {
            Kirigami.FormData.label: i18n("Platform:")
            text: i18n("KDE Plasma 6")
        }
        Controls.Label {
            Kirigami.FormData.label: i18n("Purpose:")
            text: i18n("Container status, monitoring and management from your panel.")
            wrapMode: Text.WordWrap
            Layout.maximumWidth: Kirigami.Units.gridUnit * 30
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Project:")
            Controls.Button {
                text: i18n("Source code")
                icon.name: "code-context"
                onClicked: Qt.openUrlExternally("https://github.com/deathrashed/dockmoid")
            }
            Controls.Button {
                text: i18n("Report an issue")
                icon.name: "tools-report-bug"
                onClicked: Qt.openUrlExternally("https://github.com/deathrashed/dockmoid/issues")
            }
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Connection diagnostics")
        }
        Controls.Label {
            text: i18n("Open Advanced → Connection, then choose Test connection. The check uses the unsaved engine and context fields and reports optional tools separately.")
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
            Layout.maximumWidth: Kirigami.Units.gridUnit * 34
        }
        Controls.Label {
            text: i18n("The report is shown locally in the settings page. Review it before sharing; custom command text is not included.")
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
            Layout.maximumWidth: Kirigami.Units.gridUnit * 34
            color: Kirigami.Theme.disabledTextColor
        }
    }
}
