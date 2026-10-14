import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

/*
 * Integration: the programs Dockmoid hands work to.
 */
KCM.SimpleKCM {
    id: page


    property alias cfg_terminalCommand: terminalCommand.text
    property alias cfg_editorCommand: editorCommand.text
    property alias cfg_launchers: launchers.value
    property alias cfg_logTailLines: logTailLines.value

    // Plasma supplies cfg_<name>Default alongside every cfg_<name>.
    property string cfg_launchersDefault
    property string cfg_terminalCommandDefault
    property string cfg_editorCommandDefault
    property int cfg_logTailLinesDefault

    Kirigami.FormLayout {
            Layout.fillWidth: true
        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Terminal")
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Command:")
            Controls.TextField {
                id: terminalCommand

                placeholderText: i18n("automatic")
            }
            QuestionHelp { helpText: i18n("Leave empty to use the first terminal found (Konsole, GNOME Terminal, Kitty, Alacritty, Foot, WezTerm, Ghostty, XFCE Terminal, xterm). {command} is replaced with the docker command; without it the command is simply appended. Example: kitty -e {command}") }
        }

        Controls.SpinBox {
            id: logTailLines
            Kirigami.FormData.label: i18n("Log lines to load:")
            from: 50; to: 10000; stepSize: 50; editable: true
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Editor")
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Command:")
            Controls.TextField {
                id: editorCommand

                placeholderText: i18n("automatic")
            }
            QuestionHelp { helpText: i18n("Used by “Edit Compose File”. Leave empty to use Kate, gedit, VS Code or the system default, whichever exists. {file} is the compose file and {dir} its folder.") }
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("“Open in” menu")
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Launchers:")
            StructuredRulesEditor {
                id: launchers
                title: i18n("Open-in launchers")
                kind: "launcher"
                delimiter: "|"
                headers: [i18n("Label"), i18n("Icon name"), i18n("Scope"), i18n("Command")]
                example: i18n("No launchers configured.")

                Layout.fillWidth: true
                Layout.minimumWidth: 0
            }
            QuestionHelp { helpText: i18n("Scope “container” needs a running container and fills in {id} and {shell}; scope “project” needs a Compose folder and fills in {dir}. Launchers whose program is not installed are hidden automatically. Comments and malformed lines remain in the advanced text view.") }
        }

        Controls.Button {
            text: i18n("Restore the default launchers")
            icon.name: "edit-undo"
            onClicked: page.cfg_launchers = page.cfg_launchersDefault
        }
        Controls.Button { text: i18n("Restore page defaults"); icon.name: "edit-undo"; onClicked: { page.cfg_terminalCommand = page.cfg_terminalCommandDefault; page.cfg_editorCommand = page.cfg_editorCommandDefault; page.cfg_launchers = page.cfg_launchersDefault; page.cfg_logTailLines = page.cfg_logTailLinesDefault } }

    }
}
