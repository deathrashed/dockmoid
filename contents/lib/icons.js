/*
 * icons.js — turning a container into the name of an icon in the library.
 *
 * Two layers decide it: the user's own rules (below), then a name match against
 * the icon library (further down). Nothing about particular services is
 * hard-coded here; the library is the data.
 */

/*
 * Parse the user's rules. One "text=icon" pair per line: a container whose name,
 * image or service contains `text` gets the library icon called `icon`. A bare
 * "text" (no =) gives matching containers no icon at all. Blank lines and lines
 * starting with # are ignored.
 */
function parseOverrides(text) {
    var list = [];
    if (!text) return list;
    var lines = String(text).split("\n");
    for (var i = 0; i < lines.length; i++) {
        var line = lines[i].trim();
        if (line === "" || line.charAt(0) === "#") continue;
        var idx = line.indexOf("=");
        if (idx < 0) {
            list.push([line, null]);
        } else {
            list.push([line.slice(0, idx).trim(), line.slice(idx + 1).trim()]);
        }
    }
    return list;
}

/*
 * Expand a leading "~" into the user's home directory. QML JavaScript has no
 * environment access, so the home path is passed in by the caller.
 */
function expandHome(path, home) {
    if (!path) return "";
    var p = String(path);
    if (p === "~") return home;
    if (p.indexOf("~/") === 0) return home + "/" + p.slice(2);
    return p;
}

/*
 * First matching rule wins. Returns the icon name, null when the rule masks the
 * container, or undefined when no rule applies.
 */
function ruleMatch(rules, haystack) {
    var text = String(haystack || "").toLowerCase();
    for (var i = 0; i < rules.length; i++) {
        if (rules[i][0] !== "" && text.indexOf(rules[i][0].toLowerCase()) !== -1)
            return rules[i][1];
    }
    return undefined;
}

/* ===================================================== icon library ====== */

/*
 * The library is a plain folder of provider artwork (selfh.st/icons layout:
 * `plex.svg`, plus optional `plex-light.svg` / `plex-dark.svg` variants).
 *
 * QML cannot list a directory, so the backend runs `ls -1` on it and hands the
 * output here. Nothing about the library is baked into the package, which means
 * a freshly downloaded or updated folder is picked up without regenerating
 * anything.
 */

var EXT_RANK = { "svg": 0, "webp": 1, "png": 2 };

/* `ls -1` output -> { name: { file, light, dark } }. SVG beats WebP beats PNG. */
function parseLibrary(listing) {
    var entries = {};
    var rank = {};
    var lines = String(listing || "").split("\n");
    for (var i = 0; i < lines.length; i++) {
        var file = lines[i].trim();
        var dot = file.lastIndexOf(".");
        if (dot <= 0) continue;
        var ext = file.slice(dot + 1).toLowerCase();
        if (EXT_RANK[ext] === undefined) continue;
        var stem = file.slice(0, dot).toLowerCase();
        var slot = "file";
        var base = stem;
        if (/-light$/.test(stem)) { slot = "light"; base = stem.slice(0, -6); }
        else if (/-dark$/.test(stem)) { slot = "dark"; base = stem.slice(0, -5); }
        if (!entries[base]) entries[base] = { "file": "", "light": "", "dark": "" };
        var key = base + "/" + slot;
        if (rank[key] !== undefined && rank[key] <= EXT_RANK[ext]) continue;
        rank[key] = EXT_RANK[ext];
        entries[base][slot] = file;
    }
    // A variant on its own (no plain file) still counts as the icon.
    for (var name in entries) {
        var e = entries[name];
        if (e.file === "") e.file = e.light !== "" ? e.light : e.dark;
    }
    return entries;
}

function libraryCount(entries) {
    var n = 0;
    for (var k in entries) n++;
    return n;
}

/* Registry paths that carry no information about the service. */
var NOISE = ["docker", "docker.io", "ghcr.io", "lscr.io", "quay.io", "gcr.io",
             "registry", "library", "linuxserver", "hotio", "latest", "release"];

/* Names an image is commonly published under vs. how the library spells them. */
var ALIASES = {
    "pihole": "pi-hole",
    "portainer-ce": "portainer",
    "portainer-ee": "portainer",
    "adguardhome": "adguard-home",
    "homeassistant": "home-assistant",
    "couchdb": "apache-couchdb",
    "qbittorrent-nox": "qbittorrent",
    "vaultwarden": "vaultwarden",
    "uptime-kuma": "uptime-kuma",
    "nginx-proxy-manager": "nginx-proxy-manager",
    "jc21": "nginx-proxy-manager"
};

var SUFFIXES = ["-ce", "-ee", "-ngx", "-server", "-app", "-web", "-webui", "-ui",
                "-gui", "-docker", "-nox", "-oss", "-community", "-latest"];

