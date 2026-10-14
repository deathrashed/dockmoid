#!/bin/sh
# Everything that can be checked without a Plasma session.
cd "$(dirname "$0")/.." || exit 1
set -e
node tests/parsers.test.js
node tests/icons.test.js
python3 -I -c "import xml.dom.minidom as m; m.parse('contents/config/main.xml')" && echo "main.xml ok"
tests/lint.sh >/tmp/dockmoid-lint.txt || true
n=$(grep -E '^(Warning|Error)' /tmp/dockmoid-lint.txt | grep -vc 'ContainerActions.qml\|Expression statement\|implicitSize' || true)
[ "$n" = "0" ] && echo "qmllint ok" || { echo "qmllint: $n new findings"; grep -E '^(Warning|Error)' /tmp/dockmoid-lint.txt | grep -v 'ContainerActions.qml\|Expression statement\|implicitSize'; exit 1; }
