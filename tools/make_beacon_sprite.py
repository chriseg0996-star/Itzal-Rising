#!/usr/bin/env python3
"""Generate the Ascension Beacon sprite (late-game victory building).

A tall twin-spire obsidian gate cradling a large cyan star-core — bigger and
brighter than the pylon so it reads as THE endgame structure.
Output: assets/buildings/beacon.png.

Usage:  python tools/make_beacon_sprite.py
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "buildings" / "beacon.png"

W, H = 150, 176
NEON = (0, 235, 205)
OBSIDIAN = (24, 25, 31)
OBSIDIAN_HI = (50, 54, 64)
PLINTH = (56, 52, 46)


def main() -> None:
    OUT.parent.mkdir(parents=True, exist_ok=True)
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    cx = W // 2
    gy = H - 18

    sh = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(sh).ellipse([cx - 52, gy - 7, cx + 52, gy + 12], fill=(0, 0, 0, 95))
    img.alpha_composite(sh.filter(ImageFilter.GaussianBlur(3)))
    draw = ImageDraw.Draw(img)

    # Wide stepped plinth.
    draw.polygon([(cx - 46, gy), (cx + 46, gy), (cx + 34, gy - 14), (cx - 34, gy - 14)], fill=PLINTH)
    draw.polygon([(cx - 34, gy - 14), (cx + 34, gy - 14), (cx + 26, gy - 24), (cx - 26, gy - 24)], fill=(44, 41, 37))

    # Twin curved spires leaning inward.
    for s in (-1, 1):
        bx = cx + s * 26
        draw.polygon([(bx - 7, gy - 24), (bx + 7, gy - 24), (cx + s * 8, 26), (cx + s * 3, 24)],
                     fill=OBSIDIAN if s < 0 else OBSIDIAN_HI)
        draw.line([(bx, gy - 24), (cx + s * 5, 25)], fill=NEON + (150,), width=1)

    # Star core between the spires.
    core = (cx, 62)
    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.ellipse([core[0] - 20, core[1] - 20, core[0] + 20, core[1] + 20], fill=NEON + (200,))
    img.alpha_composite(glow.filter(ImageFilter.GaussianBlur(6)))
    draw.polygon([(core[0], core[1] - 14), (core[0] + 5, core[1] - 4), (core[0] + 14, core[1]),
                  (core[0] + 5, core[1] + 4), (core[0], core[1] + 14), (core[0] - 5, core[1] + 4),
                  (core[0] - 14, core[1]), (core[0] - 5, core[1] - 4)], fill=(225, 255, 250, 255))

    img.save(OUT)
    print("WROTE %s (%dx%d)" % (OUT.relative_to(ROOT), W, H))


if __name__ == "__main__":
    main()
