#!/bin/zsh
# Uninstalls All Set and puts back what it changed in macOS. For when the app
# is already gone (dragged to the Trash while running); otherwise use
# All Set › Settings › General › Uninstall All Set….
#
#   ./scripts/uninstall.sh            restore macOS, remove the login item, move the app to the Trash
#   ./scripts/uninstall.sh --data     also move ~/Library/Application Support/AllSet to the Trash
#
# Safe to run more than once. Never deletes anything: it moves things to the Trash.
set -u

BUNDLE_ID="com.pratik.allset"
DATA="$HOME/Library/Application Support/AllSet"
REMOVE_DATA=0
[[ "${1:-}" == "--data" ]] && REMOVE_DATA=1

to_trash() {
  # Finder keeps "Put Back" working; fall back to a plain move into ~/.Trash.
  local item="$1"
  [[ -e "$item" ]] || return 0
  if ! osascript -e "tell application \"Finder\" to delete (POSIX file \"$item\" as alias)" >/dev/null 2>&1; then
    mv "$item" "$HOME/.Trash/$(basename "$item")-$(date +%s)"
  fi
  echo "Moved to the Trash: $item"
}

echo "Quitting All Set if it's running…"
osascript -e "tell application id \"$BUNDLE_ID\" to quit" >/dev/null 2>&1
sleep 2

# 1. macOS's ⌘⇧5 screenshot toolbar shortcut (symbolic hot key 184), only if All Set switched it off.
if [[ "$(defaults read "$BUNDLE_ID" screenshot.systemShortcutOffByAllSet 2>/dev/null)" == "1" ]]; then
  defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 184 \
    '<dict><key>enabled</key><true/><key>value</key><dict><key>parameters</key><array><integer>53</integer><integer>23</integer><integer>1179648</integer></array><key>type</key><string>standard</string></dict></dict>'
  /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u 2>/dev/null
  defaults delete "$BUNDLE_ID" screenshot.systemShortcutOffByAllSet 2>/dev/null
  echo "Restored macOS's ⌘⇧5 screenshot shortcut."
else
  echo "macOS's ⌘⇧5 shortcut was not changed by All Set."
fi

# 2. The login item.
osascript -e 'tell application "System Events" to delete (every login item whose name is "All Set" or name is "AllSet")' >/dev/null 2>&1
echo "Removed the login item, if there was one."

# 3. The app.
for app in "/Applications/All Set.app" "/Applications/AllSet.app" "$HOME/Applications/All Set.app" "$HOME/Applications/AllSet.app"; do
  to_trash "$app"
done

# 4. The data, only when asked.
if (( REMOVE_DATA )); then
  to_trash "$DATA"
  defaults delete "$BUNDLE_ID" >/dev/null 2>&1 && echo "Removed All Set's preferences."
else
  echo "Your data is still in $DATA (run with --data to move it to the Trash)."
fi

echo "Note: the system wallpaper stays as it is now; pick another in System Settings › Wallpaper if All Set's still image is showing."
echo "Done."
