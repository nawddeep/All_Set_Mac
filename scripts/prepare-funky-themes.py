"""Builds the Funky Themes wallpapers and widget layout from the supplied designs.

Each supplied design is a flattened desktop: artwork with a menu bar, a Dock and
painted clock, calendar, music and notes cards. This keeps all of the artwork,
paints over the inside of each painted card with the card's own colour and grain
(so the live widget sits on the card as if it had always been there), replaces
the Dock and menu bar from the artwork next to them, and writes:

  Sources/AllSetCore/Resources/ThemeArt/edit-supplied-<id>.jpg   2880x1800
  Sources/AllSetCore/Themes/FunkyLayouts.swift                   where each live widget goes

Usage (needs Pillow, NumPy and OpenCV, e.g. in a virtualenv):
  python scripts/prepare-funky-themes.py <folder holding the two batch folders> [--preview <dir>]
"""

import argparse
import json
import os
import zlib

import cv2
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LAYOUTS = os.path.join(ROOT, "design", "provided-funky-themes")
ART = os.path.join(ROOT, "Sources", "AllSetCore", "Resources", "ThemeArt")
SWIFT = os.path.join(ROOT, "Sources", "AllSetCore", "Themes", "FunkyLayouts.swift")
SWIFT_MORE = os.path.join(ROOT, "Sources", "AllSetCore", "Themes", "FunkyThemesMore.swift")
SIZES = {"S": (168, 168), "M": (352, 168), "L": (352, 352)}
SWIFT_SIZES = {"S": ".small", "M": ".medium", "L": ".large"}
MENU_BAR = 42
REACH = 6
OUT = (2880, 1800)


def clear(image, rect, rng):
    """Paints over the inside of a painted card with the card's own colour and grain.

    The colour is a plane fitted to the pixels just inside the card's edge, leaving
    out ones far from their median (lettering, icons, artwork that crosses the
    edge), so a card that shades from top to bottom keeps doing so.
    """
    x0, y0, x1, y1 = rect
    area = image[y0:y1, x0:x1].astype(np.float32)
    h, w = area.shape[:2]
    b = 8
    mask = np.zeros((h, w), bool)
    mask[:b], mask[-b:], mask[:, :b], mask[:, -b:] = True, True, True, True
    ys, xs = np.nonzero(mask)
    ring = area[ys, xs]
    median = np.median(ring, axis=0)
    distance = np.abs(ring - median).sum(axis=1)
    keep = distance < max(np.percentile(distance, 60) * 2.5, 12)
    ys, xs, ring = ys[keep], xs[keep], ring[keep]
    design = np.stack([np.ones_like(xs, np.float32), xs / w, ys / h], axis=1)
    coefficients, *_ = np.linalg.lstsq(design, ring, rcond=None)
    grid_y, grid_x = np.mgrid[0:h, 0:w].astype(np.float32)
    fill = (coefficients[0] + coefficients[1] * (grid_x / w)[..., None] + coefficients[2] * (grid_y / h)[..., None])
    residual = ring - design @ coefficients
    grain = float(np.clip(np.median(np.abs(residual)) * 1.3, 0.6, 6))
    noise = cv2.GaussianBlur(rng.normal(0, grain, (h, w)).astype(np.float32), (3, 3), 0.7)
    fill = fill + noise[..., None]
    feather = 5
    ramp_x = np.clip(np.minimum(np.arange(w), np.arange(w)[::-1]) / feather, 0, 1)[None, :, None]
    ramp_y = np.clip(np.minimum(np.arange(h), np.arange(h)[::-1]) / feather, 0, 1)[:, None, None]
    alpha = np.minimum(ramp_x, ramp_y)
    image[y0:y1, x0:x1] = np.clip(area * (1 - alpha) + fill * alpha, 0, 255).astype(np.uint8)


def replace_dock(image, rect):
    """Fills the Dock's place from the artwork around it. The real Dock usually covers it."""
    x0, y0, x1, y1 = rect
    mask = np.zeros(image.shape[:2], np.uint8)
    mask[y0:y1, x0:x1] = 255
    image[:] = cv2.inpaint(image, mask, 9, cv2.INPAINT_TELEA)


