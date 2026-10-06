#!/usr/bin/python3
"""All Set's live-wallpaper library tool.

    /usr/bin/python3 scripts/wallpaper_library.py inventory <folder>
    /usr/bin/python3 scripts/wallpaper_library.py import <folder>

`inventory` reads a folder of videos (a Wallpaper Engine / Steam Workshop
folder, or any folder of video files) without changing anything in it, and
writes `inventory.json` next to the app's wallpaper library: per file, its
duration, size, frame rate, codec, bit rate, audio, SHA-256, and whether it
plays.

`import` (see below) turns that into the catalog the app reads.

Needs ffprobe and ffmpeg (Homebrew `ffmpeg`). Runs with macOS's own Python
3; nothing to install from pip. Safe to run again: results are keyed by
file content, so a rerun updates entries instead of adding new ones.
"""

import argparse
import collections
import datetime
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys

VIDEO_EXTENSIONS = {".mp4", ".m4v", ".mov", ".webm", ".mkv", ".avi"}
DEFAULT_LIBRARY = os.path.expanduser("~/Library/Application Support/AllSet/Wallpaper/Library")


def tool(name):
    for candidate in (shutil.which(name), f"/opt/homebrew/bin/{name}", f"/usr/local/bin/{name}"):
        if candidate and os.path.exists(candidate):
            return candidate
    sys.exit(f"{name} not found: install it with `brew install ffmpeg`.")


FFPROBE = None
FFMPEG = None

# How long any one outside tool (ffprobe, ffmpeg, the texture decoder) may run
# on one file before it counts as failed: a corrupt file can make one spin.
TOOL_TIME_LIMIT = 300


def run_tool(command, timeout=TOOL_TIME_LIMIT, **kwargs):
    """subprocess.run with a deadline: a tool past it is killed, and the call
    answers like a failed run (code -9, the reason on stderr) so every caller's
    existing failure path handles it."""
    try:
        return subprocess.run(command, timeout=timeout, **kwargs)
    except subprocess.TimeoutExpired:
        empty = "" if kwargs.get("text") else b""
        reason = f"timed out after {timeout} s"
        return subprocess.CompletedProcess(command, -9, stdout=empty,
                                           stderr=reason if kwargs.get("text") else reason.encode())


def write_json_atomic(path, data, **kwargs):
    """Writes JSON next to `path` under a name of its own, then swaps it in:
    a fixed ".tmp" name let two runs write into the same file."""
    import tempfile
    folder = os.path.dirname(path) or "."
    descriptor, temporary = tempfile.mkstemp(prefix=os.path.basename(path) + ".", suffix=".tmp", dir=folder)
    try:
        with os.fdopen(descriptor, "w") as handle:
            json.dump(data, handle, **kwargs)
        os.replace(temporary, path)
    except BaseException:
        if os.path.exists(temporary):
            os.remove(temporary)
        raise


class LibraryBusy(Exception):
    pass


