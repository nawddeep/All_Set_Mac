#!/usr/bin/env bash
# Builds a release build and packages it as build/AllSet.app.
set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME="AllSet"
# ALLSET_APP_DIR builds somewhere else (to check a package without replacing
# the app you run).
APP_DIR="${ALLSET_APP_DIR:-build/${APP_NAME}.app}"
HELPER="libAllSetMediaHelper.dylib"

# Builds every product, including the media helper the app loads at runtime.
swift build -c release
BIN_DIR="$(swift build -c release --show-bin-path)"

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Frameworks" "$APP_DIR/Contents/Resources"
cp "$BIN_DIR/$APP_NAME" "$APP_DIR/Contents/MacOS/$APP_NAME"
cp "$BIN_DIR/$HELPER" "$APP_DIR/Contents/Frameworks/$HELPER"
# Sparkle (updates): SwiftPM leaves the framework next to the binary; the app
# finds it in Contents/Frameworks.
if [ -d "$BIN_DIR/Sparkle.framework" ]; then
  ditto "$BIN_DIR/Sparkle.framework" "$APP_DIR/Contents/Frameworks/Sparkle.framework"
  install_name_tool -add_rpath "@executable_path/../Frameworks" "$APP_DIR/Contents/MacOS/$APP_NAME" 2>/dev/null || true
fi
cp Resources/Info.plist "$APP_DIR/Contents/Info.plist"

# Version: ALLSET_VERSION sets the marketing version (else Info.plist's);
# the build number is the commit count, so every package says which build it is.
PLIST="$APP_DIR/Contents/Info.plist"
if [ -n "${ALLSET_VERSION:-}" ]; then
  /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $ALLSET_VERSION" "$PLIST"
fi
if BUILD_NUMBER="$(git rev-list --count HEAD 2>/dev/null)"; then
  /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$PLIST"
fi

