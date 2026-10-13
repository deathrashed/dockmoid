#!/usr/bin/env python3
"""
Generates the bundled service glyphs for the Docker companion plasmoid.

Every glyph is drawn as a flat monochrome silhouette on a 24x24 grid, because
the plasmoid renders them through Kirigami.Icon with isMask: true. That masks
recolour the image to the current theme colour, so:
  * only the alpha channel matters, and
  * a multi-colour brand logo collapses into a shapeless blob.

So the set is deliberately abstract-geometric rather than a set of traced brand
logos: simple, distinguishable marks that stay legible at 16px and follow the
light/dark theme. Anyone who wants real brand artwork can override any of these
from the Services configuration page.
"""

import pathlib

OUT = pathlib.Path(__file__).resolve().parent
OUT.mkdir(parents=True, exist_ok=True)

HEAD = ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" '
        'width="24" height="24" fill="black">\n')
TAIL = '</svg>\n'


def r(x, y, w, h, rx=0, opacity=None):
    op = ' fill-opacity="%s"' % opacity if opacity is not None else ''
    if rx:
        return ('<rect x="%g" y="%g" width="%g" height="%g" rx="%g"%s/>'
                % (x, y, w, h, rx, op))
    return '<rect x="%g" y="%g" width="%g" height="%g"%s/>' % (x, y, w, h, op)


def c(cx, cy, rad, opacity=None):
    op = ' fill-opacity="%s"' % opacity if opacity is not None else ''
    return '<circle cx="%g" cy="%g" r="%g"%s/>' % (cx, cy, rad, op)


def p(points, opacity=None, rule=None):
    op = ' fill-opacity="%s"' % opacity if opacity is not None else ''
    rf = ' fill-rule="%s"' % rule if rule is not None else ''
    pts = ' '.join('%g,%g' % (x, y) for x, y in points)
    return '<polygon points="%s"%s%s/>' % (pts, rf, op)


def path(d, opacity=None, rule="evenodd"):
    op = ' fill-opacity="%s"' % opacity if opacity is not None else ''
    return '<path d="%s" fill-rule="%s"%s/>' % (d, rule, op)


# A cut-out: drawn as a hole because everything is one opaque silhouette and
# the icons are rendered as a single mask.
def ring(cx, cy, outer, inner):
    return (path('M %g %g m %g 0 a %g %g 0 1 0 %g 0 a %g %g 0 1 0 %g 0 Z '
                 'M %g %g m %g 0 a %g %g 0 1 1 %g 0 a %g %g 0 1 1 %g 0 Z'
                 % (cx - outer, cy, outer, outer, outer, -2 * outer, outer, outer,
                    -2 * outer, cx - inner, cy, inner, inner, inner, 2 * inner,
                    inner, inner, -2 * inner)))


def arc_down(cx, cy, rad, thickness):
    """A half-round cap, used for database cylinders."""
    return path('M %g %g h %g v %g a %g %g 0 0 1 %g 0 Z'
                % (cx - rad, cy, 2 * rad, thickness, rad, rad, -2 * rad))


ICONS = {}


# ------------------------------------------------------------- databases --
ICONS["mariadb"] = [
    r(5, 7, 14, 3, 1.5), r(5, 12, 14, 3, 1.5), arc_down(12, 15, 7, 3),
    r(5, 7, 14, 8, 0, 0.0),
]
ICONS["mongo"] = [
    path('M12 2 C 17 7 19 12 17 16 C 15.5 19.5 8.5 19.5 7 16 C 5 12 7 7 12 2 Z'),
    p([(12, 7), (15, 13), (9, 13)], 0.25),
]
ICONS["redis"] = [
    p([(3, 7), (12, 3), (21, 7), (12, 11)]),
    p([(3, 13), (12, 9), (21, 13), (12, 17)]),
    p([(3, 19), (12, 15), (21, 19), (12, 23)]),
]
ICONS["influxdb"] = [
    path('M12 2 L 20 8 L 20 16 L 12 22 L 4 16 L 4 8 Z', rule="nonzero"),
    c(12, 12, 3, 0.25),
]
ICONS["meilisearch"] = [
    ring(10, 10, 7, 4.5),
    p([(15, 15), (21, 15), (21, 21)], rule="nonzero"),
]
ICONS["qdrant"] = [
    c(12, 5, 3), c(5, 12, 3), c(19, 12, 3), c(9, 19, 3), c(16, 19, 3),
    c(12, 12, 2.5, 0.35),
]

