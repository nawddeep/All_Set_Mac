#!/usr/bin/env bash
# Packages a built AllSet.app for download and checks the packages work.
#
#   scripts/package-release.sh <path/to/AllSet.app> <output folder> <version>
#
# Writes, in <output folder>:
#   AllSet-<version>.zip    the app, zipped with ditto (keeps signatures and symlinks)
#   AllSet-<version>.dmg    a compressed disk image with the app and an Applications link
#   SHA256SUMS.txt          a checksum line per file, for `shasum -a 256 -c`
#
# Every package is checked before it counts: the app's signature verifies, the
# zip unpacks to an app whose signature verifies, and the disk image passes
# `hdiutil verify` and mounts with a verifying app inside. Used by CI (ci.yml,
# job "package") and by releases (release.yml); works on a headless runner
# (unlike create-dmg.sh, which lays the window out through Finder).
set -euo pipefail

app="${1:?usage: package-release.sh <AllSet.app> <output folder> <version>}"
out="${2:?usage: package-release.sh <AllSet.app> <output folder> <version>}"
version="${3:?usage: package-release.sh <AllSet.app> <output folder> <version>}"
name="AllSet-${version}"

[ -d "$app" ] || { echo "error: $app not found; build it first (scripts/build-app.sh)" >&2; exit 1; }
mkdir -p "$out"
out="$(cd "$out" && pwd)"
work="$(mktemp -d)"
mounted=""
cleanup() {
  [ -n "$mounted" ] && hdiutil detach -quiet "$mounted" 2>/dev/null || true
  rm -rf "$work"
}
trap cleanup EXIT

echo "Checking the app's signature"
codesign --verify --deep --strict "$app"

echo "Making $name.zip"
rm -f "$out/$name.zip"
ditto -c -k --sequesterRsrc --keepParent "$app" "$out/$name.zip"
mkdir "$work/unzipped"
ditto -x -k "$out/$name.zip" "$work/unzipped"
codesign --verify --deep --strict "$work/unzipped/AllSet.app"

echo "Making $name.dmg"
rm -f "$out/$name.dmg"
mkdir "$work/dmg"
ditto "$app" "$work/dmg/AllSet.app"
ln -s /Applications "$work/dmg/Applications"
hdiutil create -quiet -volname "All Set" -srcfolder "$work/dmg" -fs HFS+ -format UDZO -imagekey zlib-level=9 "$out/$name.dmg"
hdiutil verify -quiet "$out/$name.dmg"
mkdir "$work/mount"
hdiutil attach -quiet -readonly -nobrowse -noautoopen -mountpoint "$work/mount" "$out/$name.dmg"
mounted="$work/mount"
[ -d "$mounted/AllSet.app" ] || { echo "error: the disk image mounted without the app inside" >&2; exit 1; }
codesign --verify --deep --strict "$mounted/AllSet.app"
hdiutil detach -quiet "$mounted"
mounted=""

(cd "$out" && shasum -a 256 "$name.zip" "$name.dmg" > SHA256SUMS.txt)
echo "Packaged and checked:"
(cd "$out" && ls -lh "$name.zip" "$name.dmg" && cat SHA256SUMS.txt)
