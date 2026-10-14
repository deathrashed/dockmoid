#!/bin/sh
# Rebuild po/template.pot from every i18n() call, then merge it into each po/*.po.
# New language: msginit -i po/template.pot -l fr -o po/fr.po --no-translator
set -eu
cd "$(dirname "$0")/.."
file_list=$(mktemp "${TMPDIR:-/tmp}/dockmoid-i18n.XXXXXXXX")
trap 'rm -f "$file_list"' EXIT HUP INT TERM
domain=plasma_applet_dockmoid.plasmoid
find contents -name '*.qml' -o -name '*.js' | sort > "$file_list"
xgettext --from-code=UTF-8 --language=JavaScript --add-comments=i18n \
    --keyword=i18n:1 --keyword=i18np:1,2 --keyword=i18nc:1c,2 --keyword=i18ncp:1c,2,3 \
    --package-name=Dockmoid --package-version=2.4.0 -o po/template.pot -f "$file_list"
for po in po/*.po; do
    [ -e "$po" ] && msgmerge --update --backup=none "$po" po/template.pot
done
echo "template.pot: $(grep -c '^msgid' po/template.pot) messages"
