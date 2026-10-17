"""Three made-up wallpapers for the dev server (scripts/cloud/server.sh), so
there is something that may be published: this Mac's own library is all
quarantined, and none of it ever goes out.

    scripts/cloud/server.sh sample

Two short loops and a still, drawn by ffmpeg's own test patterns, so nobody
else's work is in them. Each gets its files in storage and a row marked
`published` with a license (CC0-1.0) and the source `dev-sample`. Run once;
a database that already has them is left as it is.

Never run this against the home server: --url and --storage are required so
it can't happen by default.
"""
import argparse
import hashlib
import json
import os
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import catalog_lock  # noqa: E402

PSQL = "/opt/homebrew/bin/psql" if os.path.exists("/opt/homebrew/bin/psql") else "psql"
FFMPEG = shutil.which("ffmpeg") or "/opt/homebrew/bin/ffmpeg"
SOURCE = "dev-sample"
WIDTH, HEIGHT, FPS, SECONDS = 1280, 720, 30, 4
# (title, kind, category, tags, ffmpeg test pattern)
SAMPLES = [
    ("Sample Gradient Drift", "video", "abstract", ["sample", "gradient", "live"], "gradients=speed=0.02:seed=7"),
    ("Sample Fractal Zoom", "video", "abstract", ["sample", "fractal", "live"], "mandelbrot"),
    ("Sample Colour Field", "image", "abstract", ["sample", "gradient"], "gradients=seed=21"),
]


def ffmpeg(*arguments):
    subprocess.run([FFMPEG, "-v", "error", "-y", *arguments], check=True)


def psql(url, script):
    result = subprocess.run([PSQL, url, "-q", "-At", "-v", "ON_ERROR_STOP=1", "-f", "-"],
                            input=script, capture_output=True, text=True)
    if result.returncode != 0:
        sys.exit(result.stderr.strip())
    return result.stdout.strip()


def quoted(value):
    return "null" if value is None else "'" + str(value).replace("'", "''") + "'"


def make(sample, work, storage):
    """Draws one sample, puts its files in storage and returns its row."""
    title, kind, category, tags, pattern = sample
    source = f"{pattern}{':' if '=' in pattern else '='}size={WIDTH}x{HEIGHT}:rate={FPS}"
    still = os.path.join(work, "still.jpg")
    if kind == "video":
        main = os.path.join(work, "loop.mp4")
        ffmpeg("-f", "lavfi", "-i", source, "-t", str(SECONDS), "-c:v", "libx264", "-pix_fmt", "yuv420p",
               "-movflags", "+faststart", main)
        ffmpeg("-i", main, "-frames:v", "1", "-q:v", "3", still)
    else:
        main = still
        ffmpeg("-f", "lavfi", "-i", source, "-frames:v", "1", "-q:v", "2", still)
    thumbnail = os.path.join(work, "thumbnail.jpg")
    ffmpeg("-i", still, "-vf", "scale=480:-2", "-q:v", "4", thumbnail)

    with open(main, "rb") as handle:
        id = hashlib.sha256(handle.read()).hexdigest()[:16]
    keys = {"playback_key": f"live/{id}.mp4" if kind == "video" else None,
            "still_key": f"stills/{id}.jpg", "thumbnail_key": f"thumbnails/{id}.jpg"}
    for column, made in (("playback_key", main), ("still_key", still), ("thumbnail_key", thumbnail)):
        if keys[column]:
            destination = os.path.join(storage, keys[column])
            os.makedirs(os.path.dirname(destination), exist_ok=True)
            shutil.copyfile(made, destination)
    return dict(keys, id=id, title=title, kind=kind, category=category,
                tags="{" + ",".join(tags) + "}", duration=SECONDS if kind == "video" else None,
                width=WIDTH, height=HEIGHT, fps=FPS if kind == "video" else None,
                size_bytes=os.path.getsize(main), status="published", content_rating="Everyone",
                provenance=json.dumps({"source": SOURCE, "author": "All Set dev sample", "license": "CC0-1.0"}))


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--url", required=True, help="the dev server's database")
    parser.add_argument("--storage", required=True, help="the dev server's storage/wallpapers folder")
    args = parser.parse_args()
    if not os.path.isdir(args.storage):
        sys.exit(f"{args.storage} isn't a folder")
    if psql(args.url, f"select count(*) from wallpapers where provenance->>'source' = '{SOURCE}';") != "0":
        print("The sample wallpapers are already there.")
        return

    work = tempfile.mkdtemp(prefix="allset-sample-")
    try:
        rows = [make(sample, work, args.storage) for sample in SAMPLES]
    finally:
        shutil.rmtree(work, ignore_errors=True)
    columns = list(rows[0])
    values = ",\n".join("(" + ", ".join(quoted(row[c]) for c in columns) + ", now())" for row in rows)
    # Rows that point at files, so under the catalog lock (catalog_lock.py); the
    # files are already in their places.
    psql(args.url, f"begin;\nselect pg_advisory_xact_lock({catalog_lock.ASSET_LOCK});\n"
                   f"insert into wallpapers ({', '.join(columns)}, added_at) values\n{values};\ncommit;\n")
    for row in rows:
        print(f"{row['id']}  {row['title']}")


if __name__ == "__main__":
    main()
