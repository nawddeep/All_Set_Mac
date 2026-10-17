# Security

## Reporting a problem
Please report security issues privately, not in a public issue: use GitHub's **Report a vulnerability** (Security tab of this repository), or email the maintainer listed on the repository profile. Include what you found, how to reproduce it, and the version and build from About. You'll get an answer within a week.

## What All Set does that matters for security
- **Not sandboxed**, distributed directly, signed with a Developer ID and notarized, hardened runtime with only two entitlements (calendars, audio input; `Resources/AllSet.entitlements`).
- **Permissions** are asked for only when the feature that needs one is switched on: Accessibility, Calendars, Audio Recording.
- **It runs no shell commands from its settings.** TapTap launches only apps (by bundle identifier) and Shortcuts (by plain name), checked when its settings file is read; shortcut tiles open only apps, folders and links.
- **`allset://` links** are length- and character-checked; links that change the desktop are rate-limited, undoable, and ask first when All Set isn't in front.
- **Network:** every host it can contact is listed in Settings › General › Network use (generated from `NetworkUse.swift`). API keys you add stay in the Keychain and are sent only to their own provider.
- **macOS settings it changes:** the ⌘⇧5 screenshot shortcut (only if you choose it, given back on quit) and the system wallpaper (only while the live wallpaper is on). Settings › General › Restore macOS settings puts both back; `scripts/uninstall.sh` does it for an app that's already gone.
- **Updates** are EdDSA-signed (Sparkle) and verified before install.
- **Private macOS interfaces** each have a kill switch: `defaults write com.pratik.allset capability.<name>.disabled -bool YES` (names in Settings › General › Compatibility).

## The personal library server
`scripts/cloud` is a personal server for the owner's own wallpaper library on Tailscale; it is not meant to be exposed to the internet (`Documentation/operations.md`). Its SQL passes every value as a psql variable or COPY data, never as SQL text (`scripts/cloud/pgsql.py`, tested with hostile input).
