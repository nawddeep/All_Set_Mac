# A backend for public wallpapers: the plan

Status: a plan, not built. Decision and provisioning are the owner's (OWNER_ACTIONS.md).

## Why not the current server
The library server (`operations.md`) is the owner's Mac on Tailscale: plain HTTP, Python's standard-library HTTP server, psql per request, one shared key. That is right for a few people the owner knows and wrong for strangers: no TLS, no scale, a home connection, and a single key that can't be handed to the public. It also holds Wallpaper Engine content that can never be published.

Public content needs no accounts, no database at request time and no server code.

## The shape
- **Content:** only wallpapers All Set owns outright or has a written licence to redistribute (commissioned or licensed, each with a record of its licence). Start with 30–50.
- **Files:** object storage behind a CDN: Cloudflare R2 (no egress fees) or S3 + CloudFront. Paths are content-addressed: `v1/<sha256>.mp4`, `v1/<sha256>.jpg`, so a file never changes once published and caches forever.
- **List:** one static `catalog.json` at a fixed URL (`https://cdn.example.com/v1/catalog.json`), the shape `publish_catalog.py` already writes (the app's `WallpaperLibraryCatalog`), with each file's SHA-256 and size. Short cache time (5 min) for the list, a year for the files.
- **Integrity:** the app already checks every download's SHA-256 against the list (`LibraryVideo.checksums`). Sign the list too: an Ed25519 signature in `catalog.json.sig`, the public key built into the app (the same approach Sparkle uses for updates), so a compromised bucket can't serve a different list.
- **No per-user tokens:** everything public is public. Signed URLs are only needed if paid or private content ever exists; then a small function (Cloudflare Worker / Lambda) hands out short-lived URLs.

## How the app consumes it
Already built: an app built with `ALLSET_PUBLIC_LIBRARY_URL` reads `<url>/catalog.json` with no key (`LibrarySync.update()`, `AppServices.startPublicLibrary`), shows the list with thumbnails, downloads a wallpaper when it's picked and checks its checksum. Left to add: the list signature check, and a section title ("All Set Library") next to Built in.

## Publishing
1. Add a licensed wallpaper to the catalog database with `status = 'published'` and its licence in `provenance`.
2. `publish_catalog.py` writes `catalog.json` and the files' hashes for published rows only (it already refuses rows without a licence).
3. Upload new files under their hash names (`rclone copy` or `aws s3 sync --size-only`), then the list, then the signature.
4. Purge the CDN cache for `catalog.json` only.

## Costs (rough, 2026 prices; check before buying)
| Item | Cloudflare R2 | S3 + CloudFront |
|---|---|---|
| Storage, 50 wallpapers × ~40 MB = 2 GB | ~$0.03/month | ~$0.05/month |
| Egress, 1,000 users × 10 downloads × 40 MB = 400 GB/month | $0 (R2 has no egress fee) | ~$34/month |
| Requests | free tier covers it | ~$1/month |
| Domain | ~$10/year | ~$10/year |

R2 is the default recommendation.

## Migration steps
1. Decide what content may be public, and get licences in writing (OWNER_ACTIONS).
2. Create the bucket and a custom domain with TLS; set CORS to GET only.
3. Generate the list-signing key pair; keep the private key offline or in the CI secret store.
4. Add the signature check to `LibrarySync` (tested with a fixture list), then build with `ALLSET_PUBLIC_LIBRARY_URL` pointing at the CDN.
5. Publish the first batch (above) and check a clean Mac downloads and plays it.
6. Leave the personal Tailscale server as it is for the owner's own library; nothing in the app needs it.
