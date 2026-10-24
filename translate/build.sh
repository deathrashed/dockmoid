#!/bin/sh
# Compile translate/*.po into contents/locale/<lang>/LC_MESSAGES/*.mo, where Plasma looks.
set -eu
cd "$(dirname "$0")/.."
domain=plasma_applet_com.github.deathrashed.dockmoid
for po in translate/*.po; do
    [ -e "$po" ] || { echo "no translations yet (see translate/extract.sh)"; exit 0; }
    lang=$(basename "$po" .po)
    mkdir -p "contents/locale/$lang/LC_MESSAGES"
    msgfmt -o "contents/locale/$lang/LC_MESSAGES/$domain.mo" "$po"
    echo "built $lang"
done
