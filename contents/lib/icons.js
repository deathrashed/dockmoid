/*
 * icons.js — image-substring -> bundled glyph mapping.
 *
 * Matching is done on the *lowercased image name*, so "lscr.io/linuxserver/
 * syncthing:latest" matches the "syncthing" entry. The first match in the list
 * wins, which means more specific keys must come before generic ones (that is
 * why "portainer" is listed before the trailing catch-alls).
 *
 * The user can extend or override this list from the Services config page
 * without touching code, so anything not shipped here can still get a glyph.
 */

function defaults() {
    return [
        // --- container / management platforms -----------------------------
        ["portainer", "portainer"],
        ["dockge", "dockge"],
        ["dokploy", "dokploy"],
        ["watchtower", "watchtower"],

        // --- media --------------------------------------------------------
        ["jellyfin", "jellyfin"],
        ["plex", "plex"],
        ["emby", "emby"],
        ["navidrome", "navidrome"],
        ["airsonic", "airsonic"],
        ["tautulli", "tautulli"],
        ["kodi", "kodi"],
        ["calibre", "calibre"],

        // --- *arr stack ----------------------------------------------------
        ["sonarr", "sonarr"],
        ["radarr", "radarr"],
        ["lidarr", "lidarr"],
        ["readarr", "readarr"],
        ["bazarr", "bazarr"],
        ["prowlarr", "prowlarr"],

        // --- downloads / usenet / torrents ----------------------------------
        ["sabnzbd", "sabnzbd"],
        ["nzbget", "nzbget"],
        ["qbittorrent", "qbittorrent"],
        ["transmission", "transmission"],
        ["deluge", "deluge"],
        ["rtorrent", "rtorrent"],
        ["slskd", "slskd"],
        ["soulseek", "slskd"],
        ["saberren", "saberren"],
        ["cross-seed", "cross-seed"],

        // --- files / sync ----------------------------------------------------
        ["syncthing", "syncthing"],
        ["nextcloud", "nextcloud"],
        ["owncloud", "owncloud"],
        ["filebrowser", "filebrowser"],
        ["rclone", "rclone"],
        ["immich", "immich"],
        ["photoprism", "photoprism"],
        ["paperless", "paperless"],
        ["paperless-ngx", "paperless"],

        // --- databases / caches -----------------------------------------------
        ["postgres", "postgres"],
        ["postgresql", "postgres"],
        ["mariadb", "mariadb"],
        ["mysql", "mariadb"],
        ["mongo", "mongo"],
        ["redis", "redis"],
        ["valkey", "redis"],
        ["influxdb", "influxdb"],
        ["meilisearch", "meilisearch"],
        ["qdrant", "qdrant"],

        // --- monitoring / networking -------------------------------------------
        ["grafana", "grafana"],
        ["prometheus", "prometheus"],
        ["dozzle", "dozzle"],
        ["pihole", "pihole"],
        ["pi-hole", "pihole"],
        ["adguard", "pihole"],
        ["traefik", "traefik"],
        ["nginx-proxy", "nginx"],
        ["nginx", "nginx"],
        ["caddy", "caddy"],
        ["cloudflare", "cloudflare"],
        ["wireguard", "wireguard"],
        ["tailscale", "tailscale"],
        ["wireguardwg", "wireguard"],
        ["homeassistant", "homeassistant"],
        ["home-assistant", "homeassistant"],
        ["mosquitto", "mosquitto"],
        ["nodered", "nodered"],
        ["esphome", "esphome"],

        // --- generic fallbacks ------------------------------------------------
        ["proxy", "traefik"],
        ["minecraft", "minecraft"],

        // --- the daemon itself (must stay last) -------------------------------
        ["docker", "docker"]
    ];
}

/*
 * Parse the user supplied override list. One "substring=icon" pair per line.
 * Blank lines and lines starting with # are ignored. A bare "substring" (no
 * =) removes that substring from the mapping.
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
 * Build the effective mapping. Overrides are prepended so they win over the
 * bundled defaults; a null icon in an override masks that substring.
 */
function build(overrideText) {
    var list = parseOverrides(overrideText);
    var merged = [];
    for (var i = 0; i < list.length; i++) merged.push(list[i]);
    var defs = defaults();
    for (var j = 0; j < defs.length; j++) merged.push(defs[j]);
    return merged;
}

/* Return the glyph name for an image, or "" when nothing matches. */
function match(map, image) {
    if (!image || !map) return "";
    var lower = String(image).toLowerCase();
    for (var i = 0; i < map.length; i++) {
        if (lower.indexOf(map[i][0]) === -1) continue;
        // A null icon in an override masks the substring: it wins the match
        // and suppresses every bundled rule below it.
        return map[i][1] === null ? "" : map[i][1];
    }
    return "";
}