# Third-party notices travel with the app: whatever is in Documentation/third-party
# goes into Contents/Resources/Notices, if there is anything.
NOTICES="$APP_DIR/Contents/Resources/Notices"
mkdir -p "$NOTICES"
if [ -d Documentation/third-party ] && [ -n "$(ls -A Documentation/third-party)" ]; then
  cp Documentation/third-party/* "$NOTICES/"
fi

# A public library (scripts/cloud/publish_catalog.py behind Caddyfile.public):
# no key and no Tailscale, the app reads its list by itself.
#   ALLSET_PUBLIC_LIBRARY_URL=https://library.example.com
# A copy built with one carries nothing of the private library server below:
# not its address, not the plain-HTTP exception for it.
if [ -z "${ALLSET_PUBLIC_LIBRARY_URL:-}" ] && [ -f scripts/local.env ]; then
  ALLSET_PUBLIC_LIBRARY_URL="$(sed -n 's/^ALLSET_PUBLIC_LIBRARY_URL=//p' scripts/local.env | tr -d '"' | head -1)"
fi
if [ -n "${ALLSET_PUBLIC_LIBRARY_URL:-}" ]; then
  /usr/libexec/PlistBuddy -c "Add :AllSetPublicLibraryURL string $ALLSET_PUBLIC_LIBRARY_URL" "$APP_DIR/Contents/Info.plist"
  echo "Public wallpaper library: $ALLSET_PUBLIC_LIBRARY_URL built into the app (it also checks access keys)"
  ALLSET_LIBRARY_SERVER_URL=""
  ALLSET_LIBRARY_SERVER_HOST=""
  # HTTPS needs nothing more. A plain-HTTP address (a rehearsal against this
  # Mac) needs macOS told that this one host may be reached without it.
  case "$ALLSET_PUBLIC_LIBRARY_URL" in
    http://*) ALLSET_LIBRARY_SERVER_HOST="$(printf '%s' "$ALLSET_PUBLIC_LIBRARY_URL" | sed -E 's#^http://([^/:]+).*#\1#')" ;;
  esac
else
  # Plain HTTP for exactly one host: the personal, Tailscale-only library server.
  # Its address isn't in the source; set ALLSET_LIBRARY_SERVER_HOST, or put
  # ALLSET_LIBRARY_SERVER_HOST=100.x.y.z in scripts/local.env (git-ignored).
  if [ -z "${ALLSET_LIBRARY_SERVER_HOST:-}" ] && [ -f scripts/local.env ]; then
    ALLSET_LIBRARY_SERVER_HOST="$(sed -n 's/^ALLSET_LIBRARY_SERVER_HOST=//p' scripts/local.env | tr -d '"' | head -1)"
  fi
  # The library's address, baked in so a copy sent to someone else has nothing to
  # set up but its key (`AllSet library <key>`). Same local.env pattern as the host above:
  #   ALLSET_LIBRARY_SERVER_URL=http://100.x.y.z:8080
  if [ -z "${ALLSET_LIBRARY_SERVER_URL:-}" ] && [ -f scripts/local.env ]; then
    ALLSET_LIBRARY_SERVER_URL="$(sed -n 's/^ALLSET_LIBRARY_SERVER_URL=//p' scripts/local.env | tr -d '"' | head -1)"
  fi
fi
if [ -n "${ALLSET_LIBRARY_SERVER_HOST:-}" ]; then
  PLIST="$APP_DIR/Contents/Info.plist"
  /usr/libexec/PlistBuddy -c "Add :NSAppTransportSecurity dict" "$PLIST" 2>/dev/null || true
  /usr/libexec/PlistBuddy -c "Add :NSAppTransportSecurity:NSExceptionDomains dict" "$PLIST" 2>/dev/null || true
  /usr/libexec/PlistBuddy -c "Add :NSAppTransportSecurity:NSExceptionDomains:$ALLSET_LIBRARY_SERVER_HOST dict" "$PLIST"
  /usr/libexec/PlistBuddy -c "Add :NSAppTransportSecurity:NSExceptionDomains:$ALLSET_LIBRARY_SERVER_HOST:NSExceptionAllowsInsecureHTTPLoads bool true" "$PLIST"
  /usr/libexec/PlistBuddy -c "Add :NSAppTransportSecurity:NSExceptionDomains:$ALLSET_LIBRARY_SERVER_HOST:NSIncludesSubdomains bool false" "$PLIST"
  echo "Library server: plain HTTP allowed for $ALLSET_LIBRARY_SERVER_HOST only"
else
  echo "No plain-HTTP library server: the app reaches a library over HTTPS only"
fi
if [ -n "${ALLSET_LIBRARY_SERVER_URL:-}" ]; then
  /usr/libexec/PlistBuddy -c "Delete :AllSetLibraryServerURL" "$APP_DIR/Contents/Info.plist" 2>/dev/null || true
  /usr/libexec/PlistBuddy -c "Add :AllSetLibraryServerURL string $ALLSET_LIBRARY_SERVER_URL" "$APP_DIR/Contents/Info.plist"
  echo "Wallpaper library: $ALLSET_LIBRARY_SERVER_URL built into the app"
fi
# The access key screen (AccessController) is in every build. Only a Mac with
# `defaults write com.pratik.allset accessGateOff -bool YES` skips it (the owner's).
echo "Access gate: on (a key is needed to start, except on a Mac set to skip it)"
# Updates: Sparkle stays switched off (no checks, no network) until the
# owner's EdDSA public key replaces the placeholder in Info.plist, or arrives
# here as ALLSET_SPARKLE_PUBLIC_KEY (the release workflow passes the repository
# variable SPARKLE_PUBLIC_KEY).
if [ -n "${ALLSET_SPARKLE_PUBLIC_KEY:-}" ]; then
  /usr/libexec/PlistBuddy -c "Set :SUPublicEDKey $ALLSET_SPARKLE_PUBLIC_KEY" "$APP_DIR/Contents/Info.plist"
  echo "Updates: Sparkle public key built in"
fi
if [ -f Resources/AppIcon.icns ]; then
  cp Resources/AppIcon.icns "$APP_DIR/Contents/Resources/"
fi
cp -R Sources/AllSetCore/Resources/ThemeArt "$APP_DIR/Contents/Resources/"
# Localized text (Resources/<lang>.lproj): the app bundle's own, where Text and String(localized:) look.
for strings in Resources/*.lproj; do
  [ -d "$strings" ] && cp -R "$strings" "$APP_DIR/Contents/Resources/"
done

# Sign with the local development certificate when it exists (see
# setup-signing.sh) so macOS keeps Accessibility permission across rebuilds;
# otherwise sign ad hoc. Distribution will need a Developer ID certificate and
# notarization.
# ALLSET_SIGN_IDENTITY picks one explicitly (the release workflow passes its
# Developer ID); a Developer ID signature gets the hardened runtime and a secure
# timestamp, which notarization requires.
IDENTITY="${ALLSET_SIGN_IDENTITY:--}"
if [ -z "${ALLSET_SIGN_IDENTITY:-}" ] && security find-certificate -c "All Set Development" >/dev/null 2>&1; then
  IDENTITY="All Set Development"
fi
# Every identity, ad hoc included, signs with the hardened runtime and the
# app's entitlements, so a dev build fails the same way a notarized one would.
SIGN_OPTIONS=(--options runtime)
ENTITLEMENTS=Resources/AllSet.entitlements
if [[ "$IDENTITY" == "Developer ID Application"* ]]; then
  SIGN_OPTIONS+=(--timestamp)
else
  # Library validation only loads frameworks signed by the app's own team. A
  # Developer ID build has one (app and Sparkle share it); the self-signed dev
  # certificate and ad hoc signing have none, so for those builds only the
  # check is relaxed. Releases never get this key.
  ENTITLEMENTS="$(mktemp -t allset-dev-entitlements).plist"
  cp Resources/AllSet.entitlements "$ENTITLEMENTS"
  /usr/libexec/PlistBuddy -c "Add :com.apple.security.cs.disable-library-validation bool true" "$ENTITLEMENTS"
fi
codesign --force "${SIGN_OPTIONS[@]}" --sign "$IDENTITY" "$APP_DIR/Contents/Frameworks/$HELPER"
# Sparkle's helpers are signed inside out, as Sparkle's documentation asks for
# apps built outside Xcode.
SPARKLE="$APP_DIR/Contents/Frameworks/Sparkle.framework"
if [ -d "$SPARKLE" ]; then
  for item in "$SPARKLE"/Versions/B/XPCServices/*.xpc "$SPARKLE/Versions/B/Autoupdate" "$SPARKLE/Versions/B/Updater.app"; do
    [ -e "$item" ] && codesign --force "${SIGN_OPTIONS[@]}" --sign "$IDENTITY" "$item"
  done
  codesign --force "${SIGN_OPTIONS[@]}" --sign "$IDENTITY" "$SPARKLE"
fi
codesign --force "${SIGN_OPTIONS[@]}" --entitlements "$ENTITLEMENTS" --sign "$IDENTITY" "$APP_DIR"
codesign --verify --deep --strict "$APP_DIR"

VERSION="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$PLIST")"
BUILD="$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$PLIST")"
echo "Built $APP_DIR: version $VERSION ($BUILD), signed ${IDENTITY/-/ad hoc}, notices: $(ls "$NOTICES" | tr '\n' ' ')"