# ------------------------------------------------------------- monitoring -
ICONS["grafana"] = [
    r(2, 3, 20, 18, 3),
    path('M5 17 L 9 11 L 12 14 L 16 7 L 19 10 L 19 18 L 5 18 Z', 0.28),
]
ICONS["prometheus"] = [
    path('M13 2 L 5 13 L 11 13 L 9 22 L 19 10 L 13 10 Z'),
]
ICONS["dozzle"] = [
    r(3, 4, 18, 16, 2),
    r(6, 8, 7, 1.8, 0.9), r(6, 12, 10, 1.8, 0.9), r(6, 16, 5, 1.8, 0.9),
]
ICONS["watchtower"] = [
    path('M9 22 L 10 12 L 14 12 L 15 22 Z'),
    p([(12, 2), (17, 9), (7, 9)]),
    r(9.5, 5.5, 5, 3, 0.5, 0.3),
]

# -------------------------------------------------------------- networking -
ICONS["traefik"] = [
    path('M12 2 L 21 5.5 L 21 12 C 21 17 17 20.5 12 22 C 7 20.5 3 17 3 12 '
         'L 3 5.5 Z'),
    c(12, 10, 2.2, 0.3),
    p([(7, 15), (9, 15), (7.5, 18)]), p([(17, 15), (15, 15), (16.5, 18)]),
]
ICONS["nginx"] = [
    path('M2 20 L 2 5 L 5 5 L 5 20 Z'),
    p([(5, 20), (5, 4), (8, 4), (16, 18), (16, 4), (19, 4), (19, 20), (16, 20)]),
]
ICONS["caddy"] = [
    r(2, 6, 20, 12, 3),
    r(5, 9, 14, 2, 1, 0.3),
    r(5, 13, 9, 2, 1, 0.3),
]
ICONS["cloudflare"] = [
    path('M6 18 A 4 4 0 0 1 6 10 A 5 5 0 0 1 16 9 A 3.5 3.5 0 0 1 19 18 Z'),
    r(3, 18, 18, 2, 1),
]
ICONS["wireguard"] = [
    ring(12, 12, 10, 5),
    c(12, 12, 2.6),
]
ICONS["tailscale"] = [
    c(12, 4, 2.6), c(4, 18, 2.6), c(20, 18, 2.6), c(12, 12, 2.2, 0.4),
    r(11, 5, 2, 6), r(5, 11, 14, 2, 0.6, 0.5),
]
ICONS["mosquitto"] = [
    path('M3 4 L 21 4 L 21 16 L 12 16 L 7 21 L 7 16 L 3 16 Z'),
    c(8, 10, 1.2, 0.3), c(12, 10, 1.2, 0.3), c(16, 10, 1.2, 0.3),
]
ICONS["nodered"] = [
    c(4, 5, 2.4), c(20, 5, 2.4), c(12, 19, 2.4),
    r(5, 4, 14, 2, 0.5, 0.55), r(5, 6, 2, 12, 0.5, 0.55), r(17, 6, 2, 12, 0.5, 0.55),
]
ICONS["esphome"] = [
    r(6, 6, 12, 12, 2),
    r(9.5, 9.5, 5, 5, 1, 0.3),
    r(9, 2, 2, 4), r(13, 2, 2, 4), r(18, 9, 4, 2),
    r(9, 18, 2, 4), r(13, 18, 2, 4), r(2, 9, 4, 2),
]
ICONS["homeassistant"] = [
    path('M12 3 L 22 11 L 19 11 L 19 21 L 5 21 L 5 11 L 2 11 Z'),
    r(10, 14, 4, 7, 0.5, 0.3),
]

