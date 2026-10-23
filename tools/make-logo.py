#!/usr/bin/env python3
"""POP Flow — cosmic-fastfetch: turn a picture into a fastfetch logo made of
letters and digits.

Each terminal cell gets the character whose shape (drawn in the terminal's own
font) is closest to that piece of the picture, so edges come out as g, F, L,
P, _ ... instead of flat blocks. A picture with a transparent background is
drawn by its silhouette; otherwise light parts become characters and dark
parts become the terminal background, which suits a dark terminal (--invert
swaps both rules; --by-light uses light/dark even with transparency).

    make-logo.py LOGO.png [--cols 40] [--fill TEXT] [--crop X,Y,W,H]
                 [--circle] [--invert] [--by-light] [--overlay FILE]
                 [--cell WxH]

Prints the logo, ready for fastfetch's "file" logo type (every line starts
with $1, the logo color).
"""
import argparse
import math
import os
import re
import subprocess
import sys

from PIL import Image, ImageDraw, ImageFont

CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789.,:;'`-_"
FALLBACK_FONT = "DejaVu Sans Mono"
# A cell whose sampled area is at least this full counts as "inside" and gets
# the next --fill character instead of a shape match.
FULL = 0.93
# Samples per cell across; the rows follow the cell's height/width ratio.
GX = 3


def font_file(family):
    try:
        out = subprocess.run(["fc-match", "-f", "%{file}", family],
                             capture_output=True, text=True, check=True).stdout
        return out or None
    except (OSError, subprocess.CalledProcessError):
        return None


def terminal_font():
    """Font family and size cosmic-term is set to, or the fallback."""
    conf = os.path.join(os.environ.get("XDG_CONFIG_HOME", os.path.expanduser("~/.config")),
                        "cosmic/com.system76.CosmicTerm/v1")
    try:
        family = open(os.path.join(conf, "font_name")).read().strip().strip('"')
    except OSError:
        family = FALLBACK_FONT
    try:
        size = float(open(os.path.join(conf, "font_size")).read().strip())
    except (OSError, ValueError):
        size = 14.0
    return family, size


def cell_size(path, size):
    """Width and height in pixels of one cell. cosmic-term's line height is
    ceil(1.4 * font size) (Config::metrics); the width is the font's advance."""
    font = ImageFont.truetype(path, 1000)
    return font.getlength("M") * size / 1000, math.ceil(size * 1.4)


def samples(im, gx, gy):
    small = im.resize((gx, gy), Image.BOX)
    return [v / 255 for v in small.getdata()]


def glyphs(path, gx, gy):
    cw, ch = 20 * gx, 20 * gy
    fsize = round(ch * 5 / 7)
    font = ImageFont.truetype(path, fsize)
    out = {}
    for c in CHARS + " ":
        im = Image.new("L", (cw, ch), 0)
        d = ImageDraw.Draw(im)
        left, _, right, _ = d.textbbox((0, 0), c, font=font)
        d.text(((cw - (right - left)) / 2 - left, (ch - fsize) / 2 - fsize / 10),
               c, fill=255, font=font)
        out[c] = samples(im, gx, gy)
    # Even the fullest glyph leaves gaps; scale them so it counts as solid.
    gain = 0.85 / max(sum(v) / len(v) for v in out.values())
    return {c: [min(1, x * gain) for x in v] for c, v in out.items()}


def ink(path, crop, invert, by_light):
    """Grayscale picture where 255 is "draw a character here"."""
    im = Image.open(path).convert("RGBA")
    if crop:
        x, y, w, h = crop
        im = im.crop((x, y, x + w, y + h))
    alpha = im.getchannel("A")
    if alpha.getextrema()[0] < 250 and not by_light:
        # A logo on a transparent background: its silhouette is the drawing,
        # whatever its colors (light/dark would cut a colorful logo apart).
        out = alpha.point(lambda v: 255 - v) if invert else alpha
    else:
        gray = im.convert("L")
        if invert:
            gray = gray.point(lambda v: 255 - v)
        # Transparent pixels never get ink.
        out = Image.composite(gray, Image.new("L", im.size, 0), alpha)
    if not crop:
        box = out.point(lambda v: 255 if v > 127 else 0).getbbox()
        if box:
            out = out.crop(box)
    return out


def apply_overlay(lines, path):
    """Paste a hand-drawn patch over the result: in the overlay file "?" keeps
    the generated character, anything else (a space too) replaces it."""
    for y, patch in enumerate(open(path).read().split("\n")):
        if y >= len(lines) or not patch:
            continue
        row = list(lines[y].ljust(len(patch)))
        for x, c in enumerate(patch):
            if c != "?":
                row[x] = c
        lines[y] = "".join(row).rstrip()
    return lines


def main():
    p = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    p.add_argument("image")
    p.add_argument("--cols", type=int, default=40, help="width in characters (default 40)")
    p.add_argument("--fill", default="", help="text repeated inside solid areas")
    p.add_argument("--crop", help="X,Y,W,H: use only this part of the picture")
    p.add_argument("--circle", action="store_true", help="keep only the circle inscribed in the crop")
    p.add_argument("--invert", action="store_true", help="dark parts become characters")
    p.add_argument("--by-light", action="store_true",
                   help="use light/dark even when the picture has transparency")
    p.add_argument("--overlay", help='hand-drawn patch; "?" keeps the generated character')
    p.add_argument("--cell", help="WxH of a terminal cell in pixels (default: read from cosmic-term)")
    a = p.parse_args()

    family, size = terminal_font()
    path = font_file(family) or font_file(FALLBACK_FONT)
    if not path:
        sys.exit("!! no monospace font found (fc-match)")
    if a.cell:
        cw, ch = (float(v) for v in a.cell.lower().split("x"))
    else:
        cw, ch = cell_size(path, size)
    gy = max(1, round(GX * ch / cw))

    crop = tuple(int(v) for v in re.split(r"[,x ]", a.crop)) if a.crop else None
    pic = ink(a.image, crop, a.invert, a.by_light)
    # Keep the picture's proportions on screen: a cell is GX:gy samples.
    rows = max(1, round(a.cols * GX / gy * pic.height / pic.width))
    pic = pic.resize((a.cols * GX, rows * gy), Image.BOX)
    if a.circle:
        mask = Image.new("L", pic.size, 0)
        ImageDraw.Draw(mask).ellipse((0, 0, pic.width - 1, pic.height - 1), fill=255)
        pic = Image.composite(pic, mask, mask)

    shapes = glyphs(path, GX, gy)
    lines = []
    for y in range(rows):
        row = ""
        for x in range(a.cols):
            cell = samples(pic.crop((x * GX, y * gy, (x + 1) * GX, (y + 1) * gy)), GX, gy)
            if a.fill and sum(cell) / len(cell) > FULL:
                # Offset each row so the text runs diagonally, not in columns.
                row += a.fill[(x + y * 3) % len(a.fill)]
            else:
                row += min(shapes, key=lambda c: sum((s - v) ** 2 for s, v in zip(shapes[c], cell)))
        lines.append(row.rstrip())
    if a.overlay:
        lines = apply_overlay(lines, a.overlay)
    while lines and not lines[-1]:
        lines.pop()
    print("\n".join("$1" + line for line in lines))


if __name__ == "__main__":
    main()
