/*
 * parsers.js — pure data helpers for the Docker companion plasmoid.
 *
 * Everything in here is deliberately side-effect free and free of QML types so
 * it can be reasoned about (and unit tested) on its own. All functions accept
 * the raw stdout of a `docker ...` invocation and return plain JS values.
 *
 * Parsing notes for the supported CLI shapes:
 *   - `docker ps --format json`      one JSON object per line (Docker 23+).
 *   - `docker stats --no-stream --format json`  one JSON object per line.
 *   - Older podman emits `Names` as an array, Docker 23+ as a comma string.
 *     firstName() copes with both.
 *   - `Labels` is a comma separated "k=v" string. Values may themselves
 *     contain commas, so labelMap() only ever splits on the first "=" and
 *     accepts keys without a value.
 */

function firstName(names) {
    if (!names) return "";
    if (Array.isArray(names)) {
        return String(names[0] || "").replace(/^\//, "");
    }
    return String(names).split(",")[0].replace(/^\//, "").trim();
}

function labelMap(labels) {
    if (!labels) return {};
    if (typeof labels === "object" && !Array.isArray(labels)) return labels;
    var map = {};
    var parts = String(labels).split(",");
    for (var i = 0; i < parts.length; i++) {
        var idx = parts[i].indexOf("=");
        if (idx <= 0) continue;
        map[parts[i].slice(0, idx)] = parts[i].slice(idx + 1);
    }
    return map;
}

function num(value) {
    var v = parseFloat(value);
    return isNaN(v) ? 0 : v;
}

/* "12.34%" -> 12.34 */
function percent(value) {
    return num(value);
}

/* docker ps --format json -> normalized container records */
function parseContainers(stdout) {
    var out = [];
    if (!stdout) return out;
    var lines = String(stdout).split("\n");
    for (var i = 0; i < lines.length; i++) {
        var line = lines[i].trim();
        if (line === "") continue;
        var d;
        try {
            d = JSON.parse(line);
        } catch (e) {
            continue; // a truncated/garbled line must not kill the whole refresh
        }
        out.push(normalizeContainer(d));
    }
    return out;
}

function normalizeContainer(d) {
    var labels = labelMap(d.Labels);
    var state = d.State || "unknown";
    return {
        "id": d.ID || "",
        "name": firstName(d.Names) || d.ID || "unknown",
        "image": d.Image || "",
        "command": d.Command || "",
        "createdAt": d.CreatedAt || "",
        "runningFor": d.RunningFor || "",
        "state": state,
        "status": d.Status || "",
        "health": d.HealthStatus || "none",
        "isRunning": state === "running",
        "localVolumes": String(d.LocalVolumes === undefined ? 0 : d.LocalVolumes),
        "networks": d.Networks || "",
        "mounts": d.Mounts || "",
        "ports": d.Ports || "",
        "size": d.Size || "",
        "platform": d.Platform ? (d.Platform.os + "/" + d.Platform.architecture) : "",
        "project": labels["com.docker.compose.project"] || "",
        "service": labels["com.docker.compose.service"] || "",
        "composeFiles": labels["com.docker.compose.project.config_files"] || "",
        "composeWorkDir": labels["com.docker.compose.project.working_dir"] || "",
        "composeProfile": labels["com.docker.compose.profile"] || "",
        // live stats, filled in by applyStats()
        "cpu": "",
        "mem": "",
        "memU": "",
        "blockio": "",
        "netio": "",
        "pids": "",
        "cpuPct": 0,
        "memPct": 0
    };
}

/* docker stats --no-stream --format json -> { <id>: stats } keyed by both the
   short id (as printed in the ID field) and the full 64 char id. */
function parseStats(stdout) {
    var map = {};
    if (!stdout) return map;
    var lines = String(stdout).split("\n");
    for (var i = 0; i < lines.length; i++) {
        var line = lines[i].trim();
        if (line === "") continue;
        var d;
        try {
            d = JSON.parse(line);
        } catch (e) {
            continue;
        }
        var rec = {
            "cpu": d.CPUPerc || "",
            "mem": d.MemPerc || "",
            "memU": d.MemUsage || "",
            "blockio": d.BlockIO || "",
            "netio": d.NetIO || "",
            "pids": d.PIDs || "",
            "cpuPct": percent(d.CPUPerc),
            "memPct": percent(d.MemPerc)
        };
        if (d.ID) map[d.ID] = rec;
        if (d.Container) map[d.Container] = rec;
    }
    return map;
}

function applyStats(containers, stats) {
    for (var i = 0; i < containers.length; i++) {
        var c = containers[i];
        var s = stats[c.id];
        if (!s || !c.isRunning) {
            c.cpu = ""; c.mem = ""; c.memU = ""; c.blockio = "";
            c.netio = ""; c.pids = ""; c.cpuPct = 0; c.memPct = 0;
            continue;
        }
        c.cpu = s.cpu; c.mem = s.mem; c.memU = s.memU;
        c.blockio = s.blockio; c.netio = s.netio; c.pids = s.pids;
        c.cpuPct = s.cpuPct; c.memPct = s.memPct;
    }
    return containers;
}

/*
 * Engine summary.
 *
 * The configured infoCommand is expected to emit pipe separated fields (see the
 * default in main.xml) because a JSON template needs embedded quotes that are
 * painful to hand edit in a config text box. A JSON object is still accepted so
 * an existing custom command keeps working.
 *
 *   ServerVersion|NCPU|MemTotal|Images|Containers|Running|Paused|Stopped|Name|OSType|Arch
 */
function parseInfo(stdout) {
    var empty = {
        "serverVersion": "", "ncpu": 0, "memTotal": 0,
        "images": 0, "containers": 0, "running": 0, "paused": 0, "stopped": 0,
        "name": "", "os": "", "arch": ""
    };
    if (!stdout) return empty;

    var text = String(stdout).trim();

    if (text.charAt(0) === "{") {
        var d;
        try {
            d = JSON.parse(text);
        } catch (e) {
            return empty;
        }
        empty.serverVersion = d.ServerVersion || "";
        empty.ncpu = num(d.NCPU);
        empty.memTotal = num(d.MemTotal);
        empty.images = num(d.Images);
        empty.containers = num(d.Containers);
        empty.running = num(d.Running);
        empty.paused = num(d.Paused);
        empty.stopped = num(d.Stopped);
        empty.name = d.Name || "";
        empty.os = d.OSType || "";
        empty.arch = d.Architecture || "";
        return empty;
    }

    var f = text.split("|");
    empty.serverVersion = f[0] || "";
    empty.ncpu = num(f[1]);
    empty.memTotal = num(f[2]);
    empty.images = num(f[3]);
    empty.containers = num(f[4]);
    empty.running = num(f[5]);
    empty.paused = num(f[6]);
    empty.stopped = num(f[7]);
    empty.name = f[8] || "";
    empty.os = f[9] || "";
    empty.arch = f[10] || "";
    return empty;
}

/* docker system df --format json -> array of { type, total, active, size, reclaimable } */
function parseSystemDf(stdout) {
    var out = [];
    if (!stdout) return out;
    var lines = String(stdout).split("\n");
    for (var i = 0; i < lines.length; i++) {
        var line = lines[i].trim();
        if (line === "") continue;
        var d;
        try {
            d = JSON.parse(line);
        } catch (e) {
            continue;
        }
        out.push({
            "type": d.Type || "",
            "total": num(d.TotalCount),
            "active": num(d.Active),
            "size": d.Size || "",
            "reclaimable": d.Reclaimable || ""
        });
    }
    return out;
}

/* Aggregate per-container stats into engine-wide CPU / memory figures. */
function aggregate(containers) {
    var running = 0, cpuSum = 0, memSum = 0, pids = 0, unhealthy = 0, paused = 0;
    for (var i = 0; i < containers.length; i++) {
        var c = containers[i];
        if (c.isRunning) {
            running++;
            cpuSum += c.cpuPct;
            memSum += c.memPct;
            pids += num(c.pids);
        }
        if (c.state === "paused") paused++;
        if (c.health === "unhealthy") unhealthy++;
    }
    return {
        "running": running,
        "paused": paused,
        "unhealthy": unhealthy,
        "cpuSum": cpuSum,
        "memSum": memSum,
        "pids": pids
    };
}

/* ------------------------------------------------------------------ ports -- */

/* "0.0.0.0:8080->80/tcp, [::]:8080->80/tcp" -> [{bind,hostPort,proto}] */
function parsePorts(portsStr) {
    var res = [];
    if (!portsStr) return res;
    var re = /(\[[0-9a-fA-F:]+\]|[0-9.]+):(\d+)->(\d+)\/([a-z]+)/g;
    var m;
    while ((m = re.exec(portsStr)) !== null) {
        res.push({
            "bind": m[1],
            "hostPort": parseInt(m[2], 10),
            "containerPort": parseInt(m[3], 10),
            "proto": m[4]
        });
    }
    return res;
}

function isLoopback(bind) {
    return bind === "127.0.0.1" || bind === "[::1]" || bind === "localhost";
}

function isWildcard(bind) {
    return bind === "0.0.0.0" || bind === "[::]" || bind === "::" || bind === "";
}

/*
 * Turn a container's published ports into clickable targets.
 *
 * A port bound to 0.0.0.0/[::] is reachable on every interface, so we offer
 * the configured LAN and Tailscale addresses rather than the useless 0.0.0.0.
 * A port bound to loopback is only reachable from this machine, so offering the
 * LAN address there would hand the user a link that cannot work.
 */
function buildLinks(portsStr, opts) {
    opts = opts || {};
    var lanHost = opts.lanHost || "";
    var tailscaleHost = opts.tailscaleHost || "";
    var allowLan = opts.allowLan !== false;
    var allowTailscale = opts.allowTailscale !== false;
    var schemeForPort = opts.httpsPorts || [443, 8443, 9443];

    var ports = parsePorts(portsStr);
    var seen = {};
    var links = [];
    for (var i = 0; i < ports.length; i++) {
        var p = ports[i];
        var entries = [];
        if (isLoopback(p.bind)) {
            entries.push({ label: "localhost", host: "localhost" });
        } else if (isWildcard(p.bind)) {
            if (allowLan && lanHost) entries.push({ label: "LAN", host: lanHost });
            if (allowTailscale && tailscaleHost) entries.push({ label: "Tailscale", host: tailscaleHost });
        } else {
            entries.push({ label: p.bind, host: p.bind });
        }
        for (var j = 0; j < entries.length; j++) {
            var e = entries[j];
            var key = e.host + ":" + p.hostPort + "/" + p.proto;
            if (seen[key]) continue;
            seen[key] = true;
            links.push({
                "label": e.label,
                "host": e.host,
                "port": p.hostPort,
                "proto": p.proto,
                "scheme": schemeForPort.indexOf(p.hostPort) >= 0 ? "https" : "http"
            });
        }
    }
    return links;
}

function linkUrl(link) {
    return link.scheme + "://" + link.host + ":" + link.port + "/";
}

/* ------------------------------------------------------------------ misc --- */

/* Containers that are neither running nor cleanly stopped. */
function isTransitional(state) {
    return state === "restarting" || state === "removing"
        || state === "pausing" || state === "unpausing" || state === "dead";
}

function canStart(state) {
    return state === "exited" || state === "created" || state === "dead";
}

function canStop(state) {
    return state === "running" || state === "paused";
}

function canPause(state) {
    return state === "running";
}

function canUnpause(state) {
    return state === "paused";
}

/* Strip the leading "./" or trailing path bits Docker puts in config_files. */
function firstFile(paths) {
    if (!paths) return "";
    var list = String(paths).split(",");
    for (var i = 0; i < list.length; i++) {
        var p = list[i].trim();
        if (p !== "") return p;
    }
    return "";
}

/* Shorten a full 64 char id for display, keeping the docker convention. */
function shortId(id) {
    if (!id) return "";
    return String(id).slice(0, 12);
}
