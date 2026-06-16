#!/usr/bin/env python3
"""Generate an isometric farm-plot sprite for Itzal Rising.

A dark tilled-earth diamond with furrow rows, electric-teal crop sprouts and a
soft neon edge — fits the "Basalt & Neon" look while reading clearly as a farm
(the procedural TextureGenerator placeholder looked flat/ugly). Output:
assets/buildings/farm.png. Wired into Farm.tscn as a Sprite2D.

Usage:  python tools/make_farm_sprite.py
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "buildings" / "farm.png"

W, H = 168, 120
CX, CY = W // 2, H // 2 + 4
HW, HH = 78, 44  # diamond half-width / half-height

SOIL_TOP = (60, 48, 36)
SOIL_BOT = (34, 26, 20)
FURROW = (78, 62, 44)
CROP = (40, 210, 165)
CROP_TIP = (150, 255, 230)
NEON = (0, 235, 205)


def _diamond(cx: int, cy: int, hw: int, hh: int):
	return [(cx, cy - hh), (cx + hw, cy), (cx, cy + hh), (cx - hw, cy)]


def main() -> None:
	OUT.parent.mkdir(parents=True, exist_ok=True)
	img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
	draw = ImageDraw.Draw(img)

	# Soil: vertical gradient clipped to the diamond.
	soil = Image.new("RGBA", (W, H), (0, 0, 0, 0))
	sdraw = ImageDraw.Draw(soil)
	for y in range(H):
		t = max(0.0, min(1.0, (y - (CY - HH)) / float(2 * HH)))
		c = tuple(int(SOIL_TOP[i] + (SOIL_BOT[i] - SOIL_TOP[i]) * t) for i in range(3))
		sdraw.line([(0, y), (W, y)], fill=c + (255,))
	mask = Image.new("L", (W, H), 0)
	ImageDraw.Draw(mask).polygon(_diamond(CX, CY, HW, HH), fill=255)
	img.paste(soil, (0, 0), mask)

	# Furrow rows: parallel lines along one iso axis, clipped to the soil.
	rows = Image.new("RGBA", (W, H), (0, 0, 0, 0))
	rdraw = ImageDraw.Draw(rows)
	for k in range(-6, 7):
		off = k * 11
		rdraw.line([(CX - HW + off, CY - HH - 8), (CX + off, CY + HH + 8)],
			fill=FURROW + (150,), width=2)
	img.paste(rows, (0, 0), Image.composite(rows.split()[3], Image.new("L", (W, H), 0), mask))

	# Crop sprouts on a grid inside the diamond.
	for gx in range(-5, 6):
		for gy in range(-3, 4):
			px = CX + gx * 13 + (6 if gy % 2 else 0)
			py = CY + gy * 11
			# inside-diamond test
			if abs(px - CX) / HW + abs(py - CY) / HH > 0.86:
				continue
			draw.line([(px, py + 3), (px, py - 3)], fill=CROP, width=2)
			draw.ellipse([px - 2, py - 5, px + 2, py - 1], fill=CROP_TIP)

	# Neon edge with a soft glow.
	glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
	ImageDraw.Draw(glow).polygon(_diamond(CX, CY, HW, HH), outline=NEON + (255,), width=3)
	glow = glow.filter(ImageFilter.GaussianBlur(3))
	img = Image.alpha_composite(img, glow)
	draw = ImageDraw.Draw(img)
	draw.polygon(_diamond(CX, CY, HW, HH), outline=NEON + (230,), width=2)

	img.save(OUT)
	print("WROTE %s (%dx%d)" % (OUT.relative_to(ROOT), W, H))


if __name__ == "__main__":
	main()