function splitImage(image) {
    var s = String(image || "").toLowerCase();
    var colon = s.lastIndexOf(":");
    if (colon > s.lastIndexOf("/")) s = s.slice(0, colon);
    var at = s.indexOf("@");
    if (at >= 0) s = s.slice(0, at);
    return s.split("/").filter(function (p) { return p !== ""; });
}

/*
 * Ordered, de-duplicated names worth looking up for one container, most
 * specific first: the container's own name, its compose service, the image's
 * final path component, then the rest of the image path. The Compose project
 * is deliberately not used: a helper such as deemix often lives in another
 * app's project and would inherit that app's icon.
 * (An image shown only as a hex id contributes nothing, which is fine — the
 * container and service names still resolve it.)
 */
function libraryCandidates(containerName, service, image, project) {
    var raw = [containerName, service];
    var parts = splitImage(image);
    if (parts.length > 0 && !/^[0-9a-f]{12,64}$/.test(parts[parts.length - 1]))
        raw.push(parts[parts.length - 1]);
    for (var i = parts.length - 2; i >= 0; i--) raw.push(parts[i]);

    var seen = {};
    var out = [];
    for (var j = 0; j < raw.length; j++) {
        var c = String(raw[j] || "").toLowerCase().trim();
        if (c === "" || seen[c] || NOISE.indexOf(c) >= 0) continue;
        seen[c] = true;
        out.push(c);
    }
    return out;
}

/* Spelling variants of one candidate, tried in order. */
function variantsOf(candidate) {
    var list = [candidate];
    var underscored = candidate.replace(/_/g, "-");
    if (underscored !== candidate) list.push(underscored);
    if (ALIASES[candidate]) list.push(ALIASES[candidate]);
    for (var i = 0; i < SUFFIXES.length; i++) {
        var suf = SUFFIXES[i];
        if (candidate.length > suf.length + 2 && candidate.slice(-suf.length) === suf)
            list.push(candidate.slice(0, -suf.length));
    }
    var joined = candidate.replace(/[-_.]/g, "");
    if (joined !== candidate) list.push(joined);
    return list;
}

/*
 * Pick the library entry for a container, or null.
 *
 * 1. exact / aliased / suffix-stripped match, candidate by candidate;
 * 2. a library name that is the candidate minus up to two trailing letters
 *    ("slskdn" -> "slskd"), which covers forks that append a suffix;
 * 3. a hyphenated candidate whose individual words (4+ letters) are names.
 * Later passes only run when every earlier pass found nothing, so a precise
 * match can never be displaced by a loose one.
 */
function libraryMatch(entries, candidates) {
    var i, j, v;
    for (i = 0; i < candidates.length; i++) {
        v = variantsOf(candidates[i]);
        for (j = 0; j < v.length; j++) {
            if (entries[v[j]]) return v[j];
        }
    }
    for (i = 0; i < candidates.length; i++) {
        var c = candidates[i];
        for (var cut = 1; cut <= 2; cut++) {
            if (c.length - cut >= 4 && entries[c.slice(0, -cut)]) return c.slice(0, -cut);
        }
    }
    for (i = 0; i < candidates.length; i++) {
        var words = candidates[i].split(/[-_.]/);
        for (j = 0; j < words.length; j++) {
            if (words[j].length >= 4 && entries[words[j]]) return words[j];
        }
    }
    return null;
}

/* The file to draw for a matched name. variant: 0 standard, 1 match the theme. */
function libraryFile(entries, name, variant, darkTheme) {
    var e = entries[name];
    if (!e) return "";
    if (variant === 1) {
        // "-light" artwork is white, drawn for dark backgrounds, and vice versa.
        var themed = darkTheme ? e.light : e.dark;
        if (themed !== "") return themed;
    }
    return e.file;
}

/* Stable across recreation; endpoint prevents a remote namesake inheriting an icon. */
function customKey(rec, endpoint) {
    var target = rec.project && rec.service ? "service:" + rec.project + "/" + rec.service
                                           : "name:" + String(rec.name || "");
    return String(endpoint || "docker") + "|" + target;
}

function localIconPath(fileUrl) {
    var url = String(fileUrl || "");
    if (!/^file:\/\/\//.test(url)) return "";
    var file;
    try { file = decodeURIComponent(url.slice(7)); } catch (e) { return ""; }
    if (!/\.(svg|png|webp)$/i.test(file) || /[\x00-\x1f]/.test(file)) return "";
    return file;
}

function customEntries(json) {
    try {
        var value = JSON.parse(String(json || "{}"));
        return value && typeof value === "object" && !Array.isArray(value) ? value : {};
    } catch (e) { return {}; }
}

function customMatch(entries, rec, endpoint) {
    var keys = [customKey(rec, endpoint), String(endpoint) + "|name:" + rec.name,
                String(endpoint) + "|image:" + rec.image];
    for (var i = 0; i < keys.length; i++) {
        var entry = entries[keys[i]];
        if (entry && typeof entry.file === "string" && /^[A-Za-z0-9._-]+\.(svg|png|webp)$/i.test(entry.file)) return entry;
    }
    return null;
}
