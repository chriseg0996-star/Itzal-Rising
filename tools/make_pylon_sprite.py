#!/usr/bin/env python3
"""Generate the Obsidian Pylon sprite (supply-cap building).

A slim black-glass obelisk on a stone plinth with a cyan energy core and neon
edge seams — reads as "energy" at a glance and fits Basalt & Neon.
Output: assets/buildings/pylon.png.

Usage:  python tools/make_pylon_sprite.py
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "buildings" / "pylon.png"

W, H = 96, 132
NEON = (0, 235, 205)
OBSIDIAN = (26, 27, 33)
OBSIDIAN_HI = (52, 56, 66)
PLINTH = (58, 54, 48)


def main() -> None:
    OUT.parent.mkdir(parents=True, exist_ok=True)
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    cx = W // 2
    gy = H - 14

    # Shadow.
    sh = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(sh).ellipse([cx - 30, gy - 5, cx + 30, gy + 9], fill=(0, 0, 0, 90))
    img.alpha_composite(sh.filter(ImageFilter.GaussianBlur(3)))
    draw = ImageDraw.Draw(img)

    # Stone plinth.
    draw.polygon([(cx - 24, gy), (cx + 24, gy), (cx + 17, gy - 12), (cx - 17, gy - 12)], fill=PLINTH)

    # Obelisk: front face + narrow lit side, tapering to a point.
    top = (cx, 12)
    draw.polygon([(cx - 13, gy - 12), (cx + 4, gy - 12), (top[0] + 2, top[1] + 6), (top[0] - 3, top[1] + 8)], fill=OBSIDIAN)
    draw.polygon([(cx + 4, gy - 12), (cx + 13, gy - 16), (top[0] + 5, top[1] + 10), (top[0] + 2, top[1] + 6)], fill=OBSIDIAN_HI)

    # Cyan core glow (mid-height diamond) + edge seams.
    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    my = (gy - 12 + top[1]) // 2
    gd.polygon([(cx - 6, my), (cx, my - 12), (cx + 6, my), (cx, my + 12)], fill=NEON + (230,))
    img.alpha_composite(glow.filter(ImageFilter.GaussianBlur(3)))
    draw.polygon([(cx - 4, my), (cx, my - 8), (cx + 4, my), (cx, my + 8)], fill=(210, 255, 248, 255))
    draw.line([(cx - 13, gy - 12), (top[0] - 3, top[1] + 8)], fill=NEON + (170,), width=1)
    draw.line([(cx + 13, gy - 16), (top[0] + 5, top[1] + 10)], fill=NEON + (120,), width=1)
    # Tip light.
    tipglow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(tipglow).ellipse([top[0] - 5, top[1] - 4, top[0] + 7, top[1] + 8], fill=NEON + (180,))
    img.alpha_composite(tipglow.filter(ImageFilter.GaussianBlur(2)))

    img.save(OUT)
    print("WROTE %s (%dx%d)" % (OUT.relative_to(ROOT), W, H))


if __name__ == "__main__":
    main()
