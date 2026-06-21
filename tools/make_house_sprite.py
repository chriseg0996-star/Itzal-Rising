#!/usr/bin/env python3
"""Generate a House sprite for Itzal Rising (population-supply building).

A small slate dwelling with a neon-trimmed gabled roof, a glowing window and a
door — distinct from the storehouse (no resource piles, peaked roof). Matches
the "Basalt & Neon" aesthetic. Output: assets/buildings/house.png.

Usage:  python tools/make_house_sprite.py
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "buildings" / "house.png"

W, H = 124, 116
NEON = (0, 235, 205)
WALL = (54, 50, 44)
WALL_DARK = (36, 33, 28)
ROOF = (44, 64, 64)
ROOF_DARK = (30, 46, 46)
WIN = (255, 214, 120)


def main() -> None:
    OUT.parent.mkdir(parents=True, exist_ok=True)
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    cx = W // 2
    gy = H - 16

    # Shadow.
    sh = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(sh).ellipse([cx - 44, gy - 6, cx + 44, gy + 12], fill=(0, 0, 0, 90))
    img.alpha_composite(sh.filter(ImageFilter.GaussianBlur(3)))
    draw = ImageDraw.Draw(img)

    # Iso body: front face + right side.
    bx0, bx1 = cx - 28, cx + 16
    by0, by1 = gy - 40, gy
    draw.polygon([(bx0, by0), (bx1, by0), (bx1, by1), (bx0, by1)], fill=WALL)            # front
    draw.polygon([(bx1, by0), (bx1 + 16, by0 - 9), (bx1 + 16, by1 - 9), (bx1, by1)], fill=WALL_DARK)  # side

    # Gabled roof: front triangle + right slope, neon ridge.
    apex = (cx - 6, by0 - 22)
    draw.polygon([(bx0 - 4, by0 + 2), (bx1 + 4, by0 + 2), apex], fill=ROOF)              # front gable
    draw.polygon([(bx1 + 4, by0 + 2), apex, (apex[0] + 16, apex[1] - 9), (bx1 + 16, by0 - 7)], fill=ROOF_DARK)  # right slope
    draw.line([(bx0 - 4, by0 + 2), apex], fill=NEON + (220,), width=2)
    draw.line([(bx1 + 4, by0 + 2), apex], fill=NEON + (220,), width=2)
    draw.line([apex, (apex[0] + 16, apex[1] - 9)], fill=NEON + (160,), width=2)

    # Door.
    draw.rectangle([cx - 18, gy - 22, cx - 4, gy], fill=(18, 16, 14))
    draw.line([(cx - 18, gy - 22), (cx - 4, gy - 22)], fill=NEON + (160,), width=1)

    # Glowing window with neon frame.
    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(glow).rectangle([cx + 1, gy - 24, cx + 12, gy - 13], fill=WIN + (200,))
    img.alpha_composite(glow.filter(ImageFilter.GaussianBlur(2)))
    draw.rectangle([cx + 1, gy - 24, cx + 12, gy - 13], outline=NEON + (220,), width=1)

    img.save(OUT)
    print("WROTE %s (%dx%d)" % (OUT.relative_to(ROOT), W, H))


if __name__ == "__main__":
    main()
