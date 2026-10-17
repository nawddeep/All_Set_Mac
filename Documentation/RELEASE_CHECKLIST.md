# Release checklist

Run before every public release, on real Macs, with the build that will ship (the notarized dmg from the Release workflow). Automated checks (CI: build, tests, smoke test, probes, macOS 14.2 build) don't replace this: they never see a real permission prompt, a second monitor or VoiceOver.

Record each run: date, build number (About page), who ran it. Mark every cell **Pass**, **Fail** (with a note) or **N/A**.

## 1. Install, update, uninstall

| Check | macOS 14.2+ | macOS 15 | macOS 26 |
|---|---|---|---|
| Clean Mac (new user account): download the dmg, drag to Applications, first open shows no Gatekeeper warning (notarized) | | | |
| First-run welcome appears once; every extra starts off; nothing asks for a permission | | | |
| Second launch: no welcome | | | |
| Update from the previous release through Check for Updates… (Sparkle): downloads, verifies, relaunches, data intact | | | |
| Settings › General › Uninstall All Set…: ⌘⇧5 works again, system wallpaper is yours, login item gone, app in the Trash; with the data box ticked, the data folder is in the Trash too | | | |
| `scripts/uninstall.sh` after dragging the running app to the Trash: same result | | | |

## 2. Displays

| Check | Built-in only | Built-in + external | Two identical externals |
|---|---|---|---|
| Widgets land on the chosen display; a theme asks which display | | | |
| Unplug / replug: widgets come back where they were, sized for the screen | | | |
| Change resolution: widgets refit | | | |
| Live wallpaper on each display; pauses when covered | | | |
| Dynamic Island on the notch; virtual island on a display without one | | | |

## 3. Permissions: denied, then revoked while running

For each, deny at the prompt, use the feature, then allow, then revoke in System Settings while All Set runs. Expected: no crash, no hang, the feature says what's missing, Settings › General › Permissions shows the state and Open System Settings works.

| Permission | Denied | Allowed | Revoked mid-run |
|---|---|---|---|
| Accessibility (Window Snapping shortcut, Workspaces, TapTap Copy/Paste) | | | |
| Calendars (Calendar widget) | | | |
| Audio Recording (Sound Mixer: turn one app down) | | | |

## 4. Accessibility settings

| Check | Pass/Fail |
|---|---|
| VoiceOver: every page of the main window can be reached and read; every button says what it does; the onboarding can be completed | |
| Keyboard only: ⌘1–⌘4 switch places; Tab moves through each page's controls; ⌘K search works | |
| Reduce Motion: no carousel spring, page fades only, wallpaper and widgets still | |
| Reduce Transparency: navigation and panels stay readable | |
| Increase Contrast: text and controls readable on every page | |

## 5. Features

| Check | Pass/Fail |
|---|---|
| Themes: preview, apply, Undo, Restore Previous Desktop (after a relaunch too) | |
| Widgets: add, drag, resize in Arrange mode, Edit Widget sliders, remove + Undo | |
| Wallpaper: a built-in, your own video, turn off (system wallpaper comes back) | |
| Each extra switched on works, switched off leaves no shortcut or timer | |
| AI Screenshot: ⌃⌥⌘5; asks before the first send; taking ⌘⇧5 asks first and gives it back on quit | |
| Deep links: `open allset://open/themes` instant; `open allset://theme/setup.floodlightGold` from Terminal asks first, then offers Undo | |
| Settings › General › Network use matches what Little Snitch / LuLu sees in a 10-minute session | |
| Settings › General › Compatibility: nothing "Not working" on this macOS | |
| About › Export Diagnostics… writes a zip with reports and a log | |

## 6. Energy

| Check | Pass/Fail |
|---|---|
| Activity Monitor › Energy, 10 minutes idle with 5 widgets visible and no video wallpaper: All Set's Energy Impact stays low (< 1% CPU) | |
| Fanless Mac: scrolling Themes, Widgets and Wallpaper for a minute doesn't get the Mac warm | |
