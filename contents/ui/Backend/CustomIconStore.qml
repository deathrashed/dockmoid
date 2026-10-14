import QtQuick
import QtCore
import "../../lib/icons.js" as Icons
import "../../lib/iconCatalog.js" as Catalog

/* User artwork is data, kept outside the replaceable installed package. */
Item {
    id: store
    visible: false
    property var cfg: null
    property var runner: null
    readonly property string endpoint: String(cfg ? cfg.engineCommand || "docker" : "docker")
        + (cfg && cfg.activeContext ? (/podman$/.test(String(cfg.engineCommand)) ? " --connection " : " --context ") + cfg.activeContext : "")
    readonly property string directory: decodeURIComponent(String(StandardPaths.writableLocation(StandardPaths.GenericDataLocation))
        .replace(/^file:\/\//, "")) + "/dockmoid/icons/custom"
    readonly property var entries: Icons.customEntries(cfg ? cfg.customIconFiles : "{}")

    function keyFor(rec) { return Icons.customKey(rec, endpoint) }
    function keyForName(name) { return endpoint + "|name:" + String(name).trim() }
    function keyForImage(image) { return endpoint + "|image:" + String(image).trim() }
    function quote(value) { return "'" + String(value).replace(/'/g, "'\\''") + "'" }

    function urlFor(rec) {
        var match = Icons.customMatch(entries, rec, endpoint)
        return match ? ({url: "file://" + directory + "/" + match.file, colored: match.original === true}) : null
    }

    function reset(key) {
        var next = Icons.customEntries(cfg.customIconFiles)
        delete next[key]
        cfg.customIconFiles = JSON.stringify(next)
    }

    function saveEntry(key, filename, original, label, origin) {
        var next = Icons.customEntries(cfg.customIconFiles)
        next[key] = {file: filename, original: !!original, label: String(label || key)}
        if (origin) {
            next[key].provider = origin.provider
            next[key].source = origin.url
            next[key].license = origin.license
        }
        cfg.customIconFiles = JSON.stringify(next)
    }

    function importRemote(key, url, original, label, callback) {
        var origin = Catalog.remoteInfo(url)
        if (!origin || !key || !runner) {
            if (callback) callback(false, i18n("Choose an icon from Dashboard Icons or selfh.st."))
            return
        }
        var filename = "icon-" + Date.now() + "-" + Math.floor(Math.random() * 0xffffff).toString(16) + "." + origin.extension
        var dest = directory + "/" + filename
        var provenance = JSON.stringify({provider: origin.provider, source: origin.url, license: origin.license})
        var script = "set -eu\nmkdir -p " + quote(directory) + "\n"
            + "stage=$(mktemp " + quote(directory + "/.download-XXXXXX") + ")\n"
            + "trap 'rm -f -- \"$stage\"' EXIT HUP INT TERM\n"
            + "if command -v curl >/dev/null 2>&1; then\n"
            + "  curl --fail --silent --show-error --location --proto '=https' --proto-redir '=https' --connect-timeout 10 --max-time 45 --max-filesize 5242880 -o \"$stage\" " + quote(origin.url) + "\n"
            + "elif command -v wget >/dev/null 2>&1; then\n"
            + "  wget --quiet --https-only --timeout=30 --tries=1 --max-redirect=3 -O \"$stage\" " + quote(origin.url) + "\n"
            + "else\n  echo 'Saving online icons requires curl or wget. You can still choose a local image file.' >&2; exit 69\nfi\n"
            + "test -s \"$stage\" && test \"$(wc -c < \"$stage\")\" -le 5242880\n"
            + "cp -n \"$stage\" " + quote(dest) + "\n"
            + "printf '%s\\n' " + quote(provenance) + " > " + quote(dest + ".source.json") + "\n"
        runner.run("sh -c " + quote(script), "icon-download", function(code, out, err) {
            if (code === 0) store.saveEntry(key, filename, original, label, origin)
            if (callback) callback(code === 0, code === 0 ? "" : String(err || i18n("The icon could not be downloaded. Check your connection or choose a local file.")))
        }, {timeout: 60000})
    }

    function importFile(key, fileUrl, original, label, callback) {
        var src = Icons.localIconPath(fileUrl)
        if (!src || !key || !runner) {
            if (callback) callback(false, i18n("Choose a local SVG, PNG or WebP image."))
            return
        }
        var ext = src.slice(src.lastIndexOf(".")).toLowerCase()
        var filename = "icon-" + Date.now() + "-" + Math.floor(Math.random() * 0xffffff).toString(16) + ext
        var dest = directory + "/" + filename
        // cp -n and a generated name never overwrite the original or another import.
        var cmd = "test -f " + quote(src) + " && mkdir -p " + quote(directory)
            + " && cp -n " + quote(src) + " " + quote(dest)
        runner.run(cmd, "icon-import", function (code, out, err) {
            if (code === 0) {
                store.saveEntry(key, filename, original, label, null)
            }
            if (callback) callback(code === 0, code === 0 ? "" : String(err || i18n("Could not copy the image.")))
        })
    }
}
