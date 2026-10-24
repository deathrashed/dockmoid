#!/bin/sh
# Development checks; none are runtime dependencies of the widget.
set -eu
cd "$(dirname "$0")/.."
node --test tests/*.test.js
python3 -m unittest discover -s tests -p "*_test.py"
python3 -I -c "import xml.dom.minidom as m; m.parse('contents/config/main.xml')"
sh -n install.sh package-release.sh translate/extract.sh translate/build.sh tests/run.sh tests/lint.sh
appstreamcli validate --no-net packaging/com.github.deathrashed.dockmoid.appdata.xml
if [ "${DOCKMOID_SKIP_QML_LINT:-0}" = 1 ]; then
    echo 'QML lint explicitly skipped (fixture/package checks only).'
else
    tests/lint.sh
fi