class library_lock:
    """Holds the library for one run that changes it (import, remove-duplicates):
    a second one at the same time would read the catalog, then overwrite the
    first's changes with its own."""

    def __init__(self, library):
        self.path = os.path.join(library, ".import.lock")

    def __enter__(self):
        import fcntl
        os.makedirs(os.path.dirname(self.path), exist_ok=True)
        self.handle = open(self.path, "w")
        try:
            fcntl.flock(self.handle, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            self.handle.close()
            raise LibraryBusy(f"another import is changing {os.path.dirname(self.path)}; try again when it finishes")
        return self

    def __exit__(self, *exc):
        import fcntl
        fcntl.flock(self.handle, fcntl.LOCK_UN)
        self.handle.close()


def sha256(path, chunk=8 << 20):
    digest = hashlib.sha256()
    with open(path, "rb") as handle:
        while True:
            block = handle.read(chunk)
            if not block:
                break
            digest.update(block)
    return digest.hexdigest()


def probe(path):
    """ffprobe's view of a file, or an error string."""
    result = run_tool([FFPROBE, "-v", "error", "-print_format", "json", "-show_format", "-show_streams", path],
                            capture_output=True, text=True)
    if result.returncode != 0:
        return None, (result.stderr.strip() or "ffprobe failed")[:300]
    try:
        return json.loads(result.stdout), None
    except json.JSONDecodeError:
        return None, "ffprobe output unreadable"


def decodes(path, seconds=2):
    """Whether the first seconds decode without errors (catches truncated or corrupt files)."""
    result = run_tool([FFMPEG, "-v", "error", "-xerror", "-t", str(seconds), "-i", path, "-f", "null", "-"],
                            capture_output=True, text=True)
    return result.returncode == 0, result.stderr.strip()[:300]


def fraction(text):
    try:
        top, bottom = text.split("/")
        return float(top) / float(bottom) if float(bottom) else 0.0
    except (ValueError, AttributeError):
        return 0.0


def orientation(width, height):
    if not width or not height:
        return "unknown"
    ratio = width / height
    if ratio >= 2.0:
        return "ultrawide"
    if ratio > 1.05:
        return "landscape"
    if ratio < 0.95:
        return "portrait"
    return "square"


def describe(path):
    """Metadata for one video file; `valid` says whether it can be a wallpaper."""
    entry = {"size": os.path.getsize(path), "extension": os.path.splitext(path)[1].lower()}
    info, error = probe(path)
    if info is None:
        entry.update(valid=False, problem=error)
        return entry
    streams = info.get("streams", [])
    video = next((s for s in streams if s.get("codec_type") == "video" and not s.get("disposition", {}).get("attached_pic")), None)
    audio = [s for s in streams if s.get("codec_type") == "audio"]
    fmt = info.get("format", {})
    duration = float(fmt.get("duration") or (video or {}).get("duration") or 0)
    if video is None:
        entry.update(valid=False, problem="no video stream")
        return entry
    width, height = int(video.get("width") or 0), int(video.get("height") or 0)
    rotation = 0
    for side in video.get("side_data_list", []) or []:
        if "rotation" in side:
            rotation = int(side["rotation"])
    if abs(rotation) in (90, 270):
        width, height = height, width
    entry.update(
        duration=round(duration, 3),
        width=width,
        height=height,
        fps=round(fraction(video.get("avg_frame_rate") or video.get("r_frame_rate") or "0/1"), 3),
        codec=video.get("codec_name"),
        profile=video.get("profile"),
        pixelFormat=video.get("pix_fmt"),
        bitRate=int(fmt.get("bit_rate") or video.get("bit_rate") or 0),
        container=fmt.get("format_name"),
        hasAudio=bool(audio),
        orientation=orientation(width, height),
    )
    if duration <= 0:
        entry.update(valid=False, problem="zero duration")
        return entry
    ok, error = decodes(path)
    entry.update(valid=ok, problem=None if ok else (error or "decode failed"))
    return entry


def workshop_items(root):
    """Wallpaper Engine's project.json per top-level folder, when present."""
    items = {}
    for name in sorted(os.listdir(root)):
        project = os.path.join(root, name, "project.json")
        if os.path.isfile(project):
            try:
                with open(project, encoding="utf-8-sig") as handle:
                    items[name] = json.load(handle)
            except (OSError, json.JSONDecodeError):
                items[name] = {"_unreadable": True}
    return items


def inventory(root, library):
    root = os.path.abspath(root)
    items = workshop_items(root)
    # Files already described (same path, size and modification time) aren't
    # probed or hashed again: a rerun over a large library takes seconds.
    previous = {}
    try:
        with open(os.path.join(library, "inventory.json")) as handle:
            old = json.load(handle)
        if old.get("root") == root:
            previous = {f["path"]: f for f in old.get("files", []) if f.get("sha256") and "mtime" in f}
    except (OSError, json.JSONDecodeError):
        pass
    files = []
    for folder, _, names in os.walk(root):
        for name in sorted(names):
            if os.path.splitext(name)[1].lower() in VIDEO_EXTENSIONS and not name.startswith("._"):
                files.append(os.path.join(folder, name))
    files.sort()
    print(f"{len(files)} video files under {root}", flush=True)
    records = []
    for index, path in enumerate(files, 1):
        relative = os.path.relpath(path, root)
        top = relative.split(os.sep)[0] if os.sep in relative else None
        project = items.get(top) if top else None
        record = {"path": relative}
        try:
            stat = os.stat(path)
            known = previous.get(relative)
            if known and known.get("size") == stat.st_size and known.get("mtime") == int(stat.st_mtime):
                record.update({k: v for k, v in known.items() if k not in ("path", "workshop")})
            else:
                record.update(describe(path))
                record["sha256"] = sha256(path)
                record["mtime"] = int(stat.st_mtime)
        except OSError as error:
            record.update(valid=False, problem=f"unreadable: {error}")
        if project is not None:
            record["workshop"] = {
                "id": top,
                "type": (project.get("type") or "").lower(),
                "title": project.get("title"),
                "tags": project.get("tags") or [],
                "contentRating": project.get("contentrating"),
                "isMainFile": project.get("file") == os.path.basename(path),
                "hasLicense": any(key in project for key in ("license", "licence", "copyright")),
            }
        records.append(record)
        print(f"  [{index}/{len(files)}] {'ok ' if record.get('valid') else 'BAD'} {relative}", flush=True)
    summary = {
        "root": root,
        "scannedAt": datetime.datetime.now().isoformat(timespec="seconds"),
        "workshopItems": {kind: sum(1 for p in items.values() if (p.get("type") or "").lower() == kind)
                          for kind in sorted({(p.get("type") or "").lower() for p in items.values()})},
        "files": records,
    }
    os.makedirs(library, exist_ok=True)
    with open(os.path.join(library, "inventory.json"), "w") as handle:
        json.dump(summary, handle, indent=1, ensure_ascii=False)
    report(summary)
    return summary


def report(summary):
    files = summary["files"]
    valid = [f for f in files if f.get("valid")]
    invalid = [f for f in files if not f.get("valid")]
    by_hash = {}
    for f in files:
        if f.get("sha256"):
            by_hash.setdefault(f["sha256"], []).append(f["path"])
    duplicates = {h: p for h, p in by_hash.items() if len(p) > 1}

    def count(key, rows):
        out = {}
        for row in rows:
            out[row.get(key)] = out.get(row.get(key), 0) + 1
        return dict(sorted(out.items(), key=lambda kv: -kv[1]))

    def resolution(row):
        w, h = row.get("width") or 0, row.get("height") or 0
        long = max(w, h)
        return "8K+" if long >= 7680 else "4K" if long >= 3840 else "1440p" if long >= 2560 else "1080p" if long >= 1920 else "720p" if long >= 1280 else "SD"

    total = sum(f["size"] for f in files)
    print("\n== inventory ==")
    print(f"workshop items by type: {summary['workshopItems']}")
    print(f"video files: {len(files)} ({total / 1e9:.2f} GB); valid {len(valid)}, invalid {len(invalid)}")
    print(f"exact duplicates: {len(duplicates)} groups, {sum(len(p) - 1 for p in duplicates.values())} extra copies")
    print(f"resolution: {count('res', [dict(r, res=resolution(r)) for r in valid])}")
    print(f"fps: {count('fpsBucket', [dict(r, fpsBucket=round(r.get('fps') or 0)) for r in valid])}")
    print(f"codec: {count('codec', valid)}")
    print(f"orientation: {count('orientation', valid)}")
    print(f"container: {count('extension', valid)}; with audio: {sum(1 for r in valid if r.get('hasAudio'))}")
    print("largest:")
    for row in sorted(files, key=lambda r: -r["size"])[:5]:
        print(f"  {row['size'] / 1e6:8.1f} MB  {row.get('width')}x{row.get('height')} {row.get('fps')} fps "
              f"{(row.get('bitRate') or 0) / 1e6:.1f} Mb/s  {row['path']}")
    for row in invalid:
        print(f"invalid: {row['path']}: {row.get('problem')}")


# MARK: Wallpaper Engine scenes

HERE = os.path.dirname(os.path.abspath(__file__))


def wetex_tool(library):
    """The texture decoder (scripts/wetex.swift), compiled once into the library."""
    source = os.path.join(HERE, "wetex.swift")
    binary = os.path.join(library, "bin", "wetex")
    if not os.path.exists(binary) or os.path.getmtime(binary) < os.path.getmtime(source):
        os.makedirs(os.path.dirname(binary), exist_ok=True)
        result = run_tool(["xcrun", "swiftc", "-O", source, "-o", binary], capture_output=True, text=True, timeout=900)
        if result.returncode != 0:
            sys.exit(f"couldn't compile wetex.swift:\n{result.stderr[:500]}")
    return binary


class PackageError(Exception):
    """A scene.pkg that doesn't describe itself consistently: truncated, or
    with entries pointing outside the file."""


class Package:
    """Files of a Wallpaper Engine scene: a scene.pkg archive, or loose files in
    the folder. The archive's own counts, offsets and lengths are checked
    against the file before anything is read; a loose file must be inside the
    scene's folder."""

    # Far above any real scene; a corrupt count can't make it loop for ever.
    MAX_ENTRIES = 100_000
    MAX_NAME = 4096

    def __init__(self, folder, name):
        import struct
        self.folder, self.entries, self.path = folder, {}, os.path.join(folder, name)
        if os.path.isfile(self.path):
            size = os.path.getsize(self.path)
            with open(self.path, "rb") as handle:
                def exactly(count):
                    data = handle.read(count)
                    if len(data) != count:
                        raise PackageError(f"{name} ends early")
                    return data

                def number():
                    return struct.unpack("<i", exactly(4))[0]

                def text():
                    count = number()
                    if not 0 <= count <= self.MAX_NAME:
                        raise PackageError(f"{name} has a name {count} bytes long")
                    return exactly(count).decode("utf-8", "replace")

                text()
                count = number()
                if not 0 <= count <= self.MAX_ENTRIES:
                    raise PackageError(f"{name} claims {count} files")
                raw = []
                for _ in range(count):
                    entry = text()
                    offset, length = struct.unpack("<ii", exactly(8))
                    raw.append((entry, offset, length))
                base = handle.tell()
            entries = {}
            for entry, offset, length in raw:
                if offset < 0 or length < 0 or base + offset + length > size:
                    raise PackageError(f"{name}: {entry} lies outside the file")
                entries[entry] = (base + offset, length)
            self.entries = entries

    def loose(self, name):
        """A loose file's path, only if it's inside the scene's folder."""
        if os.path.isabs(name):
            return None
        root = os.path.realpath(self.folder)
        path = os.path.realpath(os.path.join(root, name))
        return path if os.path.commonpath([root, path]) == root else None

    def has(self, name):
        if name in self.entries:
            return True
        path = self.loose(name)
        return path is not None and os.path.isfile(path)

    def read(self, name):
        if name in self.entries:
            offset, length = self.entries[name]
            with open(self.path, "rb") as handle:
                handle.seek(offset)
                return handle.read(length)
        path = self.loose(name)
        if path is None:
            raise KeyError(f"{name} is outside the scene folder")
        with open(path, "rb") as handle:
            return handle.read()

    def json(self, name):
        try:
            return json.loads(self.read(name).decode("utf-8-sig", "replace"))
        except (OSError, KeyError, json.JSONDecodeError, UnicodeDecodeError):
            return None


def value(field, default=None):
    """Scene values are plain, or {"user": …, "value": …} when bound to a setting."""
    if isinstance(field, dict):
        field = field.get("value", default)
    return default if field is None else field


def vector(field, default):
    field = value(field)
    if isinstance(field, str):
        try:
            parts = [float(p) for p in field.split()]
            return parts + default[len(parts):]
        except ValueError:
            return default
    if isinstance(field, (int, float)):
        return [float(field)] * len(default)
    return default


def decode_texture(package, name, work, wetex, frames=False):
    """A scene texture as a picture file (or frames, or an MP4), via wetex."""
    path = f"materials/{name}.tex"
    if not package.has(path):
        return None
    source = os.path.join(work, hashlib.sha1(path.encode()).hexdigest()[:12] + ".tex")
    with open(source, "wb") as handle:
        handle.write(package.read(path))
    command = [wetex, source, source[:-4] + ("-frames" if frames else "")] + (["--frames"] if frames else [])
    result = run_tool(command, capture_output=True, text=True)
    try:
        info = json.loads(result.stdout.strip().splitlines()[-1])
    except (IndexError, json.JSONDecodeError):
        return None
    return None if "error" in info else info


# The smallest movement that counts as the wallpaper moving: how much the most
# changed 1/144th of the picture differs across the loop, 0-255. Measured on
# rendered loops (docs/wallpaper-import.md): encoder noise on a static scene
# of a static picture measured 0.33, so 2.0 is six times that: a loop has to
# visibly move to beat the sharper still. Rain shimmering on water measured 2.5.
MOTION_VISIBLE = 2.0


def frame_movement(video, seconds):
    """How much the picture actually changes over the loop, where it changes
    most: the mean difference of the most-changed block of a 16x9 grid,
    between small grey copies of three frames, 0-255."""
    width, height, frames = 160, 90, []
    for at in (0.0, seconds / 3, 2 * seconds / 3):
        run = run_tool([FFMPEG, "-v", "error", "-ss", f"{at:.2f}", "-i", video, "-frames:v", "1",
                              "-vf", f"scale={width}:{height}", "-pix_fmt", "gray", "-f", "rawvideo", "-"], capture_output=True)
        if run.returncode != 0 or len(run.stdout) < width * height:
            return None
        frames.append(run.stdout)
    best = 0.0
    for a, b in ((0, 1), (0, 2), (1, 2)):
        x, y = frames[a], frames[b]
        for by in range(0, height, 10):
            for bx in range(0, width, 10):
                total = sum(abs(x[(by + j) * width + bx + i] - y[(by + j) * width + bx + i])
                            for j in range(10) for i in range(10))
                best = max(best, total / 100)
    return best


# ---------------------------------------------------------------------------
# Scene normalisation: a Wallpaper Engine scene as data that the renderer
# (scripts/wescene.swift) executes with the scene's own shaders. Nothing is
# invented: values are the scene's, effect defaults come from the shader the
# package ships, and whatever can't be carried is listed under "unsupported".
# ---------------------------------------------------------------------------

UNIFORM_DECLARATION = re.compile(r"uniform\s+(\w+)\s+(\w+)\s*(?:\[\s*\d+\s*\])?\s*;\s*//\s*(\{.*\})")
COMBO_DECLARATION = re.compile(r"//\s*\[COMBO\]\s*(\{.*\})")
# Texture header flags (TEXI): 1 draws without interpolation, 2 clamps UVs,
# 4 is a sprite sheet.
TEXTURE_NEAREST, TEXTURE_CLAMP, TEXTURE_SPRITES = 1, 2, 4
COMPONENTS = {"float": 1, "int": 1, "vec2": 2, "vec3": 3, "vec4": 4}


def scene_track(field, default):
    """A scene value as a track: its static value, plus its keyframes when the
    scene animates it (bezier keys per channel, in seconds, looped, mirrored
    or played once)."""
    static = [float(v) for v in vector(field, default)]
    track = {"value": static}
    animation = field.get("animation") if isinstance(field, dict) else None
    if isinstance(animation, dict):
        options = animation.get("options") or {}
        fps = float(options.get("fps") or 30) or 30.0
        channels = []
        for channel in range(len(static)):
            keys = []
            for key in animation.get(f"c{channel}") or []:
                if not isinstance(key, dict):
                    continue
                back, front = key.get("back") or {}, key.get("front") or {}
                keys.append({"t": float(key.get("frame", 0)) / fps, "v": float(key.get("value", static[channel])),
                             "inX": float(back.get("x", 0)) / fps if back.get("enabled", True) else 0.0,
                             "inY": float(back.get("y", 0)) if back.get("enabled", True) else 0.0,
                             "outX": float(front.get("x", 0)) / fps if front.get("enabled", True) else 0.0,
                             "outY": float(front.get("y", 0)) if front.get("enabled", True) else 0.0})
            channels.append(sorted(keys, key=lambda k: k["t"]))
        if any(channels):
            track.update(keys=channels, length=float(options.get("length") or 0) / fps,
                         mode=str(options.get("mode") or "loop"))
    return track


def texture_flags(package, name):
    raw = package.read(f"materials/{name}.tex")[:26] if package.has(f"materials/{name}.tex") else b""
    import struct
    return struct.unpack("<i", raw[22:26])[0] if len(raw) >= 26 and raw[9:17] == b"TEXI0001" else 0


def shader_interface(sources):
    """What a shader declares: material uniforms with their defaults, samplers,
    and combos with their defaults."""
    uniforms, samplers, combos = {}, {}, {}
    for source in sources:
        for line in source.splitlines():
            match = COMBO_DECLARATION.search(line)
            if match:
                try:
                    note = json.loads(match.group(1))
                except json.JSONDecodeError:
                    continue
                if note.get("combo"):
                    combos.setdefault(note["combo"], int(note.get("default", 0) or 0))
                continue
            match = UNIFORM_DECLARATION.search(line)
            if not match:
                continue
            kind, name, note_text = match.groups()
            try:
                note = json.loads(note_text)
            except json.JSONDecodeError:
                note = {}
            if kind == "sampler2D":
                samplers[name] = note
            elif kind in COMPONENTS:
                uniforms[name] = (kind, note)
    return uniforms, samplers, combos


# Particle parts the renderer simulates from the scene's own numbers. Anything
# else in a particle system is listed as unsupported, never guessed at.
PARTICLE_INITIALIZERS = {"lifetimerandom", "sizerandom", "colorrandom", "alpharandom", "velocityrandom",
                         "rotationrandom", "angularvelocityrandom"}
PARTICLE_OPERATORS = {"movement", "alphafade", "sizechange", "alphachange", "colorchange", "oscillatealpha",
                      "oscillatesize", "oscillateposition", "angularmovement"}
PARTICLE_RENDERERS = {"sprite", "spritetrail"}


# Wallpaper Engine's own particle sprites ship with the engine, not the scene,
# and are its art: the renderer draws a stand-in of the same kind instead.
PARTICLE_SPRITE_FAMILIES = [
    ("drop", ("drop", "rain", "streak", "line")),
    ("fog", ("fog", "smoke", "cloud", "mist", "dust", "steam", "fire", "flame")),
    ("beam", ("beam", "shaft", "ray")),
    ("halo", ("halo", "glow", "dot", "circle", "spark", "star", "snow", "flake", "bokeh", "light", "orb", "ember", "petal", "leaf", "debris", "ash", "bubble", "chunk")),
]


def particle_sprite(name):
    """The stand-in family for an engine particle sprite, or None."""
    lowered = name.lower()
    for family, words in PARTICLE_SPRITE_FAMILIES:
        if any(word in lowered for word in words):
            return family
    return None


def plain(node):
    """Scene numbers as plain numbers: "1 2 3" becomes [1, 2, 3], and a value
    bound to a user setting becomes that setting's value."""
    if isinstance(node, dict):
        if "value" in node and ("user" in node or "animation" in node or "script" in node):
            return plain(node["value"])
        return {k: plain(v) for k, v in node.items()}
    if isinstance(node, list):
        return [plain(v) for v in node]
    if isinstance(node, str):
        try:
            parts = [float(p) for p in node.split()]
            return parts if len(parts) > 1 else (parts[0] if parts else node)
        except ValueError:
            return node
    if isinstance(node, bool):
        return node
    if isinstance(node, (int, float)):
        return float(node)
    return node


class SceneNormaliser:
    """Turns one scene package into the renderer's input, with a report of
    everything it couldn't carry over."""

    def __init__(self, folder, project, work, wetex):
        self.folder, self.project, self.work, self.wetex = folder, project, work, wetex
        name = project.get("file") or "scene.json"
        self.package = Package(folder, os.path.splitext(name)[0] + ".pkg")
        self.scene = self.package.json(name) or {}
        self.unsupported = collections.Counter()
        self.missing = []
        self.shaders = {}
        self.decoded = {}

    def note(self, what):
        self.unsupported[what] += 1

    def save_shader(self, source):
        key = hashlib.sha1(source.encode()).hexdigest()[:12]
        if key not in self.shaders:
            path = os.path.join(self.work, f"shader-{key}.glsl")
            with open(path, "w") as handle:
                handle.write(source)
            self.shaders[key] = path
        return self.shaders[key]

    def texture(self, name):
        """What a texture name refers to: a picture, frames, a built-in, or a
        render target. None when the picture isn't in the package."""
        if not isinstance(name, str) or not name:
            return None
        if name.startswith("util/"):
            return {"builtin": name[5:]}
        if name.startswith("_rt_"):
            match = re.match(r"_rt_imageLayerComposite_(\d+)_[ab]$", name)
            if match:
                return {"layer": int(match.group(1))}
            if name == "_rt_FullFrameBuffer":
                return {"scene": True}
            return {"fbo": name}
        if name in self.decoded:
            return self.decoded[name]
        flags = texture_flags(self.package, name)
        result = None
        if flags & TEXTURE_SPRITES:
            info = decode_texture(self.package, name, self.work, self.wetex, frames=True)
            if info and info.get("kind") == "frames" and info.get("count"):
                result = {"frames": [{"file": os.path.join(info["dir"], f"frame-{i:04d}.png"), "duration": max(float(d), 0.02)}
                                     for i, d in enumerate(info["times"], 1)]}
                result["format"] = info.get("format")
        if result is None:
            info = decode_texture(self.package, name, self.work, self.wetex)
            if info and info.get("kind") == "image":
                result = {"file": info["file"], "width": info["width"], "height": info["height"], "format": info.get("format")}
        if result is None:
            self.missing.append(name)
        else:
            result.update(clamp=bool(flags & TEXTURE_CLAMP), nearest=bool(flags & TEXTURE_NEAREST))
        self.decoded[name] = result
        return result

    def effect(self, entry, material_pass=None, kind=None):
        """One effect as passes of the scene's own shaders. `material_pass` is
        used for an object's own non-generic shader, run as its first effect."""
        scene_passes = entry.get("passes") or []
        if material_pass is not None:
            spec = {"passes": [{"inline": material_pass}]}
        else:
            path = entry.get("file") or ""
            kind = path.split("/")[-2] if path.endswith("effect.json") else path
            spec = self.package.json(path)
            if not spec:
                self.note(f"effect {kind}: definition not in the package")
                return None
        fbos = [{"name": f.get("name"), "scale": float(f.get("scale") or 1)} for f in spec.get("fbos") or [] if f.get("name")]
        passes, timed = [], False
        for index, step in enumerate(spec.get("passes") or []):
            if "inline" in step:
                mpass = step["inline"]
            else:
                material = self.package.json(step.get("material", "")) or {}
                mpass = (material.get("passes") or [{}])[0]
            shader = mpass.get("shader")
            vert = self.package.read(f"shaders/{shader}.vert").decode("utf-8", "replace") if shader and self.package.has(f"shaders/{shader}.vert") else None
            frag = self.package.read(f"shaders/{shader}.frag").decode("utf-8", "replace") if shader and self.package.has(f"shaders/{shader}.frag") else None
            if not vert or not frag:
                self.note(f"effect {kind}: shader {shader} not in the package")
                return None
            timed = timed or "g_Time" in vert or "g_Time" in frag
            declared, samplers, combos = shader_interface([vert, frag])
            overrides = scene_passes[index] if index < len(scene_passes) and isinstance(scene_passes[index], dict) else {}
            combos.update({k: int(value(v, 0)) for k, v in (mpass.get("combos") or {}).items()})
            combos.update({k: int(value(v, 0)) for k, v in (overrides.get("combos") or {}).items()})
            values = dict(mpass.get("constantshadervalues") or {})
            values.update(overrides.get("constantshadervalues") or {})
            uniforms = {}
            for name, (typ, note) in declared.items():
                key = note.get("material")
                if not key:
                    continue
                default = vector(note.get("default", 0), [0.0] * COMPONENTS[typ])
                uniforms[name] = scene_track(values.get(key, note.get("default", 0)), default)
            textures = {}
            defaults = list(mpass.get("textures") or [])
            chosen = list(overrides.get("textures") or [])
            for sampler, note in samplers.items():
                match = re.match(r"g_Texture(\d+)$", sampler)
                if not match:
                    continue
                slot = int(match.group(1))
                name = chosen[slot] if slot < len(chosen) and chosen[slot] else None
                given = name is not None
                if name is None and slot < len(defaults) and defaults[slot]:
                    name = defaults[slot]
                if slot == 0 and name is None:
                    textures["0"] = {"previous": True}
                    continue
                if name is None:
                    name = note.get("default")
                resolved = self.texture(name)
                if resolved is None and name is not None:
                    self.note(f"effect {kind}: texture {name} not in the package")
                    return None
                if resolved is not None:
                    textures[str(slot)] = resolved
                # Wallpaper Engine switches a texture's combo on when one is chosen.
                if given and note.get("combo"):
                    combos[note["combo"]] = 1
            for binding in step.get("bind") or []:
                slot = str(int(binding.get("index", 0)))
                textures[slot] = {"previous": True} if binding.get("name") == "previous" else self.texture(binding.get("name"))
            passes.append({"vert": self.save_shader(vert), "frag": self.save_shader(frag), "combos": combos,
                           "uniforms": uniforms, "textures": textures, "target": step.get("target"),
                           "blending": mpass.get("blending", "normal")})
        return {"kind": kind, "fbos": fbos, "passes": passes, "timed": timed}

    def particle_system(self, path, override, depth=0):
        """One particle system, as the renderer simulates it, plus its
        children that sit alongside it. Returns a list (the system first)."""
        system = self.package.json(path) if isinstance(path, str) else None
        if not system:
            self.note("particle system not in the package")
            return []
        material = self.package.json(system.get("material", "")) or {}
        mpass = (material.get("passes") or [{}])[0]
        name = (mpass.get("textures") or [None])[0]
        texture = None
        if isinstance(name, str) and self.package.has(f"materials/{name}.tex"):
            texture = self.texture(name)
        elif isinstance(name, str) and name.startswith("particle/") and particle_sprite(name):
            texture = {"builtin": f"particle:{particle_sprite(name)}"}
            self.note(f"engine particle sprites (stand-ins drawn): {particle_sprite(name)}")
        if texture is None or texture.get("builtin") in ("white", "black", "clear"):
            self.note(f"particle system without its texture ({name})")
            return []
        shader = mpass.get("shader") or ""
        if shader and not shader.startswith("genericparticle") and not shader.startswith("genericropeparticle"):
            self.note(f"particle shader {shader} (drawn as a plain textured particle)")
        for section, known in (("initializer", PARTICLE_INITIALIZERS), ("operator", PARTICLE_OPERATORS),
                               ("renderer", PARTICLE_RENDERERS)):
            for part in system.get(section) or []:
                name = part.get("name") if isinstance(part, dict) else None
                if name == "turbulentvelocityrandom":
                    continue    # handled: a random starting direction at its speed
                if name in ("rope", "ropetrail"):
                    self.note(f"particle {name} renderer (drawn as trails)")
                elif name not in known:
                    self.note(f"particle {section} {name}")
        for emitter in system.get("emitter") or []:
            if (emitter or {}).get("name") not in ("boxrandom", "sphererandom"):
                self.note(f"particle emitter {(emitter or {}).get('name')}")
        refract = None
        if int(value((mpass.get("combos") or {}).get("REFRACT", 0), 0) or 0):
            names = mpass.get("textures") or []
            normal = names[1] if len(names) > 1 else None
            if isinstance(normal, str) and self.package.has(f"materials/{normal}.tex"):
                refract = self.texture(normal)
            else:
                self.note("refracting particles without their normal map")
                return []
        systems = [{"texture": texture, "blending": mpass.get("blending") or "translucent", "refract": refract,
                    "maxcount": float(value(system.get("maxcount"), 64) or 64),
                    "emitter": plain(system.get("emitter") or []), "initializer": plain(system.get("initializer") or []),
                    "operator": plain(system.get("operator") or []), "renderer": plain(system.get("renderer") or []),
                    "animationmode": system.get("animationmode") or "",
                    "sequencemultiplier": float(value(system.get("sequencemultiplier"), 1) or 1),
                    "override": plain(override or {})}]
        for child in system.get("children") or []:
            kind = (child or {}).get("type") or "static"
            if kind != "static" or depth > 3:
                self.note(f"particle children '{kind}' (spawned by events)")
                continue
            systems += self.particle_system(child.get("name"), override, depth + 1)
        return systems

    def normalise(self):
        general = self.scene.get("general") or {}
        projection = general.get("orthogonalprojection") or {}
        canvas = [int(projection.get("width") or 0), int(projection.get("height") or 0)]
        clear = [float(c) for c in vector(general.get("clearcolor"), [0.0, 0.0, 0.0])[:3]]
        objects = [o for o in self.scene.get("objects") or [] if isinstance(o, dict)]
        by_id = {o.get("id"): o for o in objects}
        if value(general.get("cameraparallax"), False):
            self.note("camera parallax (follows the mouse; nothing to follow here)")
        if value(general.get("camerashake"), False):
            self.note("camera shake (engine-side, not described by the scene)")
        scripted = []

        def find_scripts(node, path):
            if isinstance(node, dict):
                if isinstance(node.get("script"), str):
                    scripted.append(path)
                for key, child in node.items():
                    find_scripts(child, f"{path}.{key}")
            elif isinstance(node, list):
                for child in node:
                    find_scripts(child, path)
        find_scripts(self.scene.get("objects"), "objects")
        self.scripted = len(scripted)
        if scripted:
            self.note(f"SceneScript-driven values (code isn't run here): {len(scripted)}")

        def chain(obj):
            nodes, seen, current = [], set(), obj
            while current is not None and id(current) not in seen and len(nodes) < 16:
                seen.add(id(current))
                nodes.append({"origin": scene_track(current.get("origin"), [0.0, 0.0, 0.0]),
                              "scale": scene_track(current.get("scale"), [1.0, 1.0, 1.0]),
                              "angles": scene_track(current.get("angles"), [0.0, 0.0, 0.0])})
                current = by_id.get(current.get("parent"))
            return list(reversed(nodes))

        layers = []
        for obj in objects:
            kind = next((k for k in ("image", "particle", "text", "sound", "light", "model")
                         if obj.get(k) is not None), "other")
            if kind == "particle" and isinstance(obj.get("particle"), str):
                hidden = not value(obj.get("visible"), True)
                for system in self.particle_system(obj["particle"], obj.get("instanceoverride")):
                    layers.append({"id": None, "name": str(obj.get("name") or "particles"), "alignment": "center",
                                   "chain": chain(obj), "alpha": scene_track(obj.get("alpha"), [1.0]),
                                   "color": scene_track(obj.get("color"), [1.0, 1.0, 1.0]),
                                   "brightness": scene_track(obj.get("brightness"), [1.0]), "colorBlendMode": 0,
                                   "blending": system["blending"], "effects": [], "size": [1.0, 1.0],
                                   "hidden": hidden, "particles": system})
                continue
            if kind != "image" or not isinstance(obj.get("image"), str):
                self.note(f"{kind} object")
                continue
            alpha = scene_track(obj.get("alpha"), [1.0])
            # Hidden layers stay available to other layers' effects (some exist
            # only for that); the renderer never draws them itself.
            hidden = not value(obj.get("visible"), True) or ("keys" not in alpha and alpha["value"][0] <= 0.001)
            model = self.package.json(obj["image"]) or {}
            material = self.package.json(model.get("material", "")) or {}
            mpass = (material.get("passes") or [{}])[0]
            base_name = (mpass.get("textures") or [None])[0]
            layer = {"id": obj.get("id"), "name": str(obj.get("name") or ""), "alignment": str(obj.get("alignment") or "center"),
                     "chain": chain(obj), "alpha": alpha, "color": scene_track(obj.get("color"), [1.0, 1.0, 1.0]),
                     "brightness": scene_track(obj.get("brightness"), [1.0]),
                     "colorBlendMode": int(value(obj.get("colorBlendMode"), 0) or 0),
                     "blending": mpass.get("blending", "translucent"), "effects": [], "hidden": hidden}
            if obj["image"].endswith("util/solidlayer.json"):
                layer["solid"] = True
                size = vector(obj.get("size"), [float(canvas[0]), float(canvas[1])])
            elif model.get("fullscreen"):
                # Drawn over the whole frame, on what's been drawn so far.
                layer["background"] = True
                layer["chain"] = [{"origin": {"value": [canvas[0] / 2, canvas[1] / 2, 0.0]}, "scale": {"value": [1.0, 1.0, 1.0]},
                                   "angles": {"value": [0.0, 0.0, 0.0]}}]
                size = [float(canvas[0]), float(canvas[1])]
            elif isinstance(base_name, str) and base_name.startswith("_rt_"):
                # Its picture is a render target (what's behind it). The
                # "copybackground" flag isn't this: it only lets effects read
                # the background, and 377 ordinary layers carry it.
                layer["background"] = True
                size = vector(obj.get("size"), [float(model.get("width") or 0), float(model.get("height") or 0)])
            else:
                base = self.texture(base_name)
                if base is None or "builtin" in base:
                    self.note("image layer without its picture")
                    continue
                layer.update(texture=base)
                first = base.get("file") or (base.get("frames") or [{}])[0].get("file")
                width, height = base.get("width"), base.get("height")
                if not width and first:
                    width, height = image_size(first)
                size = vector(obj.get("size"), [float(model.get("width") or width or 0), float(model.get("height") or height or 0)])
            layer["size"] = [float(size[0]), float(size[1])]
            if size[0] < 1 or size[1] < 1:
                continue
            shader = mpass.get("shader") or ""
            if shader and not shader.startswith("genericimage") and not layer.get("solid"):
                own = self.effect({}, material_pass=mpass, kind=f"object shader {shader}")
                if own:
                    layer["effects"].append(own)
            for entry in obj.get("effects") or []:
                if not isinstance(entry, dict) or not value(entry.get("visible"), True):
                    continue
                effect = self.effect(entry)
                if effect:
                    layer["effects"].append(effect)
            if layer["colorBlendMode"]:
                self.note(f"colour blend mode {layer['colorBlendMode']} (engine enum not shipped; assumed)")
            layers.append(layer)
        return {"canvas": canvas, "clear": clear, "layers": layers}

    def report(self):
        return {"unsupported": dict(self.unsupported), "missing": sorted(set(self.missing)),
                "scripted": getattr(self, "scripted", 0)}


def image_size(path):
    result = run_tool([FFPROBE, "-v", "error", "-select_streams", "v", "-show_entries", "stream=width,height",
                             "-of", "csv=p=0", path], capture_output=True, text=True)
    try:
        width, height = [int(v) for v in result.stdout.strip().split(",")[:2]]
        return width, height
    except ValueError:
        return None, None


# How fast each effect's time runs, from its own speed uniform: only used to
# choose a loop length that its cycles fit. The rendering itself never uses this.
EFFECT_PERIODS = {
    "foliagesway": ("g_Speed", lambda s: 2 * 3.141592653589793 / s),
    "waterwaves": ("g_Speed", lambda s: 2 * 3.141592653589793 / s),
    "shake": ("g_Speed", lambda s: 2 * 3.141592653589793 / s),
    "pulse": ("g_PulseSpeed", lambda s: 2 * 3.141592653589793 / s),
    "waterflow": ("g_FlowSpeed", lambda s: 1 / s),
    "scroll": ("g_ScrollX", lambda s: 1 / (s * s)),
}


def effect_period(effect):
    known = EFFECT_PERIODS.get(effect["kind"])
    if not known:
        return None
    name, period = known
    for step in effect["passes"]:
        speed = step["uniforms"].get(name, {}).get("value", [0.0])[0]
        if abs(speed) > 1e-6:
            return abs(period(abs(speed)))
    return None


def track_period(track):
    if "keys" not in track or not track.get("length"):
        return None
    return track["length"] * (2 if track.get("mode") == "mirror" else 1)


STEADY_STATE = 60.0


def plan_loop(normalised, low=10, high=30, tolerance=0.04):
    """Picks a loop length that the scene's own cycles fit, then gives each
    timed part the smallest speed change (≤ tolerance) that makes it land on
    a whole number of cycles. What can't be fitted is joined by a short
    crossfade instead of being changed further. Returns whether anything moves."""
    parts = []   # (holder dict, period)

    def add(holder, period):
        if period and period > 0:
            parts.append((holder, period))

    moving = False
    for layer in normalised["layers"]:
        if layer.get("hidden"):
            continue
        for track_holder in [layer, *layer["chain"]]:
            for key in ("alpha", "color", "brightness", "origin", "scale", "angles"):
                track = track_holder.get(key)
                if isinstance(track, dict) and "keys" in track:
                    moving = True
                    add(track, track_period(track))
        if layer.get("particles"):
            moving = True    # periodic by construction, for any loop length
        frames = (layer.get("texture") or {}).get("frames")
        if frames and len(frames) > 1:
            moving = True
            add(layer["texture"], sum(f["duration"] for f in frames))
        for effect in layer["effects"]:
            if effect["timed"]:
                moving = True
                add(effect, effect_period(effect))
            for step in effect["passes"]:
                for track in step["uniforms"].values():
                    if "keys" in track:
                        moving = True
                        add(track, track_period(track))
    if not moving:
        return False
    best = None
    for seconds in range(low, high + 1):
        misses = 0.0
        for _, period in parts:
            count = round(seconds / period)
            error = abs(count * period / seconds - 1) if count >= 1 else 1.0
            misses += error if error > tolerance else error * 0.1
        score = misses + seconds * 0.002
        if best is None or score < best[0]:
            best = (score, seconds)
    seconds = best[1]
    for holder, period in parts:
        count = round(seconds / period)
        error = abs(count * period / seconds - 1) if count >= 1 else 1.0
        holder["timeScale"] = count * period / seconds if error <= tolerance else 1.0
    normalised["seconds"] = float(seconds)
    normalised["crossfade"] = 1.0
    # Recorded from a minute after load: one-shot start-up animations (intros,
    # fade-ins) are over, and this is what's on screen almost all the time.
    # Cycles that fit the loop are unaffected by where it starts.
    normalised["start"] = STEADY_STATE
    return True


def wescene_tool(library):
    """The scene renderer (scripts/wescene.swift), compiled once into the library."""
    source = os.path.join(HERE, "wescene.swift")
    binary = os.path.join(library, "bin", "wescene")
    if not os.path.exists(binary) or os.path.getmtime(binary) < os.path.getmtime(source):
        os.makedirs(os.path.dirname(binary), exist_ok=True)
        result = run_tool(["xcrun", "swiftc", "-O", "-Xcc", "-DGL_SILENCE_DEPRECATION", source, "-o", binary],
                                capture_output=True, text=True)
        if result.returncode != 0:
            sys.exit(f"couldn't compile wescene.swift:\n{result.stderr[:800]}")
    return binary


# A scene that takes longer than this is recorded as failed, not waited on.
RENDER_TIME_LIMIT = 600


def render_scene(normalised, output, library, work, still=False):
    """Runs the renderer on a normalised scene. Returns (result, problem)."""
    path = os.path.join(work, "normalised.json")
    with open(path, "w") as handle:
        json.dump(normalised, handle)
    command = [wescene_tool(library), path, output] + (["--still", "--width", "3840"] if still else ["--width", "2560"])
    try:
        result = subprocess.run(command, capture_output=True, text=True, timeout=RENDER_TIME_LIMIT)
    except subprocess.TimeoutExpired:
        return None, f"rendering took over {RENDER_TIME_LIMIT} s"
    try:
        info = json.loads(result.stdout.strip().splitlines()[-1])
    except (IndexError, json.JSONDecodeError):
        return None, (result.stderr.strip()[-300:] or "renderer failed")
    return (None, info["error"]) if "error" in info else (info, None)


def inspect_scene(folder, library, output=None):
    """What a scene contains and what the renderer can't carry over: layers,
    effects and their passes, animated values, sprite sheets, missing assets,
    the loop plan. With `output`, renders it too."""
    import tempfile
    project = json.load(open(os.path.join(folder, "project.json"), encoding="utf-8", errors="replace"))
    with tempfile.TemporaryDirectory() as work:
        normaliser = SceneNormaliser(folder, project, work, wetex_tool(library))
        normalised = normaliser.normalise()
        moving = plan_loop(normalised)
        report = normaliser.report()
        print(f"{project.get('title')}  canvas {normalised['canvas'][0]}x{normalised['canvas'][1]}")
        tracks = sum(1 for l in normalised["layers"] for h in [l, *l["chain"]]
                     for k in ("alpha", "color", "brightness", "origin", "scale", "angles")
                     if isinstance(h.get(k), dict) and "keys" in h[k])
        for layer in normalised["layers"]:
            what = ("solid" if layer.get("solid") else "background" if layer.get("background")
                    else f"{len(layer['texture']['frames'])} frames" if layer.get("texture", {}).get("frames") else "picture")
            effects = ", ".join(f"{e['kind']}({len(e['passes'])}p{', timed' if e['timed'] else ''}"
                                f"{', x%.3f' % e['timeScale'] if 'timeScale' in e else ''})" for e in layer["effects"])
            print(f"  {layer['name'][:28]:28s} {what:10s} {int(layer['size'][0])}x{int(layer['size'][1])} {layer['alignment']:8s} {effects}")
        print(f"animated values: {tracks}; moves: {moving}"
              + (f"; loop {normalised['seconds']:.0f} s, crossfade {normalised['crossfade']} s" if moving else ""))
        print("unsupported:", report["unsupported"] or "nothing")
        print("missing assets:", report["missing"] or "none")
        if output:
            info, problem = render_scene(normalised, output, library, work, still=not moving or output.endswith(".jpg"))
            print("render:", problem or info)


def is_blank(path):
    """True for a picture with essentially nothing in it: uniformly near-black
    (or near-white). Some scenes lean on a feature this renderer doesn't carry
    (a 3D model is the common case) and come out with only their background
    layer, or nothing at all - a real wallpaper isn't this, however dark or
    minimal its actual art may be. Threshold picked from real examples: the
    darkest legitimate art measured (a faint ink-style illustration, almost
    silhouette) sat at mean 0.38; every confirmed-blank render sat at 0.19 or
    under, mean of a 32x18 greyscale downscale, 0-255 scale."""
    result = run_tool([FFMPEG, "-v", "error", "-i", path, "-frames:v", "1", "-vf", "scale=32:18,format=gray",
                             "-f", "rawvideo", "-"], capture_output=True)
    pixels = result.stdout
    if len(pixels) < 32 * 18:
        return False  # unreadable: let the normal "couldn't render" path handle it
    mean = sum(pixels) / len(pixels)
    return mean < 0.3 or mean > 254.7


def preview_hash(folder, project):
    """The Workshop preview's difference hash, to check a composed still against."""
    preview = os.path.join(folder, project.get("preview") or "preview.jpg")
    for candidate in (preview, os.path.join(folder, "preview.jpg"), os.path.join(folder, "preview.gif")):
        if os.path.isfile(candidate):
            return dhash(candidate)
    return None


def gif_video(package, texture, work, wetex, output):
    """A GIF scene's frames as a looping H.264 video, pixels kept sharp when scaled up."""
    info = decode_texture(package, texture, work, wetex, frames=True)
    if not info or info.get("kind") != "frames" or not info.get("count"):
        return "no frames"
    listing = os.path.join(info["dir"], "frames.txt")
    with open(listing, "w") as handle:
        for index, duration in enumerate(info["times"], 1):
            handle.write(f"file 'frame-{index:04d}.png'\nduration {max(duration, 0.02):.3f}\n")
        handle.write(f"file 'frame-{len(info['times']):04d}.png'\n")
    first = os.path.join(info["dir"], "frame-0001.png")
    result = run_tool([FFPROBE, "-v", "error", "-select_streams", "v", "-show_entries", "stream=width,height", "-of", "csv=p=0", first],
                            capture_output=True, text=True)
    try:
        w, h = [int(v) for v in result.stdout.strip().split(",")[:2]]
    except ValueError:
        return "unreadable frames"
    factor = max(1, int(2160 / h))
    result = run_tool([FFMPEG, "-v", "error", "-y", "-f", "concat", "-safe", "0", "-i", listing,
                             "-vf", f"scale={w * factor}:{h * factor}:flags=neighbor,format=yuv420p,fps=30",
                             "-c:v", "h264_videotoolbox", "-b:v", "12M", "-movflags", "+faststart", output],
                            capture_output=True, text=True)
    return None if result.returncode == 0 else result.stderr.strip()[-300:]


def import_scene(folder, project, library, wetex, item_id, live=True):
    """A still (or, for GIF scenes and video textures, a video) for one scene.
    Returns (entry fields, problem)."""
    import tempfile
    file_name = project.get("file") or "scene.json"
    try:
        package = Package(folder, os.path.splitext(file_name)[0] + ".pkg")
    except PackageError as error:
        return None, f"damaged package: {error}"
    scene = package.json(file_name)
    if scene is None:
        return None, "no scene description"
    general = scene.get("general") or {}
    projection = general.get("orthogonalprojection") or {}
    canvas = (int(projection.get("width") or 0), int(projection.get("height") or 0))
    clear_rgb = vector(general.get("clearcolor"), [0.0, 0.0, 0.0])
    clear = "".join(f"{max(0, min(255, int(c * 255))):02x}" for c in clear_rgb[:3])
    with tempfile.TemporaryDirectory() as work:
        # A video texture inside: that's the wallpaper. The biggest one, since
        # smaller ones are masks and overlays for it.
        # Only when that video is the picture: a visible layer covering most
        # of the scene. A small one (a loading intro, a screen in the corner)
        # is just part of a scene that's rendered like any other.
        covering = {}
        width, height = max(canvas[0], 1), max(canvas[1], 1)
        for obj in scene.get("objects") or []:
            if not isinstance(obj, dict) or not isinstance(obj.get("image"), str) or not value(obj.get("visible"), True):
                continue
            model = package.json(obj["image"]) or {}
            material = package.json(model.get("material", "")) or {}
            texture = ((material.get("passes") or [{}])[0].get("textures") or [None])[0]
            if isinstance(texture, str):
                size, scale = vector(obj.get("size"), [0.0, 0.0]), vector(obj.get("scale"), [1.0, 1.0, 1.0])
                share = abs(size[0] * scale[0] * size[1] * scale[1]) / (width * height)
                covering[f"materials/{texture}.tex"] = max(covering.get(f"materials/{texture}.tex", 0.0), share)
        videos = []
        for name in [n for n in package.entries if n.endswith(".tex")]:
            if covering.get(name, 0.0) < 0.6:
                continue
            info = decode_texture(package, name[len("materials/"):-4], work, wetex) if name.startswith("materials/") else None
            if info and info.get("kind") == "mp4":
                videos.append((os.path.getsize(info["file"]), info["file"]))
        if videos:
            output = os.path.join(library, "extracted", f"{item_id}.mp4")
            os.makedirs(os.path.dirname(output), exist_ok=True)
            shutil.copyfile(max(videos)[1], output)
            return {"kind": "video", "playback": f"extracted/{item_id}.mp4", "source": "video texture"}, None
        if file_name.startswith("gifscene"):
            obj = next((o for o in scene.get("objects", []) if isinstance(o, dict) and isinstance(o.get("image"), str)
                        and "util/" not in o["image"]), None)
            model = package.json(obj["image"]) if obj else {}
            material = package.json((model or {}).get("material", "")) or {}
            texture = ((material.get("passes") or [{}])[0].get("textures") or [None])[0]
            output = os.path.join(library, "extracted", f"{item_id}.mp4")
            os.makedirs(os.path.dirname(output), exist_ok=True)
            problem = gif_video(package, texture, work, wetex, output) if texture else "no texture"
            if problem:
                return None, f"GIF scene: {problem}"
            return {"kind": "video", "playback": f"extracted/{item_id}.mp4", "source": "gif frames"}, None
        # Everything else: the scene's own layers, run through its own shaders.
        normaliser = SceneNormaliser(folder, project, work, wetex)
        normalised = normaliser.normalise()
        report = normaliser.report()
        if not normalised["layers"]:
            summary = ", ".join(f"{k} {v}" for k, v in sorted(report["unsupported"].items()))
            return None, f"nothing drawable ({summary})"
        if normalised["canvas"][0] < 2 or normalised["canvas"][1] < 2:
            biggest = max(normalised["layers"], key=lambda l: l["size"][0] * l["size"][1])
            normalised["canvas"] = [max(2, int(biggest["size"][0])), max(2, int(biggest["size"][1]))]
        moving = plan_loop(normalised)
        still_output = os.path.join(library, "stills", f"{item_id}.jpg")
        os.makedirs(os.path.dirname(still_output), exist_ok=True)
        info, problem = render_scene(normalised, still_output, library, work, still=True)
        if problem:
            return None, f"couldn't render: {problem}"
        if is_blank(still_output):
            os.remove(still_output)
            summary = ", ".join(f"{k} {v}" for k, v in sorted(report["unsupported"].items())) or "reason unclear"
            return None, f"renders blank ({summary}) — likely depends on something not carried, e.g. a 3D model"
        notes = {"unsupported": report["unsupported"], "missing": report["missing"], "renderer": info.get("notes", [])}
        if live and moving:
            loop_output = os.path.join(library, "live", f"{item_id}.mp4")
            os.makedirs(os.path.dirname(loop_output), exist_ok=True)
            loop, trouble = render_scene(normalised, loop_output, library, work)
            if loop:
                movement = frame_movement(loop_output, loop["seconds"])
                if movement is not None and movement >= MOTION_VISIBLE:
                    return {"kind": "video", "playback": f"live/{item_id}.mp4", "source": "scene shaders",
                            "still": f"stills/{item_id}.jpg", "loopSeconds": loop["seconds"], "movement": round(movement, 2),
                            "sceneNotes": notes}, None
                os.remove(loop_output)
                print(f"    (kept still: movement {movement} under {MOTION_VISIBLE})", flush=True)
            else:
                print(f"    (no loop: {trouble})", flush=True)
        reference = preview_hash(folder, project)
        composed = dhash(still_output, square=True)
        distance = bin(reference ^ composed).count("1") if reference is not None and composed is not None else None
        return {"kind": "image", "playback": f"stills/{item_id}.jpg", "source": "scene shaders",
                "layers": len(normalised["layers"]), "previewDistance": distance,
                "width": info["width"], "height": info["height"], "sceneNotes": notes}, None


# MARK: Import

# The app's wallpaper categories (Aerial.Category in AllSetCore), in the
# order a title keyword is tried. Two were added for this library: games and abstract.
KEYWORDS = [
    ("cities", ["city", "cities", "street", "alley", "neon", "cyberpunk", "tokyo", "downtown", "skyline", "城", "街"]),
    # Single CJK characters like 海 (sea: also in 云海 "sea of clouds" and 海报
    # "poster") or 星 (star) are too ambiguous to decide a category alone.
    ("underwater", ["underwater", "ocean", "sea", "reef", "dive", "diving", "fish", "潜水", "海底", "深海"]),
    ("space", ["space", "earth", "planet", "meteor", "galaxy", "nebula", "moon", "宇宙", "星空"]),
    ("landscapes", ["landscape", "nature", "sky", "lake", "forest", "mountain", "cloud", "river", "field", "sunset",
                    "湖", "云", "风", "山", "树", "林", "花"]),
]
TAG_CATEGORIES = {"game": "games", "landscape": "landscapes", "nature": "landscapes", "relaxing": "landscapes",
                  "animal": "landscapes", "cyberpunk": "cities", "abstract": "abstract", "pixel art": "abstract",
                  "cgi": "abstract", "anime": "abstract", "sports": "games"}

# Wallpaper-site decorations in titles: "【动态壁纸/4K/纯风景】", " - 4K", "(With BGM)", "by b站@…"
NOISE = [r"【[^】]*(壁纸|4K|4k|风景|动态)[^】]*】", r"\((with )?bgm\)", r"\b(4k|8k|2k|qhd|uhd|hd|1080p|1440p|2160p)\b",
         r"\b\d{2,3}\s?fps\b", r"\b(animated|loop(ed)?|wallpaper engine|official)\b", r"\bby\s+\S*b站\S*", r"[-—_]+\s*b站.*$",
         r"b站@\S+", r"_?简单循环.*$", r"_v\d+(\.\d+)*$", r"-?moewalls-com", r"\bedit(ed)? by .*$", r"动态壁纸", r"官网",
         r"[，,]?\s*[48]k\s*\d*\s*帧", r"\d+\s*帧", r"\s*[/／]\s*背景", r"\s[-—|]\s*by[:\s]+\S+.*$",
         r"\(?\b\d{3,4}\s*[x×]\s*\d{3,4}\b\)?", r"\[[^\]]*\bmusic\s*\]", r"\s*[-|]*\s*\|\s*random soundtracks.*$", r"\s*\|\s*full\s*$"]


def clean_title(text):
    import re
    title = text or ""
    for pattern in NOISE:
        title = re.sub(pattern, " ", title, flags=re.IGNORECASE)
    title = title.strip()
    # "horizon-sky-wanderer" → "Horizon Sky Wanderer"
    if title and not re.search(r"\s", title) and re.search(r"[-_]", title) and title.isascii():
        title = re.sub(r"[-_]+", " ", title).title()
    title = re.sub(r"\s*[-—|:：]\s*$", "", title.strip())
    title = re.sub(r"^\s*[-—|:：]\s*", "", title)
    # Brackets emptied by the cleaning above: "[ ]", "[ , music]" → "", "[music]".
    for _ in range(2):
        title = re.sub(r"[\[(（【]\s*[,+&|/]*\s*[\])）】]", " ", title)
        title = re.sub(r"([\[(（【])\s*[,+&|/]\s*", r"\1", title)
        title = re.sub(r"\s*[,+&|/]\s*([\])）】])", r"\1", title)
    title = re.sub(r"([\[(（【])\s+", r"\1", title)
    title = re.sub(r"\s+([\])）】])", r"\1", title)
    title = re.sub(r"\s{2,}", " ", title).strip(" -—_|")
    # "[Island sunset]" → "Island sunset": a name that is all bracket.
    whole = re.fullmatch(r"[\[【]([^\]】]+)[\]】]", title)
    if whole:
        title = whole.group(1).strip()
    # "arthas", "hunt showdown" → "Arthas", "Hunt Showdown"
    if title.isascii() and title == title.lower() and any(c.isalpha() for c in title):
        title = title.title()
    return title


def title_for(record, path):
    """A readable name: the Workshop title, else the file name, never a raw camera or download name."""
    import re
    workshop = record.get("workshop") or {}
    for candidate in (workshop.get("title"), os.path.splitext(os.path.basename(path))[0], os.path.basename(os.path.dirname(path))):
        title = clean_title(candidate)
        # Names made by cameras, downloaders or hashes aren't titles.
        if title and not re.fullmatch(r"(img|vid|dsc|mov|video|ssstik\.io|tikvid\.io|ytdown\.com)?[\W_\d]*[a-f0-9]{12,}?[\W_\d]*",
                                      title, flags=re.IGNORECASE) and not re.match(r"(ssstik|tikvid|ytdown)", title, re.IGNORECASE):
            return title[:80]
    return "Untitled video"


def category_for(title, tags):
    words = title.lower()
    lowered = [t.lower() for t in tags]
    if "game" in lowered:
        return "games"
    for category, keys in KEYWORDS[:3]:
        if any(key in words for key in keys):
            return category
    for tag in lowered:
        if tag in TAG_CATEGORIES:
            return TAG_CATEGORIES[tag]
    if any(key in words for key in KEYWORDS[3][1]):
        return "landscapes"
    return "abstract"


def resolution_tag(width, height):
    long = max(width or 0, height or 0)
    return "8k" if long >= 7680 else "4k" if long >= 3840 else "1440p" if long >= 2560 else "1080p" if long >= 1920 else "hd"


def needs_transcode(record):
    """Why a file can't be played as it is, or None. Measured (docs/wallpaper-import.md):
    larger than the hardware decoder's 4096×2304 falls back to software (75 % of a core);
    more than 60 frames a second doubles decoding for frames a 60 Hz screen never shows."""
    reasons = []
    if (record.get("codec") or "") not in ("h264", "hevc"):
        reasons.append(f"codec {record.get('codec')}")
    if record.get("extension") not in (".mp4", ".mov", ".m4v"):
        reasons.append(f"container {record.get('extension')}")
    if (record.get("width") or 0) > 4096 or (record.get("height") or 0) > 2304:
        reasons.append(f"{record.get('width')}×{record.get('height')} is beyond hardware decoding")
    if (record.get("fps") or 0) > 61:
        reasons.append(f"{record.get('fps'):g} fps")
    return ", ".join(reasons) or None


def transcode(source, destination, record):
    """HEVC in hardware, at most 3840×2160 and 60 fps, no audio (wallpapers play muted)."""
    fps = min(record.get("fps") or 60, 60)
    bitrate = max(8, min(int((record.get("bitRate") or 20_000_000) / 1e6), 30))
    temporary = f"{destination}.{os.getpid()}.part.mp4"
    command = [FFMPEG, "-v", "error", "-y", "-i", source, "-an",
               "-vf", f"scale='min(3840,iw)':'min(2160,ih)':force_original_aspect_ratio=decrease:force_divisible_by=2,fps={fps:g}",
               "-c:v", "hevc_videotoolbox", "-b:v", f"{bitrate}M", "-tag:v", "hvc1", "-movflags", "+faststart", temporary]
    result = run_tool(command, capture_output=True, text=True)
    if result.returncode != 0 or not os.path.exists(temporary):
        return result.stderr.strip()[:300] or "ffmpeg failed"
    os.replace(temporary, destination)
    return None


def thumbnail(source, destination, duration):
    at = max(0.0, min(2.0, duration * 0.3))
    # Seeking in a single picture skips its only frame: stills aren't seeked.
    seek = ["-ss", f"{at:.2f}"] if duration > 0 else []
    run_tool([FFMPEG, "-v", "error", "-y"] + seek + ["-i", source, "-frames:v", "1",
                    "-vf", "scale=640:-2", "-q:v", "4", destination], capture_output=True)
    return os.path.exists(destination)


def dhash(path, square=False):
    """A 64-bit difference hash of a picture (of its centre square, to compare
    with Workshop previews, which are square crops), for finding near-duplicates."""
    crop = "crop='min(iw,ih)':'min(iw,ih)'," if square else ""
    result = run_tool([FFMPEG, "-v", "error", "-i", path, "-frames:v", "1", "-vf", f"{crop}scale=9:8,format=gray",
                             "-f", "rawvideo", "-"], capture_output=True)
    pixels = result.stdout
    if len(pixels) < 72:
        return None
    bits = 0
    for row in range(8):
        for column in range(8):
            bits = (bits << 1) | (pixels[row * 9 + column] > pixels[row * 9 + column + 1])
    return bits


def loops_in_page(root, relative):
    """Whether a web wallpaper's page plays this video on a loop (a background),
    rather than as a one-off clip of an interaction."""
    import re
    folder = os.path.join(root, relative.split(os.sep)[0])
    name = os.path.basename(relative)
    text = ""
    for base, _, names in os.walk(folder):
        for page in names:
            if page.endswith((".html", ".js")) and os.path.getsize(os.path.join(base, page)) < 2_000_000:
                with open(os.path.join(base, page), encoding="utf-8", errors="replace") as handle:
                    text += handle.read() + "\n"
    tags = re.findall(r"<video\b[^>]*>", text, flags=re.IGNORECASE)
    # 1. A <video> tag naming the file: it loops if that tag says so.
    for tag in tags:
        if name in tag:
            return re.search(r"\bloop\b", tag, flags=re.IGNORECASE) is not None
    # 2. Tags without sources, filled in by script: they loop if all of them do.
    if tags and name in text:
        return all(re.search(r"\bloop\b", tag, flags=re.IGNORECASE) for tag in tags)
    # 3. Videos made in script: `.loop = true` (or loop: true) close to the name.
    for match in re.finditer(re.escape(name), text):
        around = text[max(0, match.start() - 200):match.start()] + text[match.end():match.end() + 200]
        if re.search(r"loop\s*[:=]\s*true", around, flags=re.IGNORECASE):
            return True
    return False


# Scenes left out after checking every one by eye against its Workshop preview
# (2026-09-27): pictures that come out wrong without Wallpaper Engine's
# effects, and a second upload of the same artwork.
SCENE_REVIEWED_SKIP = {
    "3577452645": "the towers are drawn by effects: only the sky comes out",
    "3572340969": "only the sky strip comes out, not the characters",
    "3684060242": "the city photos sit under an effect: only the menu ring comes out",
    "3299228616": "96 of its values are driven by SceneScript code, which isn't run here; renders dark and covered",
    "3448877775": "the video inside is a chroma mask, not the picture",
    "3645009840": "the statue comes out cut into bars (glitch effect layers)",
    "3682811008": "the same picture as 3624164256 (Resident Evil 9 - Requiem), at 1080p instead of 4K",
    "3367609708": "interactive: a click-to-play intro whose layers SceneScript code animates, which isn't run here",
}


# Bumped whenever scenes would come out differently: cached results from an
# older renderer are redone.
SCENE_RENDERER = 10


def import_scenes(root, library, summary, entries, existing, skipped, now, root_id, live=True):
    """Every Wallpaper Engine scene item in the folder, as catalog entries."""
    items = workshop_items(root)
    offloaded = offloaded_items(library)
    wetex = wetex_tool(library)
    cache_path = os.path.join(library, "scenes.json")
    try:
        with open(cache_path) as handle:
            cache = json.load(handle)
    except (OSError, json.JSONDecodeError):
        cache = {}
    imported = []
    for workshop_id, project in items.items():
        if (project.get("type") or "").lower() != "scene":
            continue
        if workshop_id in SCENE_REVIEWED_SKIP:
            skipped.append((workshop_id, f"{project.get('title')}: {SCENE_REVIEWED_SKIP[workshop_id]}"))
            continue
        folder = os.path.join(root, workshop_id)
        package_name = os.path.splitext(project.get("file") or "scene.json")[0] + ".pkg"
        package_path = os.path.join(folder, package_name)
        if not os.path.isfile(package_path):
            skipped.append((workshop_id, "scene without a package"))
            continue
        stat = os.stat(package_path)
        known = cache.get(workshop_id, {})
        if known.get("size") == stat.st_size and known.get("mtime") == int(stat.st_mtime):
            digest = known["sha256"]
        else:
            digest = sha256(package_path)
            known = {"size": stat.st_size, "mtime": int(stat.st_mtime), "sha256": digest}
        item_id = digest[:16]
        result = known.get("result") if known.get("result") and known.get("sha256") == digest else None
        current = known.get("renderer") == SCENE_RENDERER
        output_ok = result and current and local_or_offloaded(library, result.get("playback"), offloaded)
        if not output_ok:
            if not current:
                for stale in ("stills/{}.jpg", "extracted/{}.mp4", "transcoded/{}.mp4", "live/{}.mp4"):
                    path = os.path.join(library, stale.format(item_id))
                    if os.path.exists(path):
                        os.remove(path)
            known["renderer"] = SCENE_RENDERER
            try:
                result, problem = import_scene(folder, project, library, wetex, item_id, live=live)
            except Exception as error:  # one broken scene must not stop the batch
                result, problem = None, f"failed: {type(error).__name__}: {error}"
            if problem:
                skipped.append((workshop_id, f"{project.get('title')}: {problem}"))
                known.pop("result", None)
                cache[workshop_id] = known
                continue
            if result["kind"] == "video":
                media = os.path.join(library, result["playback"])
                described = describe(media)
                result.update({k: described.get(k) for k in ("duration", "width", "height", "fps", "codec", "bitRate")})
                reason = needs_transcode(dict(described, extension=".mp4"))
                if reason:
                    output = os.path.join(library, "transcoded", f"{item_id}.mp4")
                    error = None if os.path.exists(output) else transcode(media, output, described)
                    if error:
                        skipped.append((workshop_id, f"video texture can't play: {error}"))
                        continue
                    os.remove(media)
                    result.update(playback=f"transcoded/{item_id}.mp4", transcodedBecause=reason)
            known["result"] = result
            cache[workshop_id] = known
            # Saved as it goes: an interrupted run resumes where it stopped.
            with open(cache_path, "w") as handle:
                json.dump(cache, handle, indent=1, ensure_ascii=False)
        media = os.path.join(library, result["playback"])
        title = title_for({"workshop": {"title": project.get("title")}}, package_path)
        tags = [t for t in project.get("tags") or [] if t.lower() != "unspecified"]
        category = category_for(title, tags)
        rating = project.get("contentrating")
        entry = {
            "id": item_id, "title": title, "category": category, "kind": result["kind"],
            "tags": sorted({t.lower() for t in tags} | {category, resolution_tag(result.get("width"), result.get("height")),
                                                        "still" if result["kind"] == "image" else "live"}),
            "root": root_id, "file": os.path.relpath(package_path, root), "playback": result["playback"],
            **({"still": result["still"]} if result.get("still") else {}),
            "thumbnail": f"thumbnails/{item_id}.jpg", "duration": result.get("duration"),
            "width": result.get("width"), "height": result.get("height"), "fps": result.get("fps"),
            "size": recorded_size(library, result["playback"], existing.get(item_id, {}).get("size")),
            "sha256": digest, "contentRating": rating,
            "status": "quarantined",
            "statusReason": "license and author unknown" + ("" if rating == "Everyone" else "; no content rating")
                            + ("; the scene's animation and effects aren't included" if result["kind"] == "image" else ""),
            "provenance": {"source": "steam-workshop-scene", "workshopId": workshop_id, "originalTitle": project.get("title"),
                           "author": None, "license": None, "extractedFrom": result.get("source"),
                           "previewDistance": result.get("previewDistance")},
            "addedAt": existing.get(item_id, {}).get("addedAt", now),
        }
        if "transcodedBecause" in result:
            entry["transcodedBecause"] = result["transcodedBecause"]
        thumb = os.path.join(library, entry["thumbnail"])
        # Redrawn with its picture: a thumbnail older than it shows the old one.
        # An offloaded picture isn't here to compare against: its thumbnail stands.
        fresh = os.path.exists(thumb) and (not os.path.exists(media) or os.path.getmtime(thumb) >= os.path.getmtime(media))
        if not fresh and not thumbnail(media, thumb, result.get("duration") or 0):
            entry["thumbnail"] = None
        if item_id in entries:
            continue
        entries[item_id] = entry
        imported.append(item_id)
        print(f"  {entry['kind']:>5} {entry['category']:>10}  {entry['title']}", flush=True)
    with open(cache_path, "w") as handle:
        json.dump(cache, handle, indent=1, ensure_ascii=False)
    return imported


def offloaded_items(library):
    """Relative paths the app freed from this Mac because the personal server
    holds them (`offloaded.json`, written by WallpaperStore.offloadAll). Such
    a file is kept, not missing: never re-rendered, re-copied or dropped."""
    try:
        with open(os.path.join(library, "offloaded.json")) as handle:
            return set(json.load(handle))
    except (OSError, json.JSONDecodeError, TypeError):
        return set()


def local_or_offloaded(library, relative, offloaded):
    return bool(relative) and (relative in offloaded or os.path.exists(os.path.join(library, relative)))


def recorded_size(library, relative, fallback):
    path = os.path.join(library, relative)
    return os.path.getsize(path) if os.path.exists(path) else fallback


def removed_items(library):
    """Wallpapers taken out of the library by a person, by id: {id: {reason, keep}}."""
    try:
        with open(os.path.join(library, "removed.json")) as handle:
            return json.load(handle)
    except (OSError, json.JSONDecodeError):
        return {}


class CatalogUnreadable(Exception):
    """catalog.json exists but can't be read as a catalog. Never treated as an
    empty library: that would make cleanup remove every other root's files."""


def load_catalog(library):
    """The library's catalog. Missing: a fresh, empty one. Present but unreadable
    or the wrong shape: a copy is kept next to it and CatalogUnreadable is raised,
    so nothing is written or cleaned up on the strength of it."""
    path = os.path.join(library, "catalog.json")
    if not os.path.exists(path):
        return {"version": 1, "roots": [], "items": []}
    try:
        with open(path) as handle:
            catalog = json.load(handle)
        if not isinstance(catalog, dict) or not isinstance(catalog.get("items", []), list):
            raise ValueError("not a catalog object")
        return catalog
    except (OSError, ValueError) as error:
        stamp = datetime.datetime.now().strftime("%Y%m%d-%H%M%S")
        copy = os.path.join(library, f"catalog.unreadable-{stamp}.json")
        try:
            shutil.copy2(path, copy)
        except OSError:
            copy = "(couldn't copy it)"
        raise CatalogUnreadable(f"{path} can't be read ({error}). Nothing was changed; a copy is at {copy}. "
                                "Restore a good catalog.json (or move it away to start fresh) and import again.")


ORPHAN_FOLDERS = ("stills", "extracted", "transcoded", "thumbnails", "live", "originals")
ORPHAN_RUNS_KEPT = 3


def clean_orphans(library, catalog, stamp=None):
    """Pictures and copies this importer made that no entry uses any more (a
    scene left out, a removed duplicate, a video gone from its folder). Only
    the importer's own folders are touched, and nothing is deleted outright:
    files move to .orphans/<time>/, of which the latest few runs are kept.
    An empty catalog never clears a library that has files."""
    used = {item.get(key) for item in catalog["items"] for key in ("playback", "thumbnail", "still") if item.get(key)}
    orphans = []
    for folder in ORPHAN_FOLDERS:
        directory = os.path.join(library, folder)
        for name in os.listdir(directory) if os.path.isdir(directory) else []:
            if f"{folder}/{name}" not in used and os.path.isfile(os.path.join(directory, name)):
                orphans.append(f"{folder}/{name}")
    if not orphans:
        return
    if not used:
        print(f"Not cleaning up: the catalog lists nothing, but {len(orphans)} files are in the library.")
        return
    run = os.path.join(library, ".orphans", stamp or datetime.datetime.now().strftime("%Y%m%d-%H%M%S"))
    for relative in orphans:
        target = os.path.join(run, relative)
        os.makedirs(os.path.dirname(target), exist_ok=True)
        os.replace(os.path.join(library, relative), target)
    print(f"Moved {len(orphans)} unused files to {run}")
    runs = sorted(os.listdir(os.path.join(library, ".orphans")))
    for old in runs[:-ORPHAN_RUNS_KEPT]:
        shutil.rmtree(os.path.join(library, ".orphans", old), ignore_errors=True)


def remove_duplicates(decisions_path, library):
    """Takes wallpapers out of the library for good: decisions is a JSON list of
    {"remove": id, "keep": id, "reason": text}. Recorded in removed.json, so
    later imports skip them too."""
    decisions = json.load(open(decisions_path))
    removed = removed_items(library)
    catalog_path = os.path.join(library, "catalog.json")
    catalog = load_catalog(library)
    ids = {item["id"] for item in catalog["items"]}
    for decision in decisions:
        if decision["remove"] in ids and decision.get("keep") in ids and decision["remove"] != decision.get("keep"):
            removed[decision["remove"]] = {"keep": decision.get("keep"), "reason": decision.get("reason", "duplicate")}
    before = len(catalog["items"])
    catalog["items"] = [item for item in catalog["items"] if item["id"] not in removed]
    write_json_atomic(os.path.join(library, "removed.json"), removed, indent=1, ensure_ascii=False)
    write_json_atomic(catalog_path, catalog, indent=1, ensure_ascii=False)
    clean_orphans(library, catalog)
    print(f"removed {before - len(catalog['items'])}; library now {len(catalog['items'])}")


def import_library(root, library, live=True, self_contained=False):
    """Turns a folder into catalog entries: one per unique video, keyed by content.
    Rerunning updates entries (and adds new files) instead of duplicating them."""
    summary = inventory(root, library)
    root = summary["root"]
    root_id = hashlib.sha1(root.encode()).hexdigest()[:8]
    os.makedirs(os.path.join(library, "thumbnails"), exist_ok=True)
    os.makedirs(os.path.join(library, "transcoded"), exist_ok=True)
    catalog_path = os.path.join(library, "catalog.json")
    catalog = load_catalog(library)
    existing = {item["id"]: item for item in catalog.get("items", [])}
    now = datetime.datetime.now().isoformat(timespec="seconds")
    offloaded = offloaded_items(library)

    skipped, duplicates, entries = [], [], {}
    for record in summary["files"]:
        workshop = record.get("workshop")
        path = os.path.join(root, record["path"])
        if not record.get("valid"):
            skipped.append((record["path"], f"invalid: {record.get('problem')}"))
            continue
        looped = workshop and workshop.get("type") == "web" and loops_in_page(root, record["path"])
        if workshop and not (workshop.get("type") == "video" and workshop.get("isMainFile")) and not looped:
            skipped.append((record["path"], f"part of a {workshop.get('type') or 'unknown'} wallpaper, not a video wallpaper"))
            continue
        item_id = record["sha256"][:16]
        if item_id in entries:
            duplicates.append((record["path"], entries[item_id]["file"]))
            continue
        title = title_for(record, path)
        if looped:
            stem = os.path.splitext(os.path.basename(path))[0]
            clip = clean_title(stem.split("-")[-1].replace("_", " ")) or clean_title(stem.replace("-", " ").replace("_", " "))
            # Numbered clip names ("anim1 belt idle") read better without the number.
            import re
            clip = re.sub(r"^anim\d+\s*", "", clip, flags=re.IGNORECASE).strip() or clip
            title = f"{title} - {clip.title() if clip.islower() else clip}"[:80]
        tags = [t for t in (workshop or {}).get("tags", []) if t.lower() != "unspecified"]
        category = category_for(title, tags)
        rating = (workshop or {}).get("contentRating")
        entry = {
            "id": item_id,
            "title": title,
            "category": category,
            "kind": "video",
            "tags": sorted({t.lower() for t in tags} | {category, resolution_tag(record.get("width"), record.get("height"))}
                           | ({record["orientation"]} if record.get("orientation") in ("portrait", "ultrawide") else set())
                           | ({"60fps"} if (record.get("fps") or 0) >= 59 else set())),
            "root": root_id,
            "file": record["path"],
            "thumbnail": f"thumbnails/{item_id}.jpg",
            "duration": record.get("duration"),
            "width": record.get("width"),
            "height": record.get("height"),
            "fps": record.get("fps"),
            "codec": record.get("codec"),
            "bitRate": record.get("bitRate"),
            "size": record.get("size"),
            "orientation": record.get("orientation"),
            "sha256": record["sha256"],
            "contentRating": rating,
            # Nothing says who made these or whether they may be shared: they
            # play from your own drive and are never published or bundled.
            "status": "quarantined",
            "statusReason": "license and author unknown" + ("" if rating == "Everyone" else "; no content rating"),
            "provenance": {"source": "steam-workshop" if workshop else "local-folder",
                           "workshopId": (workshop or {}).get("id"), "originalTitle": (workshop or {}).get("title"),
                           "author": None, "license": None},
            "addedAt": existing.get(item_id, {}).get("addedAt", now),
        }
        thumb = os.path.join(library, entry["thumbnail"])
        if not os.path.exists(thumb) and not thumbnail(path, thumb, record.get("duration") or 0):
            entry["thumbnail"] = None
        reason = needs_transcode(record)
        if reason:
            output = os.path.join(library, "transcoded", f"{item_id}.mp4")
            done = local_or_offloaded(library, f"transcoded/{item_id}.mp4", offloaded)
            error = None if done else transcode(path, output, record)
            if error:
                entry.update(status="unsupported", statusReason=f"{reason}; transcoding failed: {error}")
            else:
                entry.update(playback=f"transcoded/{item_id}.mp4", transcodedBecause=reason,
                             playbackSize=recorded_size(library, f"transcoded/{item_id}.mp4",
                                                        existing.get(item_id, {}).get("playbackSize")))
        else:
            # Without a copy this one plays from the source folder, so it stops
            # working if that folder goes away. A copy already made is always
            # reused, so a later run without --self-contained never undoes it.
            kept = os.path.join(library, "originals", f"{item_id}{record['extension']}")
            if local_or_offloaded(library, f"originals/{item_id}{record['extension']}", offloaded):
                entry.update(playback=f"originals/{item_id}{record['extension']}",
                             playbackSize=recorded_size(library, f"originals/{item_id}{record['extension']}",
                                                        existing.get(item_id, {}).get("playbackSize")))
            elif self_contained:
                os.makedirs(os.path.dirname(kept), exist_ok=True)
                partial = kept + ".part"
                try:
                    shutil.copyfile(path, partial)
                    os.replace(partial, kept)
                except OSError as error:
                    if os.path.exists(partial):
                        os.remove(partial)
                    skipped.append((record["path"], f"couldn't copy onto this Mac: {error}"))
                else:
                    entry.update(playback=f"originals/{item_id}{record['extension']}",
                                 playbackSize=os.path.getsize(kept))
        entries[item_id] = entry
        print(f"  {entry['category']:>10}  {entry['title']}", flush=True)

    # Wallpaper Engine scenes: their artwork as a sharp still, or, when the
    # scene is really a video (a video texture, a GIF), that video.
    scene_ids = import_scenes(root, library, summary, entries, existing, skipped, now, root_id, live=live)
    print(f"scenes: {len(scene_ids)} imported", flush=True)

    # R1: every item gets recorded, even ones no earlier pass ever looked at.
    # A "web" (interactive HTML/JS) wallpaper with no video inside it never
    # appears in the video-file walk and isn't a "scene" package either, so
    # without this it would vanish with no reason logged anywhere. Scene-type
    # items are excluded below by kind, not by id: import_scenes returns
    # content-hash ids, not workshop ids, so they can't be compared here.
    seen_ids = {record["workshop"]["id"] for record in summary["files"] if record.get("workshop")}
    for workshop_id, project in workshop_items(root).items():
        kind = (project.get("type") or "unknown").lower()
        if kind != "scene" and workshop_id not in seen_ids:
            skipped.append((workshop_id, f"{project.get('title') or workshop_id}: "
                            f"{kind} wallpaper with no video inside it — interactive wallpapers aren't supported"))

    # Other folders' entries stay; this folder's are replaced by this scan.
    # Identity is content, not root: two folders can share a file (the same
    # Workshop item copied twice), and its id must appear only once in the
    # catalog, from whichever root produced it this run.
    kept = [item for item in catalog.get("items", [])
            if item.get("root") != root_id and item.get("id") not in entries]
    # Wallpapers a person removed (duplicates) stay removed on every import.
    removed = removed_items(library)
    for item_id in [i for i in entries if i in removed]:
        skipped.append((entries[item_id]["file"], f"removed: {removed[item_id].get('reason', '')}"))
    catalog["items"] = [item for item in kept + sorted(entries.values(), key=lambda e: e["title"].lower())
                        if item["id"] not in removed]
    roots = [r for r in catalog.get("roots", []) if r.get("id") != root_id]
    catalog["roots"] = roots + [{"id": root_id, "path": root, "label": os.path.basename(root)}]
    catalog["version"] = 1
    catalog["updatedAt"] = now
    write_json_atomic(catalog_path, catalog, indent=1, ensure_ascii=False)

    clean_orphans(library, catalog)

    # Near-duplicates for a person to review (never removed automatically).
    hashes = {e["id"]: dhash(os.path.join(library, e["thumbnail"])) for e in entries.values() if e.get("thumbnail")}
    near = []
    items = [e for e in entries.values() if hashes.get(e["id"]) is not None]
    for i, a in enumerate(items):
        for b in items[i + 1:]:
            distance = bin(hashes[a["id"]] ^ hashes[b["id"]]).count("1")
            if distance <= 8 and abs((a.get("duration") or 0) - (b.get("duration") or 0)) < 1.0:
                near.append({"a": a["title"], "b": b["title"], "distance": distance})
    with open(os.path.join(library, "import-report.json"), "w") as handle:
        json.dump({"root": root, "importedAt": now, "imported": len(entries), "skipped": skipped,
                   "duplicates": duplicates, "nearDuplicates": near}, handle, indent=1, ensure_ascii=False)
    size = sum(e["size"] or 0 for e in entries.values() if e.get("kind") == "video" and not e.get("playback"))
    transcoded = [e for e in entries.values() if e.get("transcodedBecause")]
    extracted = [e for e in entries.values() if (e.get("playback") or "").startswith(("stills/", "extracted/"))]

    def on_disk(entries):
        return sum(os.path.getsize(os.path.join(library, e["playback"])) for e in entries
                   if os.path.exists(os.path.join(library, e["playback"]))) / 1e9

    kinds = {k: sum(1 for e in entries.values() if e.get("kind") == k) for k in ("video", "image")}
    print(f"\n== import ==\nimported {len(entries)} wallpapers: {kinds['video']} live, {kinds['image']} stills")
    print(f"played from {root}: {size / 1e9:.2f} GB (not copied)")
    print(f"skipped {len(skipped)}; exact duplicates {len(duplicates)}; near-duplicates to review {len(near)}")
    print(f"transcoded {len(transcoded)} ({on_disk(transcoded):.2f} GB): " + "; ".join(f"{e['title']} ({e['transcodedBecause']})" for e in transcoded))
    print(f"extracted from scenes {len(extracted)} ({on_disk(extracted):.2f} GB)")
    print(f"categories: { {c: sum(1 for e in entries.values() if e['category'] == c) for c in sorted({e['category'] for e in entries.values()})} }")
    print(f"status: { {s: sum(1 for e in entries.values() if e['status'] == s) for s in sorted({e['status'] for e in entries.values()})} }")
    for path, reason in skipped:
        print(f"  skipped {path}: {reason}")


def main():
    global FFPROBE, FFMPEG
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("command", choices=["inventory", "import", "inspect-scene", "render-scene", "remove-duplicates"])
    parser.add_argument("folder")
    parser.add_argument("--library", default=DEFAULT_LIBRARY, help="where the app's library lives")
    parser.add_argument("--self-contained", action="store_true",
                        help="copy every video onto this Mac, so the source folder can go away")
    parser.add_argument("--output", help="render-scene: where to write the loop (.mp4) or still (.jpg)")
    parser.add_argument("--no-live", action="store_true",
                        help="keep scenes as stills instead of making them into looping videos")
    args = parser.parse_args()
    FFPROBE, FFMPEG = tool("ffprobe"), tool("ffmpeg")
    if args.command == "inventory":
        inventory(args.folder, args.library)
    elif args.command == "remove-duplicates":
        with library_lock(args.library):
            remove_duplicates(args.folder, args.library)
    elif args.command in ("inspect-scene", "render-scene"):
        inspect_scene(args.folder, args.library, args.output if args.command == "render-scene" else None)
    else:
        with library_lock(args.library):
            import_library(args.folder, args.library, live=not args.no_live,
                           self_contained=args.self_contained)


if __name__ == "__main__":
    try:
        main()
    except (CatalogUnreadable, LibraryBusy) as error:
        sys.exit(str(error))
