#!/usr/bin/env python3
"""Generate neon HUD resource/population icons (Basalt & Neon style).

Draws simple line-art glyphs in bright teal with a soft glow on a transparent
background, matching the game's accent. Output: assets/ui/icons/{pop,wood,gold,
food}.png at 96x96 (the HUD scales them down).

Usage:  python tools/make_hud_icons.py
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "ui" / "icons"
S = 96
NEON = (170, 248, 230, 255)   # bright line
GLOW = (40, 210, 185, 255)     # glow colour
W = 4                          # stroke width


def _canvas() -> Image.Image:
    return Image.new("RGBA", (S, S), (0, 0, 0, 0))


def _finalize(line: Image.Image) -> Image.Image:
    # Recolour a blurred copy for the glow, stack it twice under the sharp line.
    glow_src = line.copy()
    glow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    px = glow_src.load()
    gpx = glow.load()
    for y in range(S):
        for x in range(S):
            a = px[x, y][3]
            if a > 0:
                gpx[x, y] = (GLOW[0], GLOW[1], GLOW[2], a)
    glow = glow.filter(ImageFilter.GaussianBlur(6))
    out = _canvas()
    out = Image.alpha_composite(out, glow)
    out = Image.alpha_composite(out, glow)
    out = Image.alpha_composite(out, line)
    return out


def _save(name: str, line: Image.Image) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    img = _finalize(line)
    img.save(OUT / ("%s.png" % name))
    print("WROTE %s" % (OUT / ("%s.png" % name)).relative_to(ROOT))


def _person(d: ImageDraw.ImageDraw, cx: int, top: int, scale: float) -> None:
    hr = int(11 * scale)
    d.ellipse([cx - hr, top, cx + hr, top + 2 * hr], outline=NEON, width=W)
    bw = int(20 * scale)
    by = top + 2 * hr + 3
    bh = int(22 * scale)
    # Shoulders: top half of an ellipse, then short vertical sides.
    d.arc([cx - bw, by, cx + bw, by + 2 * bh], start=180, end=360, fill=NEON, width=W)
    d.line([cx - bw, by + bh, cx - bw, by + bh + 5], fill=NEON, width=W)
    d.line([cx + bw, by + bh, cx + bw, by + bh + 5], fill=NEON, width=W)


def make_pop() -> None:
    line = _canvas()
    d = ImageDraw.Draw(line)
    _person(d, cx=60, top=20, scale=0.8)   # back person
    _person(d, cx=40, top=26, scale=1.0)   # front person
    _save("pop", line)


def make_wood() -> None:
    line = _canvas()
    d = ImageDraw.Draw(line)
    # Three log ends (front), each a circle with an inner ring.
    ends = [(30, 60, 16), (52, 64, 13), (40, 40, 15)]
    for (cx, cy, r) in ends:
        d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=NEON, width=W)
        d.ellipse([cx - r // 2, cy - r // 2, cx + r // 2, cy + r // 2], outline=NEON, width=2)
    # Body of the top log extending right, with a back cap.
    d.line([40, 25, 78, 32], fill=NEON, width=W)
    d.line([55, 55, 84, 50], fill=NEON, width=W)
    d.ellipse([74, 30, 86, 52], outline=NEON, width=W)
    _save("wood", line)


def make_gold() -> None:
    line = _canvas()
    d = ImageDraw.Draw(line)

    def bar(x: int, y: int, w: int, h: int, s: int) -> None:
        d.polygon([(x + s, y), (x + w + s, y), (x + w, y + h), (x, y + h)],
                  outline=NEON, width=W)
        # little top face to read as 3D
        d.line([(x + s, y), (x + s + 6, y - 6)], fill=NEON, width=2)
        d.line([(x + w + s, y), (x + w + s + 6, y - 6)], fill=NEON, width=2)
        d.line([(x + s + 6, y - 6), (x + w + s + 6, y - 6)], fill=NEON, width=2)

    bar(20, 58, 34, 16, 8)   # bottom-left
    bar(46, 58, 34, 16, 8)   # bottom-right
    bar(33, 40, 34, 16, 8)   # top
    _save("gold", line)


def make_food() -> None:
    line = _canvas()
    d = ImageDraw.Draw(line)
    # Cob body
    cx, top, bot = 52, 18, 76
    rw = 15
    d.ellipse([cx - rw, top, cx + rw, bot], outline=NEON, width=W)
    # Kernel cross-hatch inside the cob
    for yy in range(top + 8, bot - 6, 9):
        d.line([cx - rw + 3, yy, cx + rw - 3, yy], fill=NEON, width=2)
    for xx in range(cx - rw + 5, cx + rw - 3, 9):
        d.line([xx, top + 8, xx, bot - 8], fill=NEON, width=2)
    # Two husk leaves at the base-left
    d.polygon([(cx - rw + 2, bot - 10), (20, bot + 2), (cx - 2, bot)], outline=NEON, width=W)
    d.polygon([(cx - rw + 4, bot - 22), (16, bot - 18), (cx - 4, bot - 6)], outline=NEON, width=W)
    _save("food", line)


def main() -> None:
    make_pop()
    make_wood()
    make_gold()
    make_food()


if __name__ == "__main__":
    main()
