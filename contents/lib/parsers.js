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
    var parsed = parseFloat(value);
    return isNaN(parsed) ? null : parsed;
}

/*
 * Docker prints one JSON object per line; Podman prints a single JSON array.
 * Both come out as a plain array of objects, and a garbled line is skipped
 * rather than allowed to kill the whole refresh.
 */
function jsonRecords(stdout) {
    var text = String(stdout || "").trim();
    if (text === "") return [];
    if (text.charAt(0) === "[") {
        try {
            var arr = JSON.parse(text);
            return Array.isArray(arr) ? arr : [];
        } catch (e) {
            return [];
        }
    }
    var out = [];
    var lines = text.split("\n");
    for (var i = 0; i < lines.length; i++) {
        var line = lines[i].trim();
        if (line === "") continue;
        try {
            out.push(JSON.parse(line));
        } catch (e) {
            continue;
        }
    }
    return out;
}

/* A successful empty response is a real empty list; malformed output is not. */
function isValidRecords(stdout) {
    var text = String(stdout || "").trim();
    if (text === "") return true;
    try {
        if (text.charAt(0) === "[") return Array.isArray(JSON.parse(text));
        return text.split("\n").every(function (line) {
            if (line.trim() === "") return true;
            var row = JSON.parse(line);
            return row !== null && typeof row === "object" && !Array.isArray(row);
        });
    } catch (e) { return false; }
}

/* Podman reports ports as objects; flatten them to Docker's "ip:host->ctr/proto". */
function portsToString(ports) {
    if (!ports) return "";
    if (!Array.isArray(ports)) return String(ports);
    return ports.map(function (p) {
        if (typeof p === "string") return p;
        var host = p.host_ip !== undefined ? p.host_ip : (p.HostIP || "");
        var hostPort = p.host_port !== undefined ? p.host_port : p.HostPort;
        var ctrPort = p.container_port !== undefined ? p.container_port : p.ContainerPort;
        var proto = p.protocol || p.Protocol || "tcp";
        if (!hostPort) return ctrPort + "/" + proto;
        return (host || "0.0.0.0") + ":" + hostPort + "->" + ctrPort + "/" + proto;
    }).join(", ");
}

/* docker ps --format json -> normalized container records */
function parseContainers(stdout) {
    return jsonRecords(stdout).map(normalizeContainer);
}

