#!/usr/bin/env python3
"""Generate a storehouse / resource drop-off sprite for Itzal Rising.

A small isometric depot: dark slate hut with a neon-trimmed awning and a few
resource crates/piles out front, so villagers can deposit near far resources
instead of trekking to the Town Center. Output: assets/buildings/storehouse.png.

Usage:  python tools/make_storehouse_sprite.py
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "buildings" / "storehouse.png"

W, H = 132, 116
NEON = (0, 235, 205)
WALL = (52, 48, 42)
WALL_DARK = (34, 31, 27)
ROOF = (40, 60, 60)
WOOD = (120, 84, 48)
GOLD = (224, 170, 50)


def main() -> None:
	OUT.parent.mkdir(parents=True, exist_ok=True)
	img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
	cx = W // 2
	gy = H - 16

	# Shadow.
	sh = Image.new("RGBA", (W, H), (0, 0, 0, 0))
	ImageDraw.Draw(sh).ellipse([cx - 50, gy - 6, cx + 50, gy + 12], fill=(0, 0, 0, 90))
	img.alpha_composite(sh.filter(ImageFilter.GaussianBlur(3)))
	draw = ImageDraw.Draw(img)

	# Hut body: a simple iso box (front + right side).
	bx0, bx1 = cx - 30, cx + 18
	by0, by1 = gy - 44, gy
	draw.polygon([(bx0, by0), (bx1, by0), (bx1, by1), (bx0, by1)], fill=WALL)          # front
	draw.polygon([(bx1, by0), (bx1 + 18, by0 - 10), (bx1 + 18, by1 - 10), (bx1, by1)], fill=WALL_DARK)  # side
	# Doorway.
	draw.rectangle([cx - 16, gy - 26, cx + 2, gy], fill=(18, 16, 14))
	draw.line([(cx - 16, gy - 26), (cx + 2, gy - 26)], fill=NEON + (180,), width=2)

	# Awning roof with neon trim.
	draw.polygon([(bx0 - 6, by0 + 2), (bx1 + 22, by0 - 8), (bx1 + 18, by0 - 16), (bx0 - 10, by0 - 6)], fill=ROOF)
	draw.line([(bx0 - 6, by0 + 2), (bx1 + 22, by0 - 8)], fill=NEON + (220,), width=2)
	draw.line([(bx0, by0), (bx0, by1)], fill=NEON + (120,), width=1)
	draw.line([(bx1, by0), (bx1, by1)], fill=NEON + (120,), width=1)

	# Resource piles out front: stacked wood logs + gold nuggets.
	for i in range(3):
		ly = gy - 2 - i * 4
		draw.ellipse([cx + 20, ly - 3, cx + 44, ly + 3], fill=WOOD, outline=(70, 48, 28))
	for (ox, oy, r) in [(cx - 40, gy - 4, 5), (cx - 30, gy - 2, 6), (cx - 36, gy - 9, 4)]:
		draw.ellipse([ox - r, oy - r, ox + r, oy + r], fill=GOLD, outline=(150, 110, 30))

	img.save(OUT)
	print("WROTE %s (%dx%d)" % (OUT.relative_to(ROOT), W, H))


if __name__ == "__main__":
	main()
