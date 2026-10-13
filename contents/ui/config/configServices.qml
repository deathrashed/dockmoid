import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts

import org.kde.kirigami as Kirigami

/*
 * Service icons: which container images get a recognisable glyph, and how to
 * extend that list without touching code.
 */
Kirigami.ScrollablePage {
    id: page

    property alias cfg_customIcons: customIcons.text
    property alias cfg_serviceIconDirectory: iconDir.text
    property alias cfg_coloredServiceIcons: colorIcons.checked

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
                Kirigami.FormData.label: i18n("Your own provider icons")
            }
        }

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            type: Kirigami.MessageType.Information
            text: i18n("Point this at a folder of provider icons, for example ~/pictures/selfhst. Any container whose image name matches a file there is drawn with that artwork in full colour, which takes priority over the bundled glyphs below. The images stay in that folder; only their names are indexed.")
        }

        Kirigami.FormLayout {
            wideMode: false
            Controls.Label {
                Kirigami.FormData.label: i18n("Icon folder: ")
                Layout.fillWidth: true
            }
            Controls.TextField {
                id: iconDir
                Layout.fillWidth: true
                placeholderText: "~/pictures/selfhst"
                text: plasmoid.configuration.serviceIconDirectory
            }
        }

        Kirigami.FormLayout {
            wideMode: false
            Controls.CheckBox {
                id: colorIcons
                text: i18n("Draw them in colour")
                checked: plasmoid.configuration.coloredServiceIcons
            }
        }

        Kirigami.FormLayout {
            wideMode: false
            Kirigami.Separator {
                Kirigami.FormData.isSection: true
                Kirigami.FormData.label: i18n("Bundled glyphs")
            }
        }

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            type: Kirigami.MessageType.Information
            text: i18n("Containers get a glyph when their image name contains a known service, so lscr.io/linuxserver/qbittorrent:latest is recognised the same as qbittorrent. Anything unmatched falls back to a state dot, so this is purely cosmetic.")
        }

        Kirigami.FormLayout {
            wideMode: false
            Controls.Label {
                Kirigami.FormData.label: i18n("Extra or replacement rules: ")
                Layout.fillWidth: true
            }
        }

        Controls.ScrollView {
            Layout.fillWidth: true
            Layout.preferredHeight: Kirigami.Units.gridUnit * 6

            Controls.TextArea {
                id: customIcons
                Layout.fillWidth: true
                wrapMode: TextEdit.NoWrap
                font.family: "monospace"
                placeholderText: "myregistry/myservice=portainer"
            }
        }

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            type: Kirigami.MessageType.Information
            text: i18n("One rule per line, as image-substring=glyph. Rules here are matched before the bundled ones, so a rule wins over the default for that service. A line with no '=' masks that substring, which is how you stop a container from picking up a glyph that does not suit it. Lines starting with # are ignored.")
        }

        Item {
            Layout.fillHeight: true
        }
    }
}