function normalizeContainer(d) {
    var labels = labelMap(d.Labels);
    var state = d.State || "unknown";
    return {
        "id": d.ID || d.Id || "",
        "name": firstName(d.Names) || d.ID || d.Id || "unknown",
        "image": d.Image || "",
        "command": Array.isArray(d.Command) ? d.Command.join(" ") : (d.Command || ""),
        "createdAt": d.CreatedAt || d.CreatedAtHuman || "",
        "runningFor": d.RunningFor || "",
        "state": state,
        "status": d.Status || "",
        "health": d.HealthStatus || (/\((healthy|unhealthy|health: starting)\)/.exec(d.Status || "") || ["", "none"])[1].replace("health: ", ""),
        "isRunning": state === "running",
        "localVolumes": d.LocalVolumes === undefined ? "" : String(d.LocalVolumes),
        "networks": Array.isArray(d.Networks) ? d.Networks.join(", ") : (d.Networks || ""),
        "mounts": Array.isArray(d.Mounts) ? d.Mounts.join(", ") : (d.Mounts || ""),
        "ports": portsToString(d.Ports),
        "size": d.Size || "",
        "platform": d.Platform ? (d.Platform.os + "/" + d.Platform.architecture) : "",
        "project": labels["com.docker.compose.project"] || "",
        "service": labels["com.docker.compose.service"] || "",
        "composeFiles": labels["com.docker.compose.project.config_files"] || "",
        "composeWorkDir": labels["com.docker.compose.project.working_dir"] || "",
        "composeProfile": labels["com.docker.compose.profile"] || "",
        // Optional web address to probe, set with the label dockmoid.probe.
        "probeUrl": labels["dockmoid.probe"] || "",
        "restartPolicy": "",
        "probe": "",
        "probeMs": 0,
        "updateAvailable": false,
        "pinned": false,
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
    var rows = jsonRecords(stdout);
    for (var i = 0; i < rows.length; i++) {
        var d = rows[i];
        var rec = {
            "cpu": d.CPUPerc || d.cpu_percent || "",
            "mem": d.MemPerc || d.mem_percent || "",
            "memU": d.MemUsage || d.mem_usage || "",
            "netio": d.NetIO || d.netio || d.net_io || "",
            "blockio": d.BlockIO || d.blockio || d.blocki || d.block_io || "",
            "pids": d.PIDs || d.PIDS || d.pids || "",
            "cpuPct": percent(d.CPUPerc || d.cpu_percent),
            "memPct": percent(d.MemPerc || d.mem_percent)
        };
        if (d.ID) map[d.ID] = rec;
        if (d.Id) map[shortId(d.Id)] = rec;
        if (d.id) map[d.id] = rec;
        if (d.Container) map[d.Container] = rec;
    }
    return map;
}

function applyStats(containers, stats) {
    for (var i = 0; i < containers.length; i++) {
        var c = containers[i];
        var s = stats[c.id] || stats[shortId(c.id)];
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
    return jsonRecords(stdout).map(function (d) {
        return {
            "type": d.Type || "",
            "total": num(d.TotalCount),
            "active": num(d.Active),
            "size": d.Size || "",
            "reclaimable": d.Reclaimable || ""
        };
    });
}

/* "1.2GB", "512.3MB", "4.1kB", "0B" (decimal, as `docker system df` prints) -> bytes; NaN when unknown. */
function sizeBytes(text) {
    var m = /^([0-9.]+)\s*([kKMGT]?i?)B$/.exec(String(text || "").trim());
    if (!m) return NaN;
    var unit = m[2].replace("i", "").toUpperCase();
    var power = {"": 0, K: 1, M: 2, G: 3, T: 4}[unit];
    return Number(m[1]) * Math.pow(m[2].indexOf("i") >= 0 ? 1024 : 1000, power);
}
/* Total size of every `system df` row, in bytes; NaN if any row is unreadable. */
function diskTotal(rows) {
    return (rows || []).reduce(function (sum, r) { return sum + sizeBytes(r.size); }, 0);
}
function formatBytes(n) {
    if (!(n >= 0)) return "";
    var units = ["B", "kB", "MB", "GB", "TB"], i = 0;
    while (n >= 1000 && i < units.length - 1) { n /= 1000; i++; }
    return (i === 0 ? String(Math.round(n)) : n.toFixed(n < 10 ? 2 : 1)) + units[i];
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
        // A stopped container keeps the health it had when it died; counting
        // that would leave "unhealthy" lit for things nobody is running.
        if (c.isRunning && c.health === "unhealthy") unhealthy++;
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

    // UDP ports (discovery, DNS, game traffic) cannot be opened in a browser.
    var ports = parsePorts(portsStr).filter(function (p) { return p.proto === "tcp"; });
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
            var key = e.host + ":" + p.hostPort;
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
    return state === "not-created" || state === "exited" || state === "created" || state === "dead";
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


/* ----------------------------------------------------------- hardening --- */

/* Escape user text so it can be dropped into a RegExp as a literal. */
function escapeRegExp(text) {
    return String(text).replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

/* Compose project names are lowercase alphanumerics, '-' and '_' (dots are
   tolerated for podman). Anything else is refused before it reaches a shell. */
function isSafeToken(value) {
    return /^[A-Za-z0-9][A-Za-z0-9_.-]*$/.test(String(value || ""));
}

/* ---------------------------------------------------------- restart policy -- */

var RESTART_POLICIES = ["no", "on-failure", "unless-stopped", "always"];

/*
 * Output of
 *   docker inspect --format '{{.Id}} {{.HostConfig.RestartPolicy.Name}} {{.HostConfig.RestartPolicy.MaximumRetryCount}}'
 * -> { <12 char id>: "unless-stopped" }. An empty policy name means "no".
 */
function parseRestartPolicies(stdout) {
    var map = {};
    if (!stdout) return map;
    var lines = String(stdout).split("\n");
    for (var i = 0; i < lines.length; i++) {
        var f = lines[i].trim().split(/\s+/);
        if (f.length < 1 || f[0] === "") continue;
        // An empty policy name collapses in the split, leaving the retry count
        // (a number) in its place.
        var policy = f.length > 1 && /^[a-z-]+$/.test(f[1]) ? f[1] : "no";
        map[shortId(f[0])] = policy;
    }
    return map;
}

function applyRestartPolicies(containers, policies) {
    for (var i = 0; i < containers.length; i++) {
        containers[i].restartPolicy = policies[shortId(containers[i].id)] || "";
    }
    return containers;
}

/*
 * The same inspect output can carry the container's times after the policy:
 *   ... {{.State.StartedAt}} {{.State.FinishedAt}} {{.Created}}
 * -> { <12 char id>: {startedAt, finishedAt, created} } in epoch ms, 0 when
 * Docker reports its zero time (never started / never stopped). Lines from an
 * older, policy-only command simply carry no times.
 */
function parseLifeTimes(stdout) {
    var map = {};
    var lines = String(stdout || "").split("\n");
    for (var i = 0; i < lines.length; i++) {
        var f = lines[i].trim().split(/\s+/);
        if (f.length < 1 || f[0] === "") continue;
        var stamps = f.slice(1).filter(function (t) { return /^\d{4}-\d\d-\d\dT/.test(t); }).map(function (t) {
            var ms = Date.parse(t.replace(/(\.\d{3})\d+/, "$1"));
            return isNaN(ms) || ms < Date.UTC(1971, 0, 1) ? 0 : ms;
        });
        if (stamps.length === 3) map[shortId(f[0])] = {startedAt: stamps[0], finishedAt: stamps[1], created: stamps[2]};
    }
    return map;
}

function applyLifeTimes(containers, times) {
    for (var i = 0; i < containers.length; i++) {
        var t = times[shortId(containers[i].id)];
        containers[i].startedAtMs = t ? t.startedAt : 0;
        containers[i].finishedAtMs = t ? t.finishedAt : 0;
        containers[i].createdMs = t ? t.created : 0;
    }
    return containers;
}

/*
 * `docker diff` output (A/C/D path lines) -> {total, added, changed, deleted,
 * sample}: what a recreate would throw away from the container's own
 * filesystem. Paths only; it says nothing about whether they matter.
 */
function summarizeDiff(text) {
    var out = {total: 0, added: 0, changed: 0, deleted: 0, sample: []};
    String(text || "").split("\n").forEach(function (line) {
        var m = /^([ACD])\s+(\/.*)$/.exec(line.trim());
        if (!m) return;
        out.total++;
        if (m[1] === "A") out.added++; else if (m[1] === "C") out.changed++; else out.deleted++;
        if (out.sample.length < 6) out.sample.push(m[2]);
    });
    return out;
}

/*
 * Make text safe to paste into a public bug report: the home folder becomes ~,
 * the user name <user>, host names in ssh:// or tcp:// endpoints <host>, and
 * IPv4 addresses other than loopback <ip>. A best effort, so the report is
 * shown for review before anyone copies it.
 */
function redact(text, home, user) {
    var out = String(text || "");
    if (home && home.length > 1) out = out.split(home).join("~");
    out = out.replace(/((?:ssh|tcp|https?):\/\/)(?:[^@\s\/]+@)?[^:\/\s]+/g, "$1<host>");
    out = out.replace(/\b(?!127\.)(\d{1,3}\.){3}\d{1,3}\b/g, "<ip>");
    if (user && user.length > 1) out = out.replace(new RegExp("\\b" + user.replace(/[.*+?^${}()|[\]\\]/g, "\\$&") + "\\b", "g"), "<user>");
    return out;
}

/*
 * Two lines of
 *   {{json .Name}} TAB {{json .NetworkSettings.Networks}} TAB {{json .NetworkSettings.Ports}}
 * -> what the two containers share: networks (with each side's address and
 * the names the other can use), networks only one has, and published ports.
 * Configuration only: a shared network does not prove a connection works.
 */
function parseNetworkSide(line) {
    var parts = String(line || "").split("\t");
    if (parts.length < 3) return null;
    try {
        var name = String(JSON.parse(parts[0]) || "").replace(/^\//, "");
        var nets = JSON.parse(parts[1]) || {};
        var ports = JSON.parse(parts[2]) || {};
        var networks = {};
        Object.keys(nets).forEach(function (n) {
            var v = nets[n] || {};
            var names = [].concat(v.DNSNames || [], v.Aliases || []).filter(function (x, i, all) { return x && all.indexOf(x) === i && !/^[0-9a-f]{12}$/.test(x); });
            networks[n] = {ip: v.IPAddress || "", names: names};
        });
        var published = [];
        Object.keys(ports).forEach(function (p) {
            (ports[p] || []).forEach(function (b) { published.push({container: p, hostIp: b.HostIp || "", hostPort: b.HostPort || ""}); });
        });
        return {name: name, networks: networks, published: published};
    } catch (e) { return null; }
}
function compareNetworks(text) {
    var lines = String(text || "").split("\n").filter(function (l) { return l.trim() !== ""; });
    var a = parseNetworkSide(lines[0]), b = parseNetworkSide(lines[1]);
    if (!a || !b) return null;
    var an = Object.keys(a.networks), bn = Object.keys(b.networks);
    return {
        a: a, b: b,
        shared: an.filter(function (n) { return bn.indexOf(n) >= 0 && n !== "host" && n !== "none"; }),
        onlyA: an.filter(function (n) { return bn.indexOf(n) < 0; }),
        onlyB: bn.filter(function (n) { return an.indexOf(n) < 0; }),
        hostNetwork: an.indexOf("host") >= 0 || bn.indexOf("host") >= 0
    };
}

/* True when Docker itself will bring the container back after a reboot. */
function startsAutomatically(policy) {
    return policy === "always" || policy === "unless-stopped";
}

/* -------------------------------------------------------- state changes ---- */

/* "Exited (137) 3 minutes ago" -> 137. null when there is no exit code. */
function exitCodeFromStatus(status) {
    var m = /Exited \((-?\d+)\)/.exec(String(status || ""));
    return m ? parseInt(m[1], 10) : null;
}

/* Exit codes a clean `docker stop`, ^C or SIGTERM produce. They are not crashes. */
function isDeliberateExit(code) {
    return code === 0 || code === 130 || code === 137 || code === 143;
}

/* Reduce container records to what diffStates() needs. */
function snapshotStates(containers) {
    var snap = {};
    for (var i = 0; i < containers.length; i++) {
        var c = containers[i];
        snap[c.id] = {
            "name": c.name,
            "state": c.state,
            "health": c.health,
            "exitCode": exitCodeFromStatus(c.status)
        };
    }
    return snap;
}

/*
 * Compare two snapshots and describe what happened in between.
 *
 * kinds: crashed | restarting | unhealthy | recovered | started | stopped
 * A container that did not exist in `prev` produces no event, and neither does
 * the very first poll (prev === null), so launching the widget is silent.
 */
function diffStates(prev, next) {
    var events = [];
    if (!prev) return events;
    for (var id in next) {
        var a = prev[id];
        var b = next[id];
        if (!a) continue;
        var wasUp = a.state === "running" || a.state === "restarting";
        if (b.state === "restarting" && a.state !== "restarting") {
            events.push({ "kind": "restarting", "id": id, "name": b.name });
        } else if (wasUp && (b.state === "exited" || b.state === "dead")) {
            if (b.exitCode !== null && !isDeliberateExit(b.exitCode)) {
                events.push({ "kind": "crashed", "id": id, "name": b.name, "code": b.exitCode });
            } else {
                events.push({ "kind": "stopped", "id": id, "name": b.name });
            }
        } else if (a.state !== "running" && b.state === "running") {
            events.push({ "kind": "started", "id": id, "name": b.name });
        }
        if (b.state === "running" && b.health === "unhealthy" && a.health !== "unhealthy") {
            events.push({ "kind": "unhealthy", "id": id, "name": b.name });
        } else if (a.health === "unhealthy" && b.health === "healthy") {
            events.push({ "kind": "recovered", "id": id, "name": b.name });
        }
    }
    return events;
}

/* ------------------------------------------------------------- launchers --- */

/*
 * One launcher per line:  Label | icon | scope | command
 *   scope "container": needs a running container; {id} and {shell} are filled in
 *   scope "project":   needs a compose working directory; {dir} is filled in
 * {dir} is shell-quoted by the caller; {id} and {shell} are always safe tokens.
 * Lines starting with # and blank lines are ignored.
 */
function parseLaunchers(text) {
    var out = [];
    var lines = String(text || "").split("\n");
    for (var i = 0; i < lines.length; i++) {
        var line = lines[i].trim();
        if (line === "" || line.charAt(0) === "#") continue;
        var f = line.split("|");
        if (f.length < 4) continue;
        var scope = f[2].trim().toLowerCase();
        if (scope !== "container" && scope !== "project") continue;
        var command = f.slice(3).join("|").trim();
        if (command === "") continue;
        out.push({
            "label": f[0].trim(),
            "icon": f[1].trim(),
            "scope": scope,
            "command": command,
            "binary": command.split(/\s+/)[0]
        });
    }
    return out;
}


/* ============================================================ resources ==== */

/* docker images --format json -> images with how many containers use each. */
function parseImages(stdout) {
    return jsonRecords(stdout).map(function (d) {
        var repo = d.Repository || d.repository || "";
        var tag = d.Tag || d.tag || "";
        var names = d.Names || d.names || [];
        var name = Array.isArray(names) ? (names[0] || "") : String(names || "");
        var dangling = repo === "<none>" || repo === ""
            ? (name === "" || /^<\s*none\s*>$/i.test(name))
            : false;
        var id = d.ID || d.Id || d.id || "";
        var created = d.CreatedSince || d.CreatedAt || d.created || "";
        var size = d.Size !== undefined ? d.Size : d.size;
        var containers = d.Containers !== undefined ? d.Containers : d.containers;
        var ref = repo && repo !== "<none>"
            ? (tag && tag !== "<none>" ? repo + ":" + tag : repo)
            : name;
        return {
            "id": id,
            "repository": repo,
            "tag": tag,
            "ref": dangling ? "" : ref,
            "size": size === undefined || size === null ? "" : String(size),
            "created": created,
            "containers": containers === undefined || containers === null || isNaN(parseInt(containers, 10))
                ? -1 : parseInt(containers, 10),
            "dangling": dangling
        };
    });
}

/* docker system df -v --format json -> volumes with size and how many containers mount each. */
function parseVolumes(stdout) {
    var rows = jsonRecords(stdout);
    var list = [];
    for (var i = 0; i < rows.length; i++) {
        var direct = rows[i];
        if (direct.Name !== undefined || direct.name !== undefined) {
            var directLabels = labelMap(direct.Labels || direct.labels);
            var directLinks = direct.Links !== undefined ? parseInt(direct.Links, 10)
                : (direct.links !== undefined ? parseInt(direct.links, 10) : -1);
            list.push({
                "name": direct.Name || direct.name || "",
                "driver": direct.Driver || direct.driver || "",
                "size": direct.Size || direct.size || "",
                // MountCount is the number of mount operations, not a reliable
                // count of containers referencing a volume. Keep usage unknown.
                "links": isNaN(directLinks) ? -1 : directLinks,
                "project": directLabels["com.docker.compose.project"]
                    || directLabels["io.podman.compose.project"] || ""
            });
            continue;
        }
        var vols = rows[i].Volumes;
        if (!Array.isArray(vols)) continue;
        for (var j = 0; j < vols.length; j++) {
            var v = vols[j];
            var links = parseInt(v.Links, 10);
            list.push({
                "name": v.Name || "",
                "driver": v.Driver || "",
                "size": v.Size && v.Size !== "N/A" ? v.Size : "",
                "links": isNaN(links) ? -1 : links,
                "project": labelMap(v.Labels)["com.docker.compose.project"] || ""
            });
        }
    }
    return list;
}

function parseNetworks(stdout) {
    return jsonRecords(stdout).map(function (d) {
        var name = d.Name || d.name || "";
        var labels = labelMap(d.Labels || d.labels);
        return {
            "id": d.ID || d.Id || d.id || "",
            "name": name,
            "driver": d.Driver || d.driver || "",
            "scope": d.Scope || d.scope || "",
            "builtin": name === "bridge" || name === "host" || name === "none" || name === "podman",
            "project": labels["com.docker.compose.project"] || labels["io.podman.compose.project"] || ""
        };
    });
}

/* ========================================================= image updates === */

/*
 * The update-check command prints "<local repo digests>|<remote digest>". An
 * image is current when the remote digest is one of the local ones; if either
 * side is missing nothing can be said, and "unknown" is the honest answer.
 */
function compareDigests(output) {
    var line = String(output || "").trim().split("\n").pop();
    var cut = line.lastIndexOf("|");
    if (cut < 0) return "unknown";
    var local = line.slice(0, cut).trim();
    var remote = line.slice(cut + 1).trim();
    if (!/^sha256:[0-9a-f]{64}$/.test(remote) || local === "") return "unknown";
    return local.indexOf(remote) >= 0 ? "current" : "update";
}

/* A reference worth asking a registry about: not an id, not a local build. */
function isCheckableImage(ref) {
    var s = String(ref || "");
    if (s === "" || /^[0-9a-f]{12,64}$/.test(s) || s.indexOf("sha256:") === 0) return false;
    return true;
}

/* ============================================================== alerts ===== */

/*
 * Sustained resource use. `state` is { <id>: { since, alerted } } and is carried
 * between samples by the caller. A container must stay above the threshold for
 * `seconds` before it counts, so a brief spike never notifies, and it notifies
 * once per episode.
 */
function trackThresholds(state, containers, nowMs, opts) {
    var events = [];
    var seen = {};
    for (var i = 0; i < containers.length; i++) {
        var c = containers[i];
        if (!c.isRunning) continue;
        seen[c.id] = true;
        var over = (opts.cpu > 0 && c.cpuPct >= opts.cpu) ? "cpu"
                 : (opts.mem > 0 && c.memPct >= opts.mem) ? "memory" : "";
        var st = state[c.id];
        if (over === "") {
            if (st) delete state[c.id];
            continue;
        }
        if (!st || st.what !== over) {
            state[c.id] = { "since": nowMs, "what": over, "alerted": false };
            continue;
        }
        if (!st.alerted && nowMs - st.since >= opts.seconds * 1000) {
            st.alerted = true;
            events.push({
                "kind": "resource", "id": c.id, "name": c.name, "what": over,
                "value": over === "cpu" ? c.cpuPct : c.memPct
            });
        }
    }
    for (var id in state) if (!seen[id]) delete state[id];
    return events;
}

/* ============================================================== probes ===== */

/*
 * "name=url" lines, where name is matched against the container name. A
 * container's own dockmoid.probe label wins over a line in the settings.
 */
function parseProbeRules(text) {
    var out = [];
    String(text || "").split("\n").forEach(function (line) {
        line = line.trim();
        if (line === "" || line.charAt(0) === "#") return;
        var at = line.indexOf("=");
        if (at <= 0) return;
        var url = line.slice(at + 1).trim();
        if (/^https?:\/\/[^\s'"`$\\]+$/.test(url)) out.push({ "name": line.slice(0, at).trim().toLowerCase(), "url": url });
    });
    return out;
}

function probeUrlFor(rec, rules) {
    var label = String(rec.probeUrl || "");
    if (/^https?:\/\/[^\s'"`$\\]+$/.test(label)) return label;
    for (var i = 0; i < rules.length; i++) {
        if (rules[i].name === String(rec.name).toLowerCase()) return rules[i].url;
    }
    return "";
}

/* "<url> <http code> <milliseconds>" per line -> { url: {up, code, ms} } */
function parseProbeResults(stdout) {
    var map = {};
    String(stdout || "").split("\n").forEach(function (line) {
        var f = line.trim().split(/\s+/);
        if (f.length < 3) return;
        var code = parseInt(f[1], 10);
        map[f[0]] = { "up": code >= 200 && code < 500, "code": code, "ms": Math.round((parseFloat(f[2]) || 0) * 1000) };
    });
    return map;
}

/* ============================================================ compose ====== */

/* "-f 'a.yml' -f 'b.yml'" from the comma separated config_files label. */
function composeFileArgs(configFiles, quote) {
    return String(configFiles || "").split(",").map(function (f) { return f.trim(); })
        .filter(function (f) { return f !== ""; })
        .map(function (f) { return "-f " + quote(f); }).join(" ");
}

/* ============================================================== history ==== */

/* Append to a fixed-length ring of samples. */
function pushSample(list, value, max) {
    var out = (list || []).concat([value]);
    return out.length > max ? out.slice(out.length - max) : out;
}


/* The detail page's extra facts from `inspect --format` (see fetchFacts). */
function parseFacts(text) {
    var d = JSON.parse(String(text || "").trim() || "{}");
    function when(value) {
        var t = Date.parse(value || "");
        return isNaN(t) || t <= 0 || /^0001-/.test(String(value)) ? 0 : t;
    }
    var networks = [];
    var nets = d.networks || {};
    Object.keys(nets).sort().forEach(function (name) {
        var n = nets[name] || {};
        if (n.IPAddress || n.GlobalIPv6Address) networks.push({ name: name, ip: n.IPAddress || "", ipv6: n.GlobalIPv6Address || "" });
    });
    var hc = d.healthcheck || null;
    var test = hc && Array.isArray(hc.Test) ? hc.Test : [];
    var check = "";
    if (test.length && test[0] !== "NONE") check = (test[0] === "CMD-SHELL" || test[0] === "CMD" ? test.slice(1) : test).join(" ");
    var seconds = function (ns) { return ns ? Math.round(Number(ns) / 1e9) : 0; };
    return {
        restarts: Number(d.restarts) || 0,
        startedAt: when(d.started),
        finishedAt: when(d.finished),
        exitCode: d.exitCode === undefined || d.exitCode === null ? -1 : Number(d.exitCode),
        error: String(d.error || ""),
        oomKilled: d.oom === true,
        memoryLimit: Number(d.memory) || 0,
        cpuLimit: d.nanoCpus ? Number(d.nanoCpus) / 1e9 : 0,
        networks: networks,
        healthCheck: check,
        healthInterval: hc ? seconds(hc.Interval) : 0,
        user: String(d.user || ""),
        workdir: String(d.workdir || ""),
        // The engine's health record: status, failing streak and the last probe.
        health: (function (h) {
            if (!h || typeof h !== "object") return null;
            var log = Array.isArray(h.Log) ? h.Log : [];
            var last = log.length ? log[log.length - 1] : null;
            return {
                status: String(h.Status || ""),
                failingStreak: Number(h.FailingStreak) || 0,
                lastExit: last ? Number(last.ExitCode) : -1,
                lastAt: last ? when(last.End) : 0,
                lastOutput: last ? String(last.Output || "").trim().slice(-400) : ""
            };
        })(d.health)
    };
}
