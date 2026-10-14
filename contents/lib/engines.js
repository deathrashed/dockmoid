/*
 * Engine compatibility decisions shared by the backend and command presets.
 * Keep this file pure so command selection can be tested without a live engine.
 */

/* Exact current Docker defaults that also work with the Podman CLI. Values are
   kept explicit so user-edited commands never get rewritten heuristically. */
var PODMAN_SHARED_DEFAULTS = {
    "{engine} ps --format json -a": "{engine} ps --format json -a",
    "{engine} ps --no-trunc --format json -a": "{engine} ps --no-trunc --format json -a",
    "{engine} stats --no-stream --format json": "{engine} stats --no-stream --format json",
    "{engine} images --format json": "{engine} images --format json",
    "{engine} volume ls --format json": "{engine} volume ls --format json",
    "{engine} start {id}": "{engine} start {id}",
    "{engine} stop {id}": "{engine} stop {id}",
    "{engine} restart {id}": "{engine} restart {id}",
    "{engine} rm -f {id}": "{engine} rm -f {id}",
    "{engine} pause {id}": "{engine} pause {id}",
    "{engine} unpause {id}": "{engine} unpause {id}",
    "{engine} pull {image}": "{engine} pull {image}",
    "{engine} logs --timestamps --tail {tail} {id}": "{engine} logs --timestamps --tail {tail} {id}",
    "{engine} inspect {id}": "{engine} inspect {id}"
};

/* Podman v5.7.1's event statuses and template field names differ from Docker's. */
var PODMAN_OVERRIDES = {
    "{engine} events --since {since} --until {until} --filter type=container --filter event=create --filter event=start --filter event=die --filter event=stop --filter event=kill --filter event=destroy --filter event=pause --filter event=unpause --filter event=restart --filter event=rename --filter event=update --filter event=oom --filter event=health_status --format '{{.Action}}'":
        "{engine} events --since {since} --until {until} --filter type=container --filter event=create --filter event=start --filter event=died --filter event=stop --filter event=kill --filter event=remove --filter event=pause --filter event=unpause --filter event=restart --filter event=rename --filter event=update --format '{{.Status}}'",
    "{engine} system df -v --format json": "{engine} volume ls --format json",
    "{engine} network ls --format json": "{engine} network ls --no-trunc --format json"
};

/* Return a Podman equivalent only for an exact stock template. Custom command
   overrides pass through byte-for-byte for the user to manage themselves. */
function template(cmd, isPodman) {
    var value = String(cmd || "");
    if (!isPodman) return value;
    if (Object.prototype.hasOwnProperty.call(PODMAN_OVERRIDES, value)) return PODMAN_OVERRIDES[value];
    if (Object.prototype.hasOwnProperty.call(PODMAN_SHARED_DEFAULTS, value)) return PODMAN_SHARED_DEFAULTS[value];
    return value;
}

var DOCKER_FEATURES = [
    "list", "stats", "events", "logs", "inspect", "start", "stop", "restart", "remove", "pause", "unpause", "pull",
    "resources", "compose", "registryChecks", "restartPolicies", "systemDf", "serviceControl", "info", "contexts"
];

/*
 * Podman support is deliberately limited to local/rootless container
 * inventory, status, stats, logs, inspection and direct container controls.
 * Context/connection discovery uses the backend's native Podman path.
 * Read-only image, volume and network inventories are supported. Their
 * reference counts and disk usage are not implied by Podman's listing data.
 * Compose, registry digest checks, restart-policy editing, system-df
 * summaries, service-manager controls and Docker-shaped info summaries remain
 * unavailable until their data/behavior is verified. `resources` means only
 * those read-only inventories; it does not authorize resource removal.
 */
var PODMAN_FEATURES = [
    "list", "stats", "events", "logs", "inspect", "start", "stop", "restart", "remove", "pause", "unpause", "pull",
    "resources", "contexts"
];

function supports(feature, isPodman) {
    var supported = isPodman ? PODMAN_FEATURES : DOCKER_FEATURES;
    return supported.indexOf(String(feature || "")) !== -1;
}
