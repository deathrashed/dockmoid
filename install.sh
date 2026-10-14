#!/bin/sh
# Transactional current-user installation. Never remove a working package to retry.
set -eu
source_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
data_home=${XDG_DATA_HOME:-$HOME/.local/share}
case "$data_home" in /*) ;; *) echo 'XDG_DATA_HOME must be an absolute path' >&2; exit 1;; esac
command -v kpackagetool6 >/dev/null 2>&1 || { echo 'kpackagetool6 is required' >&2; exit 1; }
[ -f "$source_dir/metadata.json" ] && [ -f "$source_dir/contents/icons/dockmoid.png" ] || {
    echo 'Incomplete package: metadata.json and contents/icons/dockmoid.png are required' >&2; exit 1;
}
package_root="$data_home/plasma/plasmoids"
installed="$package_root/dockmoid.plasmoid"
mkdir -p "$package_root"
lock="$package_root/.dockmoid-install.lock"
mkdir "$lock" 2>/dev/null || { echo 'Another Dockmoid installation is in progress' >&2; exit 1; }
transaction=
changed=0
committed=0
icon_changed=0
icon="$data_home/icons/hicolor/512x512/apps/dockmoid.png"
cleanup() {
    status=$?
    trap - EXIT HUP INT TERM
    if [ "$committed" = 0 ] && [ "$changed" = 1 ]; then
        rm -rf -- "$installed"
        if [ -d "$transaction/previous" ]; then
            mv -- "$transaction/previous" "$installed" || {
                echo "Rollback failed; previous package retained at $transaction/previous" >&2
                rmdir "$lock"; exit 1;
            }
        fi
    fi
    if [ "$committed" = 0 ] && [ "$icon_changed" = 1 ]; then
        if [ -f "$transaction/previous-icon" ]; then
            cp -p -- "$transaction/previous-icon" "$icon" || status=1
        else
            rm -f -- "$icon"
        fi
    fi
    [ -z "$transaction" ] || rm -rf -- "$transaction"
    rmdir "$lock"
    exit "$status"
}
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM
transaction=$(mktemp -d "$package_root/.dockmoid-install.XXXXXXXX")
mkdir "$transaction/source"
# Complete the staging copy before asking KPackage to touch the destination.
for entry in metadata.json contents po locale LICENSE THIRD_PARTY_NOTICES.md install.sh; do
    if [ -e "$source_dir/$entry" ]; then cp -Rp -- "$source_dir/$entry" "$transaction/source/"; fi
done
[ ! -L "$installed" ] || { echo 'Refusing a symlink at the installed package path' >&2; exit 1; }
if [ -e "$installed" ]; then
    [ -d "$installed" ] || { echo 'Installed package path is not a directory' >&2; exit 1; }
    cp -Rp -- "$installed" "$transaction/previous"
    operation=-u
else
    operation=-i
fi
mkdir -p -- "$(dirname -- "$icon")"
if [ -e "$icon" ]; then cp -p -- "$icon" "$transaction/previous-icon"; fi
cp -- "$transaction/source/contents/icons/dockmoid.png" "$transaction/new-icon"
changed=1
kpackagetool6 -t Plasma/Applet --packageroot "$package_root" "$operation" "$transaction/source"
icon_changed=1
cp -- "$transaction/new-icon" "$icon"
committed=1
if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    gtk-update-icon-cache -f -t "$data_home/icons/hicolor" || echo 'Icon cache refresh unavailable; reopen Add Widgets to refresh artwork.' >&2
fi
echo 'Dockmoid installed. Reopen Add Widgets if its icon has not refreshed.'
