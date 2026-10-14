#!/bin/sh
# Install or upgrade Dockmoid for the current user, including its theme icon.
# The icon has to live in an icon theme for the Add Widgets dialog to show it.
set -e
cd "$(dirname "$0")"
# -u refuses an unchanged version number, so fall back to remove + install.
kpackagetool6 -t Plasma/Applet -u . >/dev/null 2>&1 || {
    kpackagetool6 -t Plasma/Applet -r dockmoid.plasmoid >/dev/null 2>&1 || true
    kpackagetool6 -t Plasma/Applet -i .
}
theme="${XDG_DATA_HOME:-$HOME/.local/share}/icons/hicolor"
icons="$theme/512x512/apps"
mkdir -p "$icons"
cp docs/assets/icon.png "$icons/dockmoid.png"
rm -f "$theme/scalable/apps/dockmoid.svg"
if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    gtk-update-icon-cache -f -t "$theme"
fi
echo "Installed. If the widget icon does not appear straight away, reopen Add Widgets or run: kquitapp6 plasmashell && kstart plasmashell"
