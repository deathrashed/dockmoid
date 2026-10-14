#!/bin/sh
# Plasma supplies ambient plasmoid/i18n context properties which qmllint cannot
# resolve. Keep the established context categories disabled, never whole files;
# all other diagnostics and tool failures remain fatal. --raw shows every warning.
set -eu
cd "$(dirname "$0")/.."
raw=${DOCKMOID_LINT_RAW:-0}
case "${1:-}" in --raw) raw=1;; "") ;; *) echo "Usage: $0 [--raw]" >&2; exit 2;; esac
qt_query=
for candidate in qtpaths6 qtpaths-qt6 qmake6 qmake-qt6; do
    if command -v "$candidate" >/dev/null 2>&1; then qt_query=$candidate; break; fi
done
lint=${QMLLINT:-}
imports=${QML_IMPORT_DIR:-}
if [ -n "$qt_query" ]; then
    case "$qt_query" in qtpaths*) query=--query;; *) query=-query;; esac
    if [ -z "$lint" ]; then
        qt_bins=$("$qt_query" "$query" QT_HOST_BINS)
        [ ! -x "$qt_bins/qmllint" ] || lint="$qt_bins/qmllint"
    fi
    if [ -z "$imports" ]; then imports=$("$qt_query" "$query" QT_INSTALL_QML); fi
fi
if [ -z "$lint" ]; then
    for candidate in qmllint6 qmllint-qt6 qmllint; do
        if command -v "$candidate" >/dev/null 2>&1; then lint=$candidate; break; fi
    done
fi
[ -n "$lint" ] || { echo 'Qt 6 qmllint unavailable; set QMLLINT to its path' >&2; exit 1; }
"$lint" --version
diagnostics=$(mktemp "${TMPDIR:-/tmp}/dockmoid-qmllint.XXXXXX")
output=$(mktemp "${TMPDIR:-/tmp}/dockmoid-qmllint-output.XXXXXX")
trap 'rm -f "$diagnostics" "$output"' EXIT
set -- --ignore-settings --max-warnings 0 --json "$diagnostics"
if [ -n "$imports" ]; then set -- "$@" -I "$imports"; fi
if [ "$raw" != 1 ]; then
    set -- "$@" --unqualified disable --id-shadows-member disable
fi
for file in $(find contents/ui contents/config -name '*.qml' -type f | sort); do
    set -- "$@" "$file"
done
if "$lint" "$@" >"$output" 2>&1; then
    cat "$output" >&2
    exit 0
else
    status=$?
fi
if [ -s "$output" ]; then
    cat "$output" >&2
elif [ -s "$diagnostics" ]; then
    python3 - "$diagnostics" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as source:
    report = json.load(source)
for file in report.get("files", []):
    for warning in file.get("warnings", []):
        print("{}:{}:{}: {} [{}]".format(
            file.get("filename", "<unknown>"),
            warning.get("line", 0),
            warning.get("column", 0),
            warning.get("message", "").strip().replace("\n", " "),
            warning.get("id", warning.get("type", "warning")),
        ))
PY
fi
exit "$status"