# ------------------------------------------------------------------ media -
ICONS["jellyfin"] = [
    path('M4 3 L 20 3 L 20 21 L 4 21 Z M 10 8 L 16 12 L 10 16 Z'),
]
ICONS["plex"] = [
    p([(4, 4), (8, 12), (4, 20)]),
    p([(10, 4), (14, 12), (10, 20)]),
    p([(16, 4), (20, 12), (16, 20)]),
]
ICONS["emby"] = [
    ring(12, 12, 10, 6),
    p([(10, 8), (16, 12), (10, 16)]),
]
ICONS["navidrome"] = [
    c(8, 17, 4), r(11, 6, 2, 11, 0.8), p([(11, 6), (20, 4), (20, 9), (11, 11)]),
]
ICONS["airsonic"] = [
    c(6, 18, 3), p([(7.5, 15.5), (16, 4), (18, 6), (9.5, 17.5)]),
    c(18, 5, 2.6, 0.35), c(20.5, 8.5, 1.8, 0.35),
]
ICONS["tautulli"] = [
    r(3, 13, 4, 8), r(10, 8, 4, 13), r(17, 4, 4, 17),
]
ICONS["kodi"] = [
    r(2, 4, 20, 14, 2), r(8, 20, 8, 2),
    p([(10, 8), (16, 11), (10, 14)]),
]
ICONS["calibre"] = [
    path('M3 4 L 11 4 L 12 6 L 21 6 L 21 20 L 12 20 L 11 18 L 3 18 Z'),
    r(14, 9, 5, 1.6, 0.8, 0.3), r(14, 12, 5, 1.6, 0.8, 0.3), r(14, 15, 5, 1.6, 0.8, 0.3),
]

# -------------------------------------------------------------- *arr stack -
def _arr(inner):
    return [p([(12, 3), (20, 8), (20, 12), (4, 12), (4, 8)])] + inner + [
    p([(12, 22), (4, 17), (4, 13), (20, 13), (20, 17)]),
    p([(11, 8.5), (15.5, 13), (11, 17.5), (8, 13)], 0.0),
]


ICONS["sonarr"] = _arr([p([(12, 7), (15, 10.5), (13.2, 10.5), (13.2, 14),
                           (15, 14), (12, 17), (9, 14), (10.8, 14),
                           (10.8, 10.5), (9, 10.5)])])
ICONS["radarr"] = _arr([p([(12, 7), (15.5, 11.5), (13.6, 11.5), (13.6, 15),
                           (10.4, 15), (10.4, 11.5), (8.5, 11.5)])])
ICONS["readarr"] = _arr([path('M9 8 h 6 v 2 h -6 Z M9 11.5 h 6 v 2 h -6 Z '
                               'M11 15 h 4 v 2 h -4 Z')])
ICONS["bazarr"] = _arr([p([(9.5, 7.5), (12, 7.5), (12, 10.5), (14, 10.5),
                           (14, 12), (12, 12), (12, 16.5), (9.5, 16.5)]),
                        p([(14.5, 7.5), (16, 7.5), (16, 16.5), (14.5, 16.5)])])
ICONS["prowlarr"] = _arr([ring(11.5, 12, 4, 2.2), p([(14.5, 15), (17, 17.5)],
                                                  rule="nonzero")])

