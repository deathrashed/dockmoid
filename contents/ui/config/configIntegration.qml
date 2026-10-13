import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts

import org.kde.kirigami as Kirigami

/*
 * Integration: the terminal emulator, the editor and the log tail size.
 */
Kirigami.ScrollablePage {
    id: page

    property alias cfg_terminalCommand: terminalCommand.text
    property alias cfg_editorCommand: editorCommand.text
    property alias cfg_logTailLines: logTailLines.value

    ColumnLayout {
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
        }
        spacing: Kirigami.Units.smallSpacing

        Kirigami.FormLayout {
            wideMode: false
            Kirigami.Separator {
                Kirigami.FormData.isSection: true
                Kirigami.FormData.label: i18n("Terminal")
            }
        }

        Kirigami.FormLayout {
            Controls.TextField {
                id: terminalCommand
                Kirigami.FormData.label: i18n("Terminal command: ")
                Layout.preferredWidth: Kirigami.Units.gridUnit * 14
            }
        }

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            type: Kirigami.MessageType.Information
            text: i18n("{command} is replaced with the finished docker command. Konsole, xfce4-terminal, gnome-terminal, kitty and alacritty all work with the default form. The window is launched in the background, so it survives the popup being closed and the plasmoid being reloaded.")
        }

        Kirigami.FormLayout {
            Controls.SpinBox {
                id: logTailLines
                Kirigami.FormData.label: i18n("Log lines to show: ")
                from: 50
                to: 10000
                stepSize: 50
                editable: true
            }
        }

        Kirigami.FormLayout {
            wideMode: false
            Kirigami.Separator {
                Kirigami.FormData.isSection: true
                Kirigami.FormData.label: i18n("Editor")
            }
        }

        Kirigami.FormLayout {
            Controls.TextField {
                id: editorCommand
                Kirigami.FormData.label: i18n("Editor command: ")
                Layout.preferredWidth: Kirigami.Units.gridUnit * 14
            }
        }

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            type: Kirigami.MessageType.Information
            text: i18n("Used by 'Edit Compose File' to open the file a container was defined in, read from the compose labels Docker records at creation. {file} is the path and {dir} is the project's working directory.")
        }

        Item {
            Layout.fillHeight: true
        }
    }
}
