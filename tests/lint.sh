#!/bin/sh
# Qt 6 qmllint over the UI, ignoring the `plasmoid`/`i18n` context globals that
# every Plasma applet reaches unqualified. Exits non-zero on any other finding.
cd "$(dirname "$0")/.." || exit 1
out=$(/usr/lib/qt6/bin/qmllint -I /usr/lib/qt6/qml $(find contents/ui -name '*.qml') 2>&1)
printf '%s\n' "$out" | awk '
  /^(Warning|Error|Info):/ { keep = ($0 !~ /\[unqualified\]/ && $0 !~ /\[id-shadows-member\]/ && $0 !~ /Note: Id defined here/) }
  /^$/ { keep = 0 }
  keep { print; found = 1 }
  END { exit found }'