# ------------------------------------------------------------- downloads --
ICONS["sabnzbd"] = [
    ring(12, 12, 10, 7.5),
    p([(12, 7), (16, 12), (13.5, 12), (13.5, 16), (10.5, 16), (10.5, 12), (8, 12)]),
]
ICONS["nzbget"] = [
    r(3, 3, 18, 18, 3),
    p([(12, 6.5), (16.5, 12), (13.8, 12), (13.8, 16), (10.2, 16), (10.2, 12), (7.5, 12)],
      0.0),
]
ICONS["qbittorrent"] = [
    p([(12, 3), (20, 13), (15, 13), (15, 20), (9, 20), (9, 13), (4, 13)]),
]
ICONS["transmission"] = [
    ring(12, 12, 9, 5),
    p([(10.5, 6), (13.5, 6), (13.5, 18), (10.5, 18)]),
]
ICONS["deluge"] = [
    path('M6 15 A 4 4 0 0 1 6 8 A 5 5 0 0 1 16 7 A 3.5 3.5 0 0 1 18 15 Z'),
    p([(12, 10), (16, 15), (13.6, 15), (13.6, 19), (10.4, 19), (10.4, 15), (8, 15)]),
]
ICONS["rtorrent"] = [
    r(2, 4, 20, 16, 2),
    p([(6, 9), (10, 12.5), (6, 16)]),
    r(12, 15, 6, 1.8, 0.9, 0.35),
]
ICONS["saberren"] = [
    r(2, 5, 20, 14, 2),
    r(5, 5, 3, 14, 0, 0.3), r(16, 5, 3, 14, 0, 0.3),
    r(9, 8, 6, 3, 0.5, 0.3), r(9, 13, 6, 3, 0.5, 0.3),
]
ICONS["cross-seed"] = [
    p([(3, 8), (12, 8), (12, 5), (20, 10), (12, 15), (12, 12), (3, 12)]),
    p([(21, 16), (12, 16), (12, 19), (4, 14), (12, 9), (12, 12), (21, 12)], 0.55),
]

# -------------------------------------------------------- files and photos -
ICONS["syncthing"] = [
    c(6, 12, 4), c(18, 12, 4, 0.55),
    p([(11, 10.5), (13, 10.5), (13, 8), (17, 8), (17, 10), (14, 13.5), (13, 13.5),
       (13, 16), (17, 16), (17, 18), (11, 18), (11, 16), (10, 16), (10, 13.5)]),
    p([(13, 13.5), (10, 13.5), (7, 16), (10, 18), (10, 16), (13, 16)]),
]
ICONS["nextcloud"] = [
    path('M6 17 A 4 4 0 0 1 6 9 A 5 5 0 0 1 16 8 A 3.5 3.5 0 0 1 19 17 Z'),
    p([(8, 13), (11, 13), (9.5, 16)]),
]
ICONS["owncloud"] = [
    path('M5 18 A 4.5 4.5 0 0 1 5 9 A 5.5 5.5 0 0 1 16 8 A 4 4 0 0 1 20 18 Z'),
    c(12, 14, 3, 0.28),
]
ICONS["filebrowser"] = [
    path('M2 5 L 9 5 L 11 8 L 22 8 L 22 19 L 2 19 Z'),
    r(2, 12, 20, 7),
]
ICONS["immich"] = [
    r(2, 5, 20, 15, 2),
    p([(4, 18), (10, 10), (14, 15), (16, 13), (20, 18)]),
    c(16.5, 9, 2, 0.4),
]
ICONS["photoprism"] = [
    ring(12, 12, 10, 6.5),
    p([(12, 4), (19, 8), (19, 16), (12, 20), (5, 16), (5, 8)]),
]
ICONS["paperless"] = [
    r(4, 3, 12, 15, 1.5), r(7, 6, 12, 15, 1.5, 0.7),
    r(9, 9, 12, 12, 1.5, 0.45),
]
ICONS["minecraft"] = [
    path('M12 2 L 22 7 L 22 17 L 12 22 L 2 17 L 2 7 Z M12 4.2 L 4.2 8 L 4.2 '
         '16 L 12 19.8 Z'),
    path('M12 2 L 22 7 L 22 17 L 12 22 L 2 17 L 2 7 Z M12 4.2 L 19.8 8 L '
         '19.8 16 L 12 19.8 Z'),
]

if __name__ == "__main__":
    written = []
    for name, shapes in ICONS.items():
        body = "\n".join("  " + s for s in shapes)
        (OUT / (name + ".svg")).write_text(HEAD + body + "\n" + TAIL)
        written.append(name)
    print("wrote %d glyphs: %s" % (len(written), " ".join(sorted(written))))
