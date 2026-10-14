import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.kde.plasma.plasma5support as Plasma5Support

/*
 * Icons: the artwork shown beside each container.
 *
 * Every icon comes from one library folder of per-service images. A small set
 * of the most common services ships with the widget; downloading the selfh.st
 * collection, or pointing at your own folder, adds the rest.
 */
KCM.SimpleKCM {
    id: page

    property alias cfg_serviceIconDirectory: iconDir.text
    property alias cfg_coloredServiceIcons: colorIcons.checked
    property alias cfg_iconVariant: variant.currentIndex
    property alias cfg_customIcons: customIcons.text

    readonly property string defaultFolder: "~/.local/share/dockmoid/icons/svg"

    property bool busy: false
    property string status: ""

    Plasma5Support.DataSource {
        id: shell
        engine: "executable"
        connectedSources: []
        onNewData: function (source, data) {
            disconnectSource(source)
            page.busy = false
            var out = String(data["stdout"] || "").trim()
            if (data["exit code"] === 0 && /^[0-9]+$/.test(out)) {
                page.status = i18np("%1 icon is ready.", "%1 icons are ready.", parseInt(out))
                iconDir.text = page.defaultFolder
            } else {
                let err = String(data["stderr"] || "").trim().split("\n").pop()
                page.status = i18n("The download failed: %1", err || i18n("is git installed and are you online?"))
            }
        }
    }

    /*
     * A sparse, blobless clone fetches only the svg folder (a few MB), and a
     * later run is a fast-forward pull, so "Update" is cheap. Everything goes
     * under the user's own data directory.
     */
    function download() {
        page.busy = true
        page.status = i18n("Downloading…")
        var cmd = 'd="$HOME/.local/share/dockmoid/icons"; mkdir -p "$(dirname "$d")" && '
            + 'if [ -d "$d/.git" ]; then git -C "$d" pull --ff-only -q; '
            + 'else rm -rf "$d.tmp" && git clone --depth 1 --filter=blob:none --sparse -q https://github.com/selfhst/icons.git "$d.tmp" '
            + '&& git -C "$d.tmp" sparse-checkout set svg && rm -rf "$d" && mv "$d.tmp" "$d"; fi '
            + '&& ls "$d/svg" | grep -vc -- "-\\(light\\|dark\\)\\.svg$"'
        shell.connectSource(cmd)
    }

    Kirigami.FormLayout {
        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Provider icon library")
        }

        Controls.TextField {
            id: iconDir
            Kirigami.FormData.label: i18n("Folder:")
            placeholderText: i18n("automatic")
            Layout.preferredWidth: Kirigami.Units.gridUnit * 22
        }
        Hint { text: i18n("Leave empty to use the downloaded set (~/.local/share/dockmoid/icons/svg), then ~/Pictures/selfhst, then the small set that ships with the widget. Any folder of SVG, WebP or PNG files named after services works: plex.svg, pi-hole.svg … Variants named name-light and name-dark are understood.") }

        RowLayout {
            Kirigami.FormData.label: i18n("Get the icons:")
            Controls.Button {
                text: i18n("Download or update selfh.st icons")
                icon.name: "download"
                enabled: !page.busy
                onClicked: page.download()
            }
            Controls.BusyIndicator {
                running: page.busy
                visible: page.busy
                implicitHeight: Kirigami.Units.iconSizes.smallMedium
                implicitWidth: implicitHeight
            }
        }
        Hint {
            visible: page.status !== ""
            text: page.status
        }
        Hint { text: i18n("The widget ships about 120 common services. This fetches the full selfh.st/icons collection (about 3,000 icons, CC BY 4.0) from GitHub with git, only when you press it. Afterwards press Apply.") }

        Controls.CheckBox {
            id: colorIcons
            Kirigami.FormData.label: i18n("Draw:")
            text: i18n("icons in full colour (off draws them in the theme colour)")
        }

        Controls.ComboBox {
            id: variant
            Kirigami.FormData.label: i18n("Variant:")
            model: [i18n("Standard artwork"), i18n("Match the theme (light or dark)")]
        }
        Hint { text: i18n("Many logos come in a white and a dark version. “Match the theme” picks the one that reads against your current colours, when the library has it.") }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("How a container finds its icon")
        }
        Hint { text: i18n("The container's own name, its Compose service name and its image are tried in that order, with common spellings and suffixes handled (portainer-ce → portainer, pihole → pi-hole). Containers started from an image id still match by name. A container with no match just shows its status dot.") }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Your own rules")
        }

        Controls.ScrollView {
            Kirigami.FormData.label: i18n("Rules:")
            Kirigami.FormData.labelAlignment: Qt.AlignTop
            Layout.preferredWidth: Kirigami.Units.gridUnit * 26
            Layout.preferredHeight: Kirigami.Units.gridUnit * 6

            Controls.TextArea {
                id: customIcons
                wrapMode: TextEdit.NoWrap
                font.family: "monospace"
                placeholderText: "myregistry/myservice=portainer"
                selectByMouse: true
            }
        }
        Hint { text: i18n("One rule per line: text=icon-name. A container whose name, image or service contains the text gets that icon from the library (for example: myapp=plex). A line with no “=” gives matching containers no icon. Rules are tried before the automatic match. Lines starting with # are ignored.") }
    }
}
