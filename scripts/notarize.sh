#!/usr/bin/env bash
# Notarizes and staples a Developer ID–signed All Set, then checks Gatekeeper
# accepts it.
#
#   scripts/notarize.sh app  <path/to/AllSet.app>
#   scripts/notarize.sh dmg  <path/to/AllSet-x.y.z.dmg>
#
# Needs APPLE_ID, APPLE_TEAM_ID and APPLE_APP_PASSWORD (an app-specific
# password) in the environment. Used by .github/workflows/release.yml; works
# the same on a Mac with the Developer ID certificate in its keychain.
set -euo pipefail

kind="${1:?usage: notarize.sh app|dmg <path>}"
target="${2:?usage: notarize.sh app|dmg <path>}"
: "${APPLE_ID:?set APPLE_ID}" "${APPLE_TEAM_ID:?set APPLE_TEAM_ID}" "${APPLE_APP_PASSWORD:?set APPLE_APP_PASSWORD}"
[ -e "$target" ] || { echo "error: $target not found" >&2; exit 1; }

submit() {
  xcrun notarytool submit "$1" --apple-id "$APPLE_ID" --team-id "$APPLE_TEAM_ID" --password "$APPLE_APP_PASSWORD" --wait \
    --output-format json | tee "${TMPDIR:-/tmp}/notary-result.json"
  if ! grep -q '"status" *: *"Accepted"' "${TMPDIR:-/tmp}/notary-result.json"; then
    id="$(sed -n 's/.*"id" *: *"\([^"]*\)".*/\1/p' "${TMPDIR:-/tmp}/notary-result.json" | head -1)"
    [ -n "$id" ] && xcrun notarytool log "$id" --apple-id "$APPLE_ID" --team-id "$APPLE_TEAM_ID" --password "$APPLE_APP_PASSWORD" || true
    echo "error: notarization was not accepted" >&2
    exit 1
  fi
}

case "$kind" in
  app)
    zip="$(mktemp -d)/AllSet-notarize.zip"
    ditto -c -k --keepParent "$target" "$zip"
    submit "$zip"
    xcrun stapler staple "$target"
    xcrun stapler validate "$target"
    spctl --assess --type execute -vv "$target"
    ;;
  dmg)
    submit "$target"
    xcrun stapler staple "$target"
    xcrun stapler validate "$target"
    spctl --assess --type open --context context:primary-signature -vv "$target"
    ;;
  *)
    echo "usage: notarize.sh app|dmg <path>" >&2
    exit 2
    ;;
esac
echo "Notarized, stapled and accepted by Gatekeeper: $target"
