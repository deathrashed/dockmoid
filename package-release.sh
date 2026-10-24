#!/bin/sh
# Build clean KDE and source archives from this checkout. Does not publish them.
set -eu

src=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
dest=${1:?Usage: package-release.sh OUTPUT_DIRECTORY}
mkdir -p -- "$(dirname -- "$dest")"
dest=$(CDPATH= cd -- "$(dirname -- "$dest")" && pwd)/$(basename -- "$dest")
case "$dest/" in "$src/"*) echo 'Output directory must be outside the source tree.' >&2; exit 1;; esac

version=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["KPlugin"]["Version"])' "$src/metadata.json")
[ "$version" = 2.4.0 ] || { echo "Expected release version 2.4.0, found $version" >&2; exit 1; }
command -v zip >/dev/null 2>&1 || { echo 'zip is required' >&2; exit 1; }
for required in contents metadata.json LICENSE THIRD_PARTY_NOTICES.md README.md RELEASE_CHECKLIST.md install.sh; do
    [ -e "$src/$required" ] || { echo "Missing release file: $required" >&2; exit 1; }
done

mkdir -p -- "$dest"
stage=$(mktemp -d "$dest/.dockmoid-release.XXXXXXXX")
cleanup() { rm -rf -- "$stage"; }
trap cleanup EXIT HUP INT TERM
mkdir -p "$stage/package" "$stage/source/dockmoid-$version"

copy_runtime() {
    target=$1
    cp -R -- "$src/contents" "$target/contents"
    cp -- "$src/metadata.json" "$src/LICENSE" "$src/THIRD_PARTY_NOTICES.md" "$target/"
    # Exclude VCS state, test fixtures and machine-local/cache files if present.
    find "$target" \( -name .git -o -name .hg -o -name .svn -o -name __pycache__ \
        -o -name .pytest_cache -o -name tests -o -name test \) -prune -exec rm -rf -- {} +
    find "$target" -type f \( -name '*.pyc' -o -name '*.qmlc' -o -name '*.jsc' \
        -o -name '.env' -o -name '.env.*' \) -delete
}

copy_runtime "$stage/package"
copy_runtime "$stage/source/dockmoid-$version"
cp -- "$src/README.md" "$src/RELEASE_CHECKLIST.md" "$src/install.sh" "$src/package-release.sh" "$stage/source/dockmoid-$version/"
for entry in docs tests translate packaging .gitattributes .gitignore CHANGELOG.md CONTRIBUTING.md SECURITY.md; do
    if [ -e "$src/$entry" ]; then cp -R -- "$src/$entry" "$stage/source/dockmoid-$version/"; fi
done
# Source distributions contain development checks, not their generated caches.
find "$stage/source" -type d -name __pycache__ -prune -exec rm -rf -- {} +

(
    cd "$stage/package"
    zip -X -qr "$stage/dockmoid-$version.plasmoid" .
)
(
    cd "$stage/source"
    zip -X -qr "$stage/dockmoid-$version-source.zip" "dockmoid-$version"
)
(
    cd "$stage"
    sha256sum "dockmoid-$version.plasmoid" "dockmoid-$version-source.zip" > SHA256SUMS
)
mv -f -- "$stage/dockmoid-$version.plasmoid" "$dest/dockmoid-$version.plasmoid"
mv -f -- "$stage/dockmoid-$version-source.zip" "$dest/dockmoid-$version-source.zip"
mv -f -- "$stage/SHA256SUMS" "$dest/SHA256SUMS"
printf 'Created %s\nCreated %s\n' "$dest/dockmoid-$version.plasmoid" "$dest/dockmoid-$version-source.zip"
