.pragma library

/*
 * compose.js — the Compose command lines, written once.
 *
 * Immediate actions (DockerBackend.composeRun) and Doctor's reviewed plans
 * both build their commands here, so a service-scoped action never touches
 * its dependencies (--no-deps) and a stopped service stays stopped
 * (--no-start) whichever path ran it.
 *
 *   ctx.compose  the expanded compose command ("docker compose")
 *   ctx.quote    shell quoting
 *   ctx.tail     log lines for "logs" verbs
 *   ctx.dryRun   the installed Compose accepts --dry-run
 *
 * Returns "" for a verb that does not apply (unsafe names, no service, or a
 * preview without dry-run support).
 */

function safe(token) { return /^[A-Za-z0-9][A-Za-z0-9_.-]*$/.test(String(token || "")); }

function fileArgs(files, quote) {
    return String(files || "").split(",").map(function (f) { return f.trim(); })
        .filter(function (f) { return f !== ""; })
        .map(function (f) { return "-f " + quote(f); }).join(" ");
}

function recipe(verb, rec, ctx) {
    if (!rec || !safe(rec.project)) return "";
    var files = fileArgs(rec.composeFiles, ctx.quote);
    var base = ctx.compose + " -p " + rec.project + " " + files;
    var dry = ctx.compose + " --dry-run -p " + rec.project + " " + files;
    var svc = safe(rec.service) ? rec.service : "";
    var tail = Math.max(1, Math.min(10000, Number(ctx.tail) || 200));
    var steps = {
        up: base + " up -d", down: base + " down", pull: base + " pull", stop: base + " stop",
        restart: base + " restart", ps: base + " ps -a", start: base + " start",
        pause: base + " pause", unpause: base + " unpause", images: base + " images", top: base + " top",
        logs: base + " logs --no-color --tail " + tail,
        recreate: base + " up -d --force-recreate",
        update: base + " pull && " + base + " up -d",
        // Validates without printing the resolved file, which can hold secrets.
        config: base + " config --quiet",
        // Apply: Compose recreates only what changed in the files or image.
        apply: base + " up -d",
        preview: ctx.dryRun ? dry + " up -d" : ""
    };
    if (svc) {
        steps["create-service"] = base + " up -d --no-deps " + svc;
        steps["service-restart"] = base + " restart " + svc;
        steps["service-recreate"] = base + " up -d --no-deps --force-recreate " + svc;
        steps["service-pull"] = base + " pull " + svc;
        steps["service-logs"] = base + " logs --no-color --tail " + tail + " " + svc;
        steps["update-service-running"] = base + " pull " + svc + " && " + base + " up -d --no-deps --force-recreate " + svc;
        steps["update-service-stopped"] = base + " pull " + svc + " && " + base + " up --no-start --no-deps --force-recreate " + svc;
        steps["service-apply-running"] = base + " up -d --no-deps " + svc;
        steps["service-apply-stopped"] = base + " up --no-start --no-deps " + svc;
        steps["service-preview"] = ctx.dryRun ? dry + " up -d --no-deps " + svc : "";
    }
    return steps[verb] || "";
}

/* Run `command` from the project folder, after checking every file is readable
   (Doctor's plans run later than they were reviewed). */
function guarded(command, rec, quote) {
    if (!command) return "";
    var checks = String(rec.composeFiles || "").split(",").map(function (f) { return f.trim(); })
        .filter(function (f) { return f !== ""; }).map(function (f) { return "test -r " + quote(f); });
    return (checks.length ? checks.join(" && ") + " && " : "")
        + (rec.composeWorkDir ? "cd " + quote(rec.composeWorkDir) + " && " : "") + command;
}