def prepare(theme, source_folder, preview):
    path = os.path.join(source_folder, theme["file"])
    image = np.array(Image.open(path).convert("RGB"))
    assert image.shape[:2] == (992, 1586), f"{theme['id']}: expected 1586x992, got {image.shape[1]}x{image.shape[0]}"
    rng = np.random.default_rng(zlib.crc32(theme["id"].encode()))
    # The menu bar: the real one covers this strip, so the artwork below, mirrored, is enough.
    if theme.get("menubar", True):
        # The strip the real menu bar covers: smoothed over from the artwork below it.
        strip = np.zeros(image.shape[:2], np.uint8)
        strip[:MENU_BAR] = 255
        image[:] = cv2.inpaint(image, strip, 6, cv2.INPAINT_TELEA)
    if theme["dock"]:
        replace_dock(image, theme["dock"])
    for widget in theme["widgets"]:
        clear(image, widget["clear"], rng)
        # Parts of a tilted or overlapped card the widget's own rectangle doesn't reach.
        for extra in widget.get("also", []):
            clear(image, extra, rng)
    picture = Image.fromarray(image).resize(OUT, Image.LANCZOS).filter(ImageFilter.UnsharpMask(radius=1.4, percent=55, threshold=2))
    picture.save(os.path.join(ART, f"edit-supplied-{theme['id']}.jpg"), quality=88, optimize=True, progressive=True)
    if preview:
        sketch = Image.fromarray(image)
        draw = ImageDraw.Draw(sketch)
        for widget in theme["widgets"]:
            x0, y0, x1, y1 = widget["clear"]
            draw.rectangle([x0 - REACH, y0 - REACH, x1 + REACH, y1 + REACH], outline=(255, 0, 200), width=2)
            for ex0, ey0, ex1, ey1 in widget.get("also", []):
                draw.rectangle([ex0, ey0, ex1, ey1], outline=(0, 200, 255), width=1)
        sketch.save(os.path.join(preview, f"{theme['id']}.png"))


def swift_layouts(themes):
    lines = [
        "// Generated by scripts/prepare-funky-themes.py from design/provided-funky-themes/layout.json.",
        "// Edit the JSON and run the script; don't edit this by hand.",
        "",
        "extension FunkyThemes {",
        "    /// Each design's live widgets, in pixels of its picture: each fills the",
        "    /// card drawn for it, with the ink that reads on that card.",
        "    static let layouts: [String: [Placement]] = [",
    ]
    for theme in themes:
        lines.append(f"        \"{theme['id']}\": [")
        for widget in theme["widgets"]:
            x0, y0, x1, y1 = widget["clear"]
            # Reach a little past the cleared inside, towards the card's edge.
            x0, y0, x1, y1 = x0 - REACH, y0 - REACH, x1 + REACH, y1 + REACH
            w, h = SIZES[widget["size"]]
            # Stretch squeezes the drawing rather than reflowing it, so only a
            # little, where it can't be seen; the rest is an even scale, centred.
            stretch = min(max(((y1 - y0) / h) / ((x1 - x0) / w), 0.92), 1.08)
            scale = min((x1 - x0) / w, (y1 - y0) / (h * stretch))
            x = (x0 + x1) / 2 - w * scale / 2
            y = (y0 + y1) / 2 - h * scale * stretch / 2
            face = f", face: .{widget['face']}" if "face" in widget else ""
            lines.append(f"            Placement(.{widget['kind']}, {SWIFT_SIZES[widget['size']]}, x: {round(x)}, y: {round(y)}, "
                         f"scale: {scale:.3f}, stretch: {stretch:.3f}, ink: 0x{widget['ink']}{face}),")
        lines.append("        ],")
    lines += ["    ]", "}", ""]
    with open(SWIFT, "w") as file:
        file.write("\n".join(lines))


def swift_more(themes):
    """The Design entries for themes that carry their own look (`meta`)."""
    lines = [
        "// Generated by scripts/prepare-funky-themes.py from design/provided-funky-themes/layout-*.json.",
        "// Edit the JSON and run the script; don't edit this by hand.",
        "",
        "extension FunkyThemes {",
        "    static let additional: [Design] = [",
    ]
    for theme in themes:
        meta = theme.get("meta")
        if not meta:
            continue
        collections = ", ".join(f".{name}" for name in ["funkyThemes"] + meta["collections"] + [("night" if meta["dark"] else "designer")])
        lines += [
            f"        make(\"{theme['id']}\", \"{meta['title']}\", \"{meta['tagline']}\",",
            f"             card: 0x{meta['card']}, ink: 0x{meta['ink']}, accent: 0x{meta['accent']}, dark: {str(meta['dark']).lower()}, font: .{meta['font']},",
            f"             style: .{meta['style']}, filter: .{meta['filter']}, charm: \"{meta['charm']}\",",
            f"             collections: [{collections}], tags: \"{meta['tags']}\"" + (f", radius: {meta['radius']}" if "radius" in meta else "") + "),",
        ]
    lines += ["    ]", "}", ""]
    with open(SWIFT_MORE, "w") as file:
        file.write("\n".join(lines))


def load():
    themes = []
    for name in sorted(os.listdir(LAYOUTS)):
        if name == "layout.json" or (name.startswith("layout-") and name.endswith(".json")):
            with open(os.path.join(LAYOUTS, name)) as file:
                for theme in json.load(file)["themes"]:
                    theme["layoutFile"] = name
                    themes.append(theme)
    return themes


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("source")
    parser.add_argument("--preview")
    parser.add_argument("--only", help="comma-separated layout files (e.g. layout-3.json) to prepare; Swift is always written for all")
    args = parser.parse_args()
    themes = load()
    only = set(args.only.split(",")) if args.only else None
    if args.preview:
        os.makedirs(args.preview, exist_ok=True)
    for theme in themes:
        if only is None or theme["layoutFile"] in only:
            prepare(theme, args.source, args.preview)
            print("prepared", theme["id"])
    swift_layouts(themes)
    swift_more(themes)


if __name__ == "__main__":
    main()
