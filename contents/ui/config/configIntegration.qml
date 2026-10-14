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
    property alias cfg_launchers: launchers.text
    property alias cfg_logTailLines: logTailLines.value

    // Plasma supplies cfg_<name>Default alongside every cfg_<name>.
    property string cfg_launchersDefault
    property string cfg_terminalCommandDefault
    property string cfg_editorCommandDefault
    property int cfg_logTailLinesDefault

    Kirigami.FormLayout {
        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Terminal")
        }

        Controls.TextField {
            id: terminalCommand
            Kirigami.FormData.label: i18n("Command:")
            placeholderText: i18n("automatic")
            Layout.preferredWidth: Kirigami.Units.gridUnit * 20
        }
        Hint { text: i18n("Leave empty to use the first terminal found (Konsole, GNOME Terminal, Kitty, Alacritty, Foot, WezTerm, Ghostty, XFCE Terminal, xterm). {command} is replaced with the docker command; without it the command is simply appended. Example: kitty -e {command}") }

        Controls.SpinBox {
            id: logTailLines
            Kirigami.FormData.label: i18n("Log lines to load:")
            from: 50; to: 10000; stepSize: 50; editable: true
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Editor")
        }

        Controls.TextField {
            id: editorCommand
            Kirigami.FormData.label: i18n("Command:")
            placeholderText: i18n("automatic")
            Layout.preferredWidth: Kirigami.Units.gridUnit * 20
        }
        Hint { text: i18n("Used by “Edit Compose File”. Leave empty to use Kate, gedit, VS Code or the system default, whichever exists. {file} is the compose file and {dir} its folder.") }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("“Open in” menu")
        }

        Controls.ScrollView {
            Kirigami.FormData.label: i18n("Launchers:")
            Kirigami.FormData.labelAlignment: Qt.AlignTop
            Layout.preferredWidth: Kirigami.Units.gridUnit * 30
            Layout.preferredHeight: Kirigami.Units.gridUnit * 9

            Controls.TextArea {
                id: launchers
                wrapMode: TextEdit.NoWrap
                font.family: "monospace"
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                selectByMouse: true
            }
        }
        Hint { text: i18n("One per line:  Label | icon name | scope | command.  Scope “container” needs a running container and fills in {id} and {shell}; scope “project” needs a Compose project folder and fills in {dir}. Launchers whose program is not installed are hidden automatically. Lines starting with # are ignored.") }

        Controls.Button {
            text: i18n("Restore the default launchers")
            icon.name: "edit-undo"
            onClicked: launchers.text = page.cfg_launchersDefault
        }
    }
}
