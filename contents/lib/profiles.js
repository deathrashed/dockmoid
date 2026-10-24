/* Versioned settings profiles. Imported command templates require explicit opt-in. */
var KEYS = ["engineCommand", "eventsCommand", "updateInterval", "changeCheckInterval", "idleCheckInterval", "usageInterval", "logTailLines", "checkActiveCommand", "listCommand", "usageCommand", "infoCommand", "systemDfCommand", "startOneCommand", "stopOneCommand", "restartOneCommand", "killOneCommand", "pauseOneCommand", "unpauseOneCommand", "removeOneCommand", "renameOneCommand", "pullImageCommand", "logsCommand", "logsFollowCommand", "shellCommand", "inspectCommand", "groupStartCommand", "groupStopCommand", "groupRestartCommand", "startCommand", "stopServiceCommand", "stopSocketCommand", "imagesCommand", "volumesCommand", "networksCommand", "removeImageCommand", "removeVolumeCommand", "removeNetworkCommand", "composeCommand", "updateCheckCommand", "contextListCommand", "restartPolicyCommand", "setRestartPolicyCommand", "pruneCommand", "fetchOnStartup", "refreshOnExpand", "statsWhenCollapsed", "useNotifications", "confirmDestructive", "showDiskUsage", "notifyOnEngineChange", "debugCommands", "readOnly", "savedViews", "notifyOnCrash", "notifyOnRestartLoop", "notifyOnUnhealthy", "notifyOnRecovered", "notifyOnStartStop", "notifyMuteAfterAction", "restartPolicyInterval", "alertCpu", "alertMem", "alertSeconds", "checkImageUpdates", "updateCheckHours", "notifyOnUpdate", "logWatchMinutes", "notifyOnLogIssue", "probes", "probeInterval", "notifyOnProbe", "activeContext", "pinned", "historySamples", "middleClickAction", "terminalCommand", "editorCommand", "launchers", "shellList", "lanHost", "tailscaleHost", "autoDetectHosts", "enableBrowserLinks", "allowLanLinks", "allowTailscaleLinks", "httpsPorts", "defaultViewMode", "defaultDetailLevel", "defaultGridDetailLevel", "defaultTableDetailLevel", "resourceBarMax", "panelStyle", "deploymentDirectory", "deploymentStorageDirectory", "deploymentRegistry", "deploymentRestartPolicy", "deploymentNetwork", "engineStorageTarget", "sortRole", "sortAscending", "showHeader", "showStatusBar", "showActivityBar", "showHealth", "showResourceBars", "rowIconSize", "separateResult", "separator", "badgeStyle", "searchStyle", "searchScope", "searchShortcut", "mainDot", "mainDotPosition", "mainDotColor", "mainDotUseCustomColor", "iconColor", "iconUseCustomColor", "wrapText", "widthFit", "hideWhenInactive", "panelIndicator", "indicatorTarget", "customStateColors", "stateOkColor", "stateBadColor", "statePausedColor", "showRestartPolicy", "customIconFiles", "customIcons", "serviceIconDirectory", "iconVariant", "coloredServiceIcons"];
function commandKey(key) { return /Command$/.test(key) || key === "launchers"; }
function capture(page) {
    var values = {};
    KEYS.forEach(function (key) {
        var value = page["cfg_" + key];
        if (value !== undefined && value !== null && ["string", "boolean", "number"].indexOf(typeof value) >= 0) values[key] = value;
    });
    return values;
}
function parse(text, allowCommands) {
    var data = JSON.parse(String(text || "{}"));
    if (data.version !== 1 || !Array.isArray(data.profiles)) throw new Error("Unsupported profile version");
    if (data.profiles.length > 100) throw new Error("Too many profiles");
    var ids = {};
    var result = data.profiles.map(function (profile) {
        if (!profile || !/^[A-Za-z0-9._-]+$/.test(profile.id) || ids[profile.id] || typeof profile.name !== "string") throw new Error("Invalid profile");
        ids[profile.id] = true;
        var values = {};
        KEYS.forEach(function (key) {
            if (!allowCommands && commandKey(key)) return;
            var value = (profile.values || {})[key];
            if (["string", "boolean", "number"].indexOf(typeof value) >= 0) values[key] = value;
        });
        if (values.activeContext && !/^[A-Za-z0-9][A-Za-z0-9_.-]*$/.test(values.activeContext)) delete values.activeContext;
        return {id: profile.id, name: profile.name.slice(0, 100), values: values};
    });
    return {version: 1, profiles: result};
}
function load(text) {
    try { return parse(text, true); } catch (e) { return {version: 1, profiles: []}; }
}
function upsert(data, profile) {
    var next = parse(JSON.stringify(data || {version: 1, profiles: []}), true);
    var index = next.profiles.findIndex(function (saved) { return saved.id === profile.id; });
    if (index < 0 && next.profiles.length >= 100) throw new Error("Profile limit reached (100)");
    var normalized = parse(JSON.stringify({version: 1, profiles: [profile]}), true).profiles[0];
    if (index < 0) next.profiles.push(normalized);
    else next.profiles[index] = normalized;
    return next;
}
function merge(existing, incoming, idPrefix) {
    var next = parse(JSON.stringify(existing || {version: 1, profiles: []}), true);
    var additions = parse(JSON.stringify(incoming || {version: 1, profiles: []}), true);
    if (next.profiles.length + additions.profiles.length > 100) throw new Error("Profile limit is 100; remove a saved profile before importing");
    var ids = {};
    next.profiles.forEach(function (profile) { ids[profile.id] = true; });
    var prefix = String(idPrefix || "import-");
    additions.profiles.forEach(function (profile, index) {
        var id = prefix + index;
        var suffix = 1;
        while (ids[id]) id = prefix + index + "-" + suffix++;
        if (!/^[A-Za-z0-9._-]+$/.test(id)) throw new Error("Invalid imported profile id");
        profile.id = id;
        ids[id] = true;
        next.profiles.push(profile);
    });
    return next;
}
function prepareExport(data, currentProfile, allowCommands) {
    var result = parse(JSON.stringify(data || {version: 1, profiles: []}), true);
    var includedCurrent = false;
    if (currentProfile && result.profiles.length < 100) {
        var current = parse(JSON.stringify({version: 1, profiles: [currentProfile]}), true).profiles[0];
        result.profiles.push(current);
        includedCurrent = true;
    }
    result = parse(JSON.stringify(result), !!allowCommands);
    return {data: result, includedCurrent: includedCurrent};
}
/* Every filter the state menu offers; "attention" is stored as problems. */
var VIEW_STATES = ["all", "running", "stopped", "not-created", "updates", "paused", "restarting", "created", "unhealthy", "failed"];
function parseViews(text) {
    try {
        var list = JSON.parse(String(text || "[]"));
        if (!Array.isArray(list)) return [];
        return list.filter(function (v) { return v && typeof v.name === "string" && [0, 1, 2, 3].indexOf(v.mode) >= 0; })
            .slice(0, 30).map(function (v) { return {name: v.name.slice(0, 80), search: String(v.search || ""), mode: v.mode, state: VIEW_STATES.indexOf(v.state) >= 0 ? v.state : "all", detailLevel: [0, 1, 2, 3].indexOf(v.detailLevel) >= 0 ? v.detailLevel : 1, problems: !!v.problems || v.state === "attention"}; });
    } catch (e) { return []; }
}
