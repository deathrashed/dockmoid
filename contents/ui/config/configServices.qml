import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import QtCore

import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import "../backend" as Backend
import "../components" as Components

/* Artwork library settings and per-container custom mappings. */
KCM.SimpleKCM {
    id: page

    property string cfg_serviceIconDirectoryDefault
    property bool cfg_coloredServiceIconsDefault
    property int cfg_iconVariantDefault
    property string cfg_customIconsDefault
    property string cfg_customIconFilesDefault
    property string cfg_engineCommand
    property string cfg_activeContext

    property alias cfg_serviceIconDirectory: iconDir.text
    property alias cfg_coloredServiceIcons: colorIcons.checked
    property alias cfg_iconVariant: variant.currentIndex
    property alias cfg_customIcons: customIcons.value
    property string cfg_customIconFiles: "{}"

    property bool busy: false
    property string status: ""
    property string mappingSearch: ""
    property string selectedKey: ""
    property string selectedLabel: ""

    readonly property string libraryRoot: decodeURIComponent(String(StandardPaths.writableLocation(StandardPaths.GenericDataLocation))
        .replace(/^file:\/\//, "")) + "/dockmoid"
    readonly property string libraryDirectory: libraryRoot + "/dashboard-icons/svg"

    QtObject {
        id: iconConfig
        property string customIconFiles: page.cfg_customIconFiles
        property string engineCommand: page.cfg_engineCommand
        property string activeContext: page.cfg_activeContext
        onCustomIconFilesChanged: {
            if (page.cfg_customIconFiles !== customIconFiles)
                page.cfg_customIconFiles = customIconFiles
        }
    }
    onCfg_customIconFilesChanged: {
        if (iconConfig.customIconFiles !== cfg_customIconFiles)
            iconConfig.customIconFiles = cfg_customIconFiles
    }

    Backend.CommandRunner {
        id: runner
        timeout: 100000
        maxConcurrent: 1
    }

    Backend.CustomIconStore {
        id: iconStore
        cfg: iconConfig
        runner: runner
    }

    function shellQuote(value) {
        return "'" + String(value).replace(/'/g, "'\\''") + "'"
    }

    function download() {
        page.busy = true
        page.status = i18n("Downloading the icon library…")
        var base = page.libraryRoot
        var dest = base + "/dashboard-icons"
        var qBase = shellQuote(base)
        var qDest = shellQuote(dest)
        var script = "set -eu\n"
            + "base=" + qBase + "\n"
            + "dest=" + qDest + "\n"
            + "mkdir -p \"$base\"\n"
            + "stage=$(mktemp -d \"$base/.dockmoid-dashboard-stage.XXXXXX\")\n"
            + "case \"$stage\" in \"$base\"/.dockmoid-dashboard-stage.*) ;; *) exit 70 ;; esac\n"
            + "trap 'case \"$stage\" in \"$base\"/.dockmoid-dashboard-stage.*) rm -rf -- \"$stage\" ;; *) exit 70 ;; esac' EXIT HUP INT TERM\n"
            + "git clone --depth 1 --filter=blob:none --sparse -q https://github.com/homarr-labs/dashboard-icons.git \"$stage/repo\"\n"
            + "git -C \"$stage/repo\" sparse-checkout set svg png webp\n"
            + "git -C \"$stage/repo\" show HEAD:LICENSE > \"$stage/LICENSE\"\n"
            + "git -C \"$stage/repo\" show HEAD:NOTICE.md > \"$stage/NOTICE.md\" 2>/dev/null || :\n"
            + "for format in svg png webp; do test -d \"$stage/repo/$format\"; done\n"
            + "if [ -e \"$dest\" ]; then\n"
            + "  test -f \"$dest/.dockmoid-dashboard-owned\" || { echo 'The existing icon folder is not managed by Dockmoid; it was left unchanged.' >&2; exit 73; }\n"
            + "  for format in svg png webp; do mkdir -p \"$dest/svg\"; cp -au \"$stage/repo/$format/.\" \"$dest/svg/\"; done\n"
            + "  cp \"$stage/LICENSE\" \"$dest/LICENSE\"\n"
            + "  if [ -s \"$stage/NOTICE.md\" ]; then cp \"$stage/NOTICE.md\" \"$dest/NOTICE.md\"; fi\n"
            + "else\n"
            + "  mkdir \"$stage/install\"\n"
            + "  mkdir \"$stage/install/svg\"\n"
            + "  for format in svg png webp; do cp -a \"$stage/repo/$format/.\" \"$stage/install/svg/\"; done\n"
            + "  cp \"$stage/LICENSE\" \"$stage/install/LICENSE\"\n"
            + "  if [ -s \"$stage/NOTICE.md\" ]; then cp \"$stage/NOTICE.md\" \"$stage/install/NOTICE.md\"; fi\n"
            + "  printf '%s\\n' 'dockmoid Dashboard Icons library' > \"$stage/install/.dockmoid-dashboard-owned\"\n"
            + "  mv \"$stage/install\" \"$dest\"\n"
            + "fi\n"
            + "find \"$dest/svg\" -maxdepth 1 -type f | wc -l | tr -d ' '\n"
        runner.run("sh -c " + shellQuote(script), "settings-icon-library", function(code, out, err) {
            page.busy = false
            if (code === 0) {
                page.status = i18n("Icon library updated. %1 image files are ready; press Apply to use them.", String(out).trim())
                iconDir.text = page.libraryDirectory
            } else {
                const detail = String(err || out || "").trim().split("\n").pop()
                page.status = i18n("The download failed; the existing library remains available. %1", detail)
            }
        }, {timeout: 90000})
    }

    function mappingKeys() {
        var keys = Object.keys(iconStore.entries)
        var query = page.mappingSearch.trim().toLowerCase()
        if (query !== "")
            keys = keys.filter(function(key) {
                var entry = iconStore.entries[key] || {}
                return key.toLowerCase().indexOf(query) >= 0 || String(entry.label || "").toLowerCase().indexOf(query) >= 0
            })
        return keys.sort()
    }

    function addMapping() {
        var target = mappingTarget.currentIndex
        var detail = mappingValue.text.trim()
        if (!detail) {
            status = i18n("Enter a container name, image, or Compose project and service first.")
            return
        }
        if (target === 2) {
            const service = serviceValue.text.trim()
            if (!service || detail.indexOf("/") >= 0 || service.indexOf("/") >= 0) {
                status = i18n("Enter the Compose project and service as separate names.")
                return
            }
            selectedKey = iconStore.endpoint + "|service:" + detail + "/" + service
            selectedLabel = i18n("Compose service %1/%2", detail, service)
        } else if (target === 1) {
            selectedKey = iconStore.keyForImage(detail)
            selectedLabel = i18n("Image %1", detail)
        } else {
            selectedKey = iconStore.keyForName(detail)
            selectedLabel = i18n("Container %1", detail)
        }
        iconChooser.chooseForKey(selectedKey, selectedLabel, detail)
    }

    QtObject {
        id: iconBackend
        readonly property var customIconStore: iconStore
    }
    Components.CustomIconDialog {
        id: iconChooser
        backend: iconBackend
        onIconSaved: {
            page.status = i18n("Custom icon saved. Press Apply to use it.")
            mappingList.model = page.mappingKeys()
        }
    }

    ColumnLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Kirigami.Units.smallSpacing

        Kirigami.FormLayout {
            Layout.fillWidth: true

            Kirigami.Separator {
                Kirigami.FormData.isSection: true
                Kirigami.FormData.label: i18n("Provider icon library")
            }

            RowLayout {
                Kirigami.FormData.label: i18n("Folder:")
                Controls.TextField {
                    id: iconDir
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0

                    placeholderText: i18n("automatic")
                }
                QuestionHelp { helpText: i18n("Leave empty to use the downloaded set, then the older local library and the icons that ship with Dockmoid. A folder of SVG, WebP or PNG files named after services also works. Names such as plex-light.svg and plex-dark.svg provide theme variants.") }
            }

            RowLayout {
                Kirigami.FormData.label: i18n("Get icons:")
                RowLayout {

                    Controls.Button {
                        text: i18n("Download or update Dashboard Icons")
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
                QuestionHelp { helpText: i18n("The download starts only when you press the button. Dockmoid stages the download under its own data folder and leaves an existing unmanaged folder untouched. Git and an internet connection are needed.") }
            }

            Controls.CheckBox {
                id: colorIcons
                Kirigami.FormData.label: i18n("Draw:")
                text: i18n("icons in full colour")
            }

            RowLayout {
                Kirigami.FormData.label: i18n("Variant:")
                Controls.ComboBox {
                    id: variant

                    model: [i18n("Standard artwork"), i18n("Match the theme")]
                }
                QuestionHelp { helpText: i18n("When the library has light and dark versions, matching the theme picks the variant intended for the current background.") }
            }

            Kirigami.Separator {
                Kirigami.FormData.isSection: true
                Kirigami.FormData.label: i18n("Icon rules")
            }

            RowLayout {
                Kirigami.FormData.label: i18n("Advanced rules:")
                StructuredRulesEditor {
                    id: customIcons
                    title: i18n("Library rules")
                    kind: "keyValue"
                    delimiter: "="
                    headers: [i18n("Match text"), i18n("Icon name (empty hides icon)")]
                    allowEmptyValue: true
                    example: i18n("No custom icon rules. Automatic library matching stays enabled.")

                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                }
                QuestionHelp { helpText: i18n("Structured rows keep the existing text=icon-name format. A bare match with an empty icon hides the automatic icon. Use Advanced text to edit comments or unusual entries. Structured custom mappings below take priority over these rules.") }
            }
        }

        RowLayout {
            Kirigami.FormLayout {
                Layout.fillWidth: true

                Kirigami.Separator {
                    Kirigami.FormData.isSection: true
                    Kirigami.FormData.label: i18n("Custom icon mappings")
                }

                RowLayout {
                    Kirigami.FormData.label: i18n("Match:")
                    RowLayout {

                        Controls.ComboBox {
                            id: mappingTarget
                            model: [i18n("Container name"), i18n("Image"), i18n("Compose service")]
                        }
                        Controls.TextField {
                            id: mappingValue
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            placeholderText: mappingTarget.currentIndex === 2 ? i18n("project") : mappingTarget.currentIndex === 1 ? i18n("image name") : i18n("container name")
                        }
                        Controls.TextField {
                            id: serviceValue
                            visible: mappingTarget.currentIndex === 2
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            placeholderText: i18n("service")
                        }
                        Controls.Button {
                            text: i18n("Choose icon…")
                            icon.name: "document-open"
                            onClicked: page.addMapping()
                        }
                    }
                    QuestionHelp { helpText: i18n("Search Dashboard Icons and selfh.st, or browse local files. Chosen artwork is copied into Dockmoid's user data, so the source file can move or be deleted. Container names and image rules apply to the selected engine/context; Compose project/service mappings survive container recreation. Choose another host under Advanced → Connection before creating mappings for it.") }
                }

                RowLayout {
                    Kirigami.FormData.label: i18n("Find mapping:")
                    Controls.TextField {
                        id: searchMappings
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        placeholderText: i18n("Search names or keys")
                        onTextChanged: {
                            page.mappingSearch = text
                            mappingList.model = page.mappingKeys()
                        }
                    }
                }

                RowLayout {
                    Kirigami.FormData.label: i18n("Saved mappings:")
                    Controls.ScrollView {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        Layout.preferredHeight: Kirigami.Units.gridUnit * 8

                        Kirigami.FormData.labelAlignment: Qt.AlignTop
                        ListView {
                            id: mappingList
                            model: page.mappingKeys()
                            clip: true
                            Controls.Label {
                                anchors.centerIn: parent
                                visible: mappingList.count === 0
                                text: i18n("No custom mappings match this search.")
                                color: Kirigami.Theme.disabledTextColor
                            }
                            delegate: Controls.ItemDelegate {
                                id: mappingDelegate
                                readonly property string mappingKey: modelData
                                width: ListView.view.width
                                text: String(iconStore.entries[mappingKey].label || mappingKey)
                                contentItem: RowLayout {
                                    Image {
                                        Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                                        Layout.preferredHeight: Kirigami.Units.iconSizes.medium
                                        source: "file://" + iconStore.directory + "/" + iconStore.entries[mappingDelegate.mappingKey].file
                                        fillMode: Image.PreserveAspectFit
                                        asynchronous: true
                                    }
                                    Controls.Label { Layout.fillWidth: true; text: String(iconStore.entries[mappingDelegate.mappingKey].label || mappingDelegate.mappingKey); elide: Text.ElideMiddle }
                                    Controls.Button {
                                        text: i18n("Reset")
                                        icon.name: "edit-delete"
                                        onClicked: {
                                            iconStore.reset(mappingDelegate.mappingKey)
                                            mappingList.model = page.mappingKeys()
                                            page.status = i18n("Mapping removed. Press Apply to save.")
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            visible: page.status !== ""
            text: page.status
        }

        Controls.Button {
            text: i18n("Restore page defaults")
            icon.name: "edit-undo"
            onClicked: {
                page.cfg_serviceIconDirectory = page.cfg_serviceIconDirectoryDefault
                page.cfg_coloredServiceIcons = page.cfg_coloredServiceIconsDefault
                page.cfg_iconVariant = page.cfg_iconVariantDefault
                page.cfg_customIcons = page.cfg_customIconsDefault
                page.cfg_customIconFiles = page.cfg_customIconFilesDefault
                iconConfig.customIconFiles = page.cfg_customIconFilesDefault
                mappingList.model = page.mappingKeys()
            }
        }
    }
}
