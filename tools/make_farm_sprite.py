#!/usr/bin/env python3
"""Generate an isometric farm-plot sprite for Itzal Rising.

A raised tilled-earth bed (top face + two soil side faces, so it reads with
depth like the other buildings, not a flat decal) with furrow rows, electric-
teal crop sprouts and a neon edge. Output: assets/buildings/farm.png, wired
into Farm.tscn as a Sprite2D.

Usage:  python tools/make_farm_sprite.py
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "buildings" / "farm.png"

W, H = 176, 132
HW, HH = 80, 42          # top-face diamond half-width / half-height
DEPTH = 22               # soil thickness (side faces)

NEON = (0, 235, 205)
SOIL_TOP_A = (66, 52, 38)
SOIL_TOP_B = (40, 31, 23)
SOIL_LEFT = (28, 22, 16)
SOIL_RIGHT = (46, 36, 26)
FURROW = (84, 66, 46)
CROP = (40, 210, 165)
CROP_TIP = (160, 255, 232)


def main() -> None:
	OUT.parent.mkdir(parents=True, exist_ok=True)
	img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
	draw = ImageDraw.Draw(img)
	cx = W // 2
	cy = H - DEPTH - HH - 6  # top-face vertical centre

	top = [(cx, cy - HH), (cx + HW, cy), (cx, cy + HH), (cx - HW, cy)]
	b = (cx, cy + HH)
	left_pt = (cx - HW, cy)
	right_pt = (cx + HW, cy)

	# Ground shadow.
	sh = Image.new("RGBA", (W, H), (0, 0, 0, 0))
	ImageDraw.Draw(sh).ellipse([cx - HW - 6, cy + HH + DEPTH - 14, cx + HW + 6, cy + HH + DEPTH + 8],
		fill=(0, 0, 0, 90))
	img.alpha_composite(sh.filter(ImageFilter.GaussianBlur(4)))
	draw = ImageDraw.Draw(img)

	# Side faces (soil cross-section) give the bed height.
	draw.polygon([left_pt, b, (b[0], b[1] + DEPTH), (left_pt[0], left_pt[1] + DEPTH)], fill=SOIL_LEFT)
	draw.polygon([right_pt, b, (b[0], b[1] + DEPTH), (right_pt[0], right_pt[1] + DEPTH)], fill=SOIL_RIGHT)

	# Top face: gradient soil clipped to the diamond.
	soil = Image.new("RGBA", (W, H), (0, 0, 0, 0))
	sdraw = ImageDraw.Draw(soil)
	for y in range(cy - HH, cy + HH):
		t = (y - (cy - HH)) / float(2 * HH)
		c = tuple(int(SOIL_TOP_A[i] + (SOIL_TOP_B[i] - SOIL_TOP_A[i]) * t) for i in range(3))
		sdraw.line([(0, y), (W, y)], fill=c + (255,))
	mask = Image.new("L", (W, H), 0)
	ImageDraw.Draw(mask).polygon(top, fill=255)
	img.paste(soil, (0, 0), mask)
	draw = ImageDraw.Draw(img)

	# Furrow rows along one iso axis, clipped to the top face.
	rows = Image.new("RGBA", (W, H), (0, 0, 0, 0))
	rdraw = ImageDraw.Draw(rows)
	for k in range(-6, 7):
		off = k * 12
		rdraw.line([(cx - HW + off, cy - HH - 6), (cx + off, cy + HH + 6)], fill=FURROW + (150,), width=2)
	img.paste(rows, (0, 0), Image.composite(rows.split()[3], Image.new("L", (W, H), 0), mask))
	draw = ImageDraw.Draw(img)

	# Crop sprouts on a grid inside the top face.
	for gx in range(-5, 6):
		for gy in range(-3, 4):
			px = cx + gx * 14 + (7 if gy % 2 else 0)
			py = cy + gy * 11
			if abs(px - cx) / HW + abs(py - cy) / HH > 0.82:
				continue
			draw.line([(px, py + 3), (px, py - 4)], fill=CROP, width=2)
			draw.ellipse([px - 2, py - 6, px + 2, py - 2], fill=CROP_TIP)

	# Neon edge on the top diamond + a glow.
	glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
	ImageDraw.Draw(glow).polygon(top, outline=NEON + (255,), width=3)
	img = Image.alpha_composite(img, glow.filter(ImageFilter.GaussianBlur(3)))
	ImageDraw.Draw(img).polygon(top, outline=NEON + (220,), width=2)

	img.save(OUT)
	print("WROTE %s (%dx%d)" % (OUT.relative_to(ROOT), W, H))


if __name__ == "__main__":
	main()
