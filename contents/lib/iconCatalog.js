/* Both upstream indexes are data only. Never accept arbitrary download URLs. */
var providers = {
    dashboard: {name: "Dashboard Icons", index: "https://raw.githubusercontent.com/homarr-labs/dashboard-icons/main/tree.json",
        base: "https://raw.githubusercontent.com/homarr-labs/dashboard-icons/main/", source: "https://github.com/homarr-labs/dashboard-icons", license: "https://github.com/homarr-labs/dashboard-icons/blob/main/LICENSE"},
    selfhst: {name: "selfh.st", index: "https://raw.githubusercontent.com/selfhst/icons/main/index.json",
        base: "https://raw.githubusercontent.com/selfhst/icons/main/", source: "https://github.com/selfhst/icons", license: "https://github.com/selfhst/icons/blob/main/LICENSE"}
};
function entry(provider, name, displayName, file, keywords) {
    var p = providers[provider];
    return {id: provider + ":" + name, provider: provider, providerName: p.name,
        name: name, displayName: displayName, path: file, url: p.base + file,
        searchKey: (name + " " + displayName + " " + (keywords || "")).toLowerCase().replace(/[-_.,/]+/g, " ")};
}
function fromDashboard(tree) {
    if (!tree || !Array.isArray(tree.svg) || !Array.isArray(tree.png) || !Array.isArray(tree.webp)) throw new Error("Invalid Dashboard Icons catalog");
    var chosen = {};
    // Prefer vectors, followed by the smaller raster format. Keep colour variants searchable.
    ["svg", "webp", "png"].forEach(function(format) {
        tree[format].forEach(function(file) {
            if (typeof file !== "string" || !/^[a-z0-9][a-z0-9._-]*\.(svg|png|webp)$/i.test(file) || !file.endsWith("." + format)) return;
            var name = file.slice(0, -(format.length + 1));
            if (!chosen[name]) chosen[name] = entry("dashboard", name, name.replace(/-/g, " "), format + "/" + file, "");
        });
    });
    return Object.keys(chosen).sort().map(function(key) { return chosen[key]; });
}
function fromSelfhst(index) {
    if (!Array.isArray(index)) throw new Error("Invalid selfh.st catalog");
    var out = [];
    index.forEach(function(icon) {
        if (!icon || typeof icon.Reference !== "string" || !/^[a-z0-9][a-z0-9._-]*$/i.test(icon.Reference)) return;
        var ext = icon.SVG === "Yes" ? "svg" : icon.WebP === "Yes" ? "webp" : icon.PNG === "Yes" ? "png" : "";
        if (!ext) return;
        var name = icon.Reference;
        out.push(entry("selfhst", name, String(icon.Name || name), ext + "/" + name + "." + ext, icon.Tags));
        ["Light", "Dark"].forEach(function(variant) {
            if (icon[variant] !== "Yes") return;
            var suffix = variant.toLowerCase();
            out.push(entry("selfhst", name + "-" + suffix, String(icon.Name || name) + " (" + suffix + ")", ext + "/" + name + "-" + suffix + "." + ext, icon.Tags));
        });
    });
    return out;
}
function search(entries, query, provider) {
    var normalized = String(query || "").trim().toLowerCase().replace(/[-_.,/]+/g, " ");
    var words = normalized.split(/\s+/).filter(function(w) { return w !== ""; });
    return entries.filter(function(icon) {
        return (provider === "all" || icon.provider === provider) && words.every(function(word) { return icon.searchKey.indexOf(word) >= 0; });
    }).sort(function(a, b) {
        var exactA = a.name === String(query).trim().toLowerCase() ? 0 : 1;
        var exactB = b.name === String(query).trim().toLowerCase() ? 0 : 1;
        return exactA - exactB || a.displayName.localeCompare(b.displayName) || a.provider.localeCompare(b.provider);
    });
}
function remoteInfo(url) {
    var match = /^https:\/\/raw\.githubusercontent\.com\/(homarr-labs\/dashboard-icons|selfhst\/icons)\/main\/(svg|png|webp)\/([A-Za-z0-9][A-Za-z0-9._-]*)\.(svg|png|webp)$/.exec(String(url));
    if (!match || match[2] !== match[4]) return null;
    var provider = match[1] === "selfhst/icons" ? providers.selfhst : providers.dashboard;
    return {url: String(url), extension: match[4], provider: provider.name, source: provider.source, license: provider.license};
}
