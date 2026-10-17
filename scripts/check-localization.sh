#!/usr/bin/env bash
# Fails when AppKit user-facing text is a bare string literal: alerts, buttons,
# menu items and toasts must go through String(localized:) so they can be
# translated (SwiftUI Text("…") literals are localized already).
#   scripts/check-localization.sh
set -euo pipefail
cd "$(dirname "$0")/.."
found=$(grep -rnE '(messageText|informativeText) = "|addButton\(withTitle: "|Toast\(message: "|NSMenuItem\(title: "' Sources/AllSet --include='*.swift' \
  | grep -v 'PageCPUProbe\|RenderHarness' || true)
if [ -n "$found" ]; then
  echo "User-facing text that bypasses localization (wrap it in String(localized:)):"
  echo "$found"
  exit 1
fi
echo "Localization: every alert, button, menu item and toast string is localizable."
