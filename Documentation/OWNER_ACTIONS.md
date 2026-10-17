# Owner actions

Things only the owner can do. Ordered by priority at the end of the run.

## To do
- **Public content: decide and provision.** Read `Documentation/public-content-backend.md`. Decide which wallpapers may be public and get written licences (none of the 986 Workshop items can be). Then create a Cloudflare R2 bucket with a custom domain, generate the list-signing key, and follow its migration steps.
- **Sparkle update key.** Run `.build/artifacts/sparkle/Sparkle/bin/generate_keys` once (after `swift build`); it stores the private key in your login keychain and prints the public key. Then `generate_keys -x sparkle_private.key`, put that file's contents in the GitHub secret `SPARKLE_PRIVATE_KEY`, delete the file, and put the public key in the repository **variable** `SPARKLE_PUBLIC_KEY`. Releases then publish `appcast.xml` and the app checks it. Feed: `https://github.com/nawddeep/All_Set_Mac/releases/latest/download/appcast.xml` (change `SUFeedURL` in Resources/Info.plist if releases live elsewhere). If you paste the key into Info.plist instead, update `UpdateConfigurationTests.theShippedInfoPlistIsStillThePlaceholder`.
- **Apple Developer ID (blocks a public release).** 1) Join the Apple Developer Program ($99/year, developer.apple.com/programs). 2) Xcode › Settings › Accounts › Manage Certificates › + › "Developer ID Application"; export it from Keychain Access as a .p12 with a password. 3) In GitHub › Settings › Secrets and variables › Actions add: `DEVELOPER_ID_CERT_P12` (`base64 -i cert.p12 | pbcopy`), `DEVELOPER_ID_CERT_PASSWORD`, `APPLE_ID`, `APPLE_TEAM_ID` (developer.apple.com › Membership), `APPLE_APP_PASSWORD` (appleid.apple.com › App-Specific Passwords). 4) Push a tag `v0.2.0`; the Release workflow signs, runs `scripts/notarize.sh` for the app and the dmg, and publishes. 5) Download the dmg on another Mac and confirm it opens with no warning.
- Hardened runtime check (5 min): on the current build, confirm a Calendar widget shows events, the Sound Mixer turns one app down, ⌃⌥ arrow window shortcuts move a window, and Now Playing shows a playing track. All Set now always runs hardened; report anything that stopped working.
- Licence: LICENSE is proprietary "All rights reserved" in your name (Pratik Kansara, from git config). Confirm the name and the choice, or pick another licence.
- Lid Plane: if you want it back, the only legal route is licensing the whole app GPL-3.0. Decide, then `git revert c5192d2`.

## Blocked
