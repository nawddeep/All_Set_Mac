"""Bundle the theme photos listed in LicensedPhotos.swift instead of hotlinking them.

For every photo: ask Openverse for its record, keep it only if the licence is
CC0 or the Public Domain Mark, download it, shrink it to at most 1024 px with
`sips` (JPEG quality 60) into Sources/AllSetCore/Resources/ThemeArt as
`licensed-<id>.jpg`, and write the attribution list to
Documentation/third-party/licensed-photos.md. Photos that fail any step are
listed in the output with the reason; the Swift list is then rewritten to the
kept photos only, marked `provider: "bundled"` with no URLs.

Run from the repository root: /opt/homebrew/bin/python3 -I scripts/bundle_licensed_photos.py
Idempotent: photos already bundled are verified again but not downloaded again.
"""
import json
import os
import re
import subprocess
import sys
import time
import urllib.request

ROOT = os.getcwd()
SWIFT = os.path.join(ROOT, "Sources/AllSetCore/Aesthetics/LicensedPhotos.swift")
ART = os.path.join(ROOT, "Sources/AllSetCore/Resources/ThemeArt")
NOTICES = os.path.join(ROOT, "Documentation/third-party/licensed-photos.md")
ALLOWED = {"cc0", "pdm"}
UA = {"User-Agent": "AllSet/1.0 (macOS app; licence check)"}

BLOCK = re.compile(r'WebPhoto\(id: "(?P<id>[^"]+)".*?origin: "(?P<origin>[^"]*)"\)', re.S)


def get(url, attempts=4):
    for attempt in range(attempts):
        try:
            with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=30) as response:
                return response.read()
        except urllib.error.HTTPError as error:
            if error.code == 429 and attempt + 1 < attempts:
                time.sleep(int(error.headers.get("Retry-After") or 60))
                continue
            raise
    raise RuntimeError("unreachable")


def main():
    source = open(SWIFT, encoding="utf-8").read()
    blocks = list(BLOCK.finditer(source))
    records, dropped = {}, []
    for match in blocks:
        photo_id = match.group("id")
        if photo_id in records or any(d[0] == photo_id for d in dropped):
            continue
        text = match.group(0)
        url = re.search(r'imageURLString: "([^"]+)"', text)
        file = os.path.join(ART, f"licensed-{photo_id}.jpg")
        try:
            record = json.loads(get(f"https://api.openverse.org/v1/images/{photo_id}/"))
            time.sleep(3.2)  # Openverse allows anonymous bursts of about 20 a minute.
            licence = (record.get("license") or "").lower()
            if licence not in ALLOWED:
                dropped.append((photo_id, f"licence is {licence or 'missing'}"))
                continue
            if not os.path.exists(file):
                if not url:
                    dropped.append((photo_id, "no image address"))
                    continue
                raw = file + ".download"
                with open(raw, "wb") as out:
                    out.write(get(url.group(1)))
                subprocess.run(["sips", "-s", "format", "jpeg", "-s", "formatOptions", "60", "-Z", "1024", raw, "--out", file],
                               check=True, capture_output=True)
                os.remove(raw)
            records[photo_id] = record
            print(f"kept {photo_id} {licence}", flush=True)
        except Exception as error:  # noqa: BLE001 - every failure is reported, none stops the run
            dropped.append((photo_id, str(error)))
            if os.path.exists(file + ".download"):
                os.remove(file + ".download")

    # The Swift list: kept photos only, bundled, no addresses to fetch.
    def rewrite(match):
        photo_id = match.group("id")
        if photo_id not in records:
            return None
        text = match.group(0)
        text = re.sub(r'provider: "[^"]*"', 'provider: "bundled"', text)
        text = re.sub(r'\s*imageURLString: "[^"]*", thumbnailURLString: "[^"]*",', "", text)
        text = re.sub(r'\s*imageURLString: "[^"]*",', "", text)
        return text

    out, last = [], 0
    for match in blocks:
        replacement = rewrite(match)
        start = match.start()
        if replacement is None:
            # Drop the whole entry, including its trailing comma and line break.
            end = match.end()
            while end < len(source) and source[end] in ",":
                end += 1
            line_start = source.rfind("\n", 0, start) + 1
            out.append(source[last:line_start])
            last = end + 1 if source[end:end + 1] == "\n" else end
        else:
            out.append(source[last:start])
            out.append(replacement)
            last = match.end()
    out.append(source[last:])
    open(SWIFT, "w", encoding="utf-8").write("".join(out))

    os.makedirs(os.path.dirname(NOTICES), exist_ok=True)
    with open(NOTICES, "w", encoding="utf-8") as notes:
        notes.write("# Photos shipped with All Set\n\n")
        notes.write("Each photo below was checked against its Openverse record when it was bundled: every one is\n")
        notes.write("dedicated to the public domain (CC0 1.0) or marked public domain (Public Domain Mark 1.0).\n")
        notes.write("No attribution is required; it is given anyway.\n\n")
        notes.write("| File | Title | Creator | Licence | Source |\n|---|---|---|---|---|\n")
        for photo_id, record in sorted(records.items()):
            title = (record.get("title") or "").replace("|", "/")
            creator = (record.get("creator") or "Unknown").replace("|", "/")
            licence = f"{record.get('license', '').upper()} {record.get('license_version') or ''}".strip()
            notes.write(f"| licensed-{photo_id}.jpg | {title} | {creator} | {licence} | {record.get('foreign_landing_url') or ''} |\n")

    print(f"\nkept {len(records)}, dropped {len(dropped)}")
    for photo_id, reason in dropped:
        print(f"dropped {photo_id}: {reason}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
