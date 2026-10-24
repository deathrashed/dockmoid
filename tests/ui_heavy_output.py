"""Large Inspect and log output stay responsive, and stay correct.

Builds synthetic data the size of `docker inspect` for ~40 containers and a
5000-line log, loads the production InspectTree and LogViewer offscreen, and
checks both what they show and that each step stays under a generous limit
(about 20x the timings measured on a desktop, so slow CI still passes).
Optional, like ui_runtime.py: needs PySide6 and the Plasma QML imports.
"""
import json, os, pathlib, random, sys, tempfile
os.environ.setdefault('QT_QPA_PLATFORM', 'offscreen')
from PySide6.QtWidgets import QApplication
from PySide6.QtQuick import QQuickView
from PySide6.QtCore import QUrl, QElapsedTimer
from PySide6.QtTest import QTest

project = pathlib.Path(__file__).resolve().parents[1]
random.seed(7)
def container(i):
    return {"Id": "%064x" % i, "Name": "/svc%02d" % i, "State": {"Status": "running", "Health": {"Status": "healthy", "Log": [{"ExitCode": 0, "Output": "ok"}] * 5}},
            "Config": {"Env": ["VAR_%d=value" % k for k in range(30)], "Labels": {"com.example.label%d" % k: "x" * 20 for k in range(40)}},
            "NetworkSettings": {"Networks": {"net%d" % k: {"IPAddress": "172.18.0.%d" % k, "Aliases": ["a", "b"]} for k in range(3)}},
            "Mounts": [{"Source": "/srv/svc%d/%d" % (i, k), "Destination": "/data%d" % k} for k in range(8)]}
inspect = json.dumps([container(i) for i in range(40)])
log = "\n".join("2026-10-24T10:%02d:%02d.123456789Z \x1b[32m%s\x1b[0m request %d took %dms" % (i // 60 % 60, i % 60, random.choice(["INFO", "WARN", "ERROR"]), i, random.randint(1, 900)) for i in range(5000))

out = pathlib.Path(tempfile.mkdtemp(prefix='dockmoid-heavy-'))
qml = out / 'Heavy.qml'
qml.write_text('''import QtQuick
import "%s" as C
Item { id: root; width: 1000; height: 700
 property var plasmoid: ({configuration: {logTimestampMode: 1, logTimestampPrecision: 0}})
 C.InspectTree { id: tree; anchors.fill: parent }
 C.LogViewer { id: logs; anchors.fill: parent; visible: false; logMode: true }
 function setTree(t) { tree.text = t } function expandAll() { tree.setAllExpanded(true) } function collapseAll() { tree.setAllExpanded(false) }
 function search(q) { tree.needle = q } function rows() { return tree.rows.length } function firstPath(i) { return tree.rows[i] ? tree.rows[i].path : "" }
 function raw(i) { return tree.rawAt(tree.rows[i].index) }
 function setLog(t) { logs.visible = true; logs.text = t } function filter(q) { logs.needle = q } function matched() { return logs.shownLines.length } function hidden() { return logs.hiddenLines }
}''' % (project / 'contents/ui/components').as_uri())
app = QApplication([])
view = QQuickView(); view.setSource(QUrl.fromLocalFile(str(qml)))
assert view.status() != QQuickView.Error, [e.toString() for e in view.errors()]
view.show(); r = view.rootObject(); failures = []

def timed(label, fn, limit_ms, settle=0):
    t = QElapsedTimer(); t.start(); fn(); app.processEvents()
    if settle: QTest.qWait(settle)
    ms = t.elapsed() - settle
    print('%-28s %6d ms' % (label, ms))
    if ms > limit_ms: failures.append('%s took %d ms (limit %d)' % (label, ms, limit_ms))

timed('inspect load', lambda: r.setTree(inspect), 3000)
if r.rows() != 41: failures.append(('collapsed rows', r.rows()))          # $ plus 40 containers
timed('inspect expand all', r.expandAll, 5000)
expanded = r.rows()
timed('inspect collapse all', r.collapseAll, 3000)
if r.rows() != 41: failures.append(('rows after collapse', r.rows()))
timed('inspect search', lambda: r.search('IPAddress'), 5000, settle=250)
if r.rows() == 0: failures.append('search found nothing')
if '172.18.0.' not in r.raw(r.rows() - 1): failures.append(('last search row value', r.raw(r.rows() - 1)[:80]))
r.search(''); QTest.qWait(250)
def count(v):
    return 1 + (sum(count(x) for x in (v.values() if isinstance(v, dict) else v)) if isinstance(v, (dict, list)) else 0)
if expanded != count(json.loads(inspect)): failures.append(('expand all rows', expanded, count(json.loads(inspect))))

timed('log load 5000 lines', lambda: r.setLog(log), 5000)
if r.matched() != 5000 or r.hidden() != 3000: failures.append(('log lines', r.matched(), r.hidden()))
timed('log filter', lambda: r.filter('ERROR'), 5000, settle=200)
if not 0 < r.matched() < 5000: failures.append(('filtered lines', r.matched()))

print('heavy output checks:', 'ok' if not failures else failures)
sys.exit(1 if failures else 0)
