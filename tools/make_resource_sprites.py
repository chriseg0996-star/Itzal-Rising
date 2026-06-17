#!/usr/bin/env python3
"""Generate stylized resource sprites for Itzal Rising (wood + gold).

Replaces the flat procedural TextureGenerator placeholders with hand-styled
art in the "Basalt & Neon" look:
  - tree.png      : a small grove of layered conifers, deep teal-green with a
                    neon-teal rim and dark trunks.
  - goldmine.png  : a dark basalt outcrop with glowing amber crystal shards.

Output: assets/world/{tree,goldmine}.png. Wired into ResourceNode.tscn and
GoldMine.tscn as Sprite2D.

Usage:  python tools/make_resource_sprites.py
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
OUT_DIR = ROOT / "assets" / "world"

NEON = (0, 235, 205)
SHADOW = (0, 0, 0, 90)


def _ground_shadow(img: Image.Image, cx: int, cy: int, rx: int, ry: int) -> None:
	sh = Image.new("RGBA", img.size, (0, 0, 0, 0))
	ImageDraw.Draw(sh).ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=SHADOW)
	sh = sh.filter(ImageFilter.GaussianBlur(4))
	img.alpha_composite(sh)


def _glow(size, draw_fn, blur: int) -> Image.Image:
	g = Image.new("RGBA", size, (0, 0, 0, 0))
	draw_fn(ImageDraw.Draw(g))
	return g.filter(ImageFilter.GaussianBlur(blur))


def _conifer(draw: ImageDraw.ImageDraw, cx: int, base_y: int, h: int, w: int) -> None:
	# Dark trunk.
	tw = max(3, w // 8)
	draw.rectangle([cx - tw, base_y - h * 0.18, cx + tw, base_y], fill=(46, 33, 24))
	# Three stacked tiers, darkest at the bottom.
	tiers = 3
	greens = [(20, 62, 44), (26, 78, 54), (34, 96, 66)]
	for i in range(tiers):
		t = i / float(tiers)
		tier_w = w * (1.0 - 0.22 * i)
		top = base_y - h * (0.18 + 0.78 * (i + 1) / tiers)
		bot = base_y - h * (0.18 + 0.78 * i / tiers) + h * 0.06
		draw.polygon([(cx, top), (cx - tier_w / 2, bot), (cx + tier_w / 2, bot)],
			fill=greens[i])
		# Neon rim on the upper-left edge of each tier.
		draw.line([(cx, top), (cx - tier_w / 2, bot)], fill=NEON + (180,), width=2)


def make_tree() -> None:
	W, H = 128, 148
	img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
	draw = ImageDraw.Draw(img)
	_ground_shadow(img, W // 2, H - 18, 46, 16)
	draw = ImageDraw.Draw(img)
	# Grove: a tall centre tree flanked by two smaller ones.
	_conifer(draw, W // 2 - 34, H - 22, 78, 56)
	_conifer(draw, W // 2 + 32, H - 18, 70, 50)
	_conifer(draw, W // 2 - 2, H - 14, 112, 74)
	# Soft neon glow pass over the canopies.
	glow = _glow((W, H), lambda d: [
		d.polygon([(W // 2 - 2, H - 14 - 108), (W // 2 - 39, H - 50), (W // 2 + 35, H - 50)],
			outline=NEON + (120,), width=2)], 4)
	img.alpha_composite(glow)
	img.save(OUT_DIR / "tree.png")
	print("WROTE assets/world/tree.png (%dx%d)" % (W, H))


def make_goldmine() -> None:
	# A timber-framed mine entrance dug into a dark rock face, gold ore glinting
	# inside and piled at the mouth.
	W, H = 156, 124
	img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
	cx = W // 2
	gy = H - 16  # ground line
	_ground_shadow(img, cx, gy, 60, 16)
	draw = ImageDraw.Draw(img)

	# Rock cliff: stacked dark slate slabs (chunky, not round).
	draw.polygon([(cx - 64, gy), (cx - 52, gy - 64), (cx - 10, gy - 80),
		(cx + 44, gy - 70), (cx + 64, gy - 30), (cx + 60, gy)], fill=(40, 42, 50))
	draw.polygon([(cx - 40, gy - 30), (cx - 30, gy - 70), (cx + 8, gy - 78),
		(cx + 38, gy - 60), (cx + 44, gy - 28)], fill=(52, 55, 65))
	# Neon-teal rim light along the top ridge.
	draw.line([(cx - 52, gy - 64), (cx - 10, gy - 80), (cx + 44, gy - 70)],
		fill=NEON + (150,), width=2)

	# Mine shaft: a dark arched opening (rounded-top rectangle).
	mw, mh = 46, 54
	ax0, ay0, ax1, ay1 = cx - mw // 2, gy - mh, cx + mw // 2, gy
	draw.rounded_rectangle([ax0, ay0, ax1, ay1], radius=mw // 2, fill=(10, 9, 13))
	draw.rectangle([ax0, ay0 + mw // 2, ax1, ay1], fill=(10, 9, 13))

	# Gold glints deep in the shaft (glow).
	glints = [(cx - 8, gy - 30), (cx + 9, gy - 22), (cx + 1, gy - 14), (cx - 12, gy - 12)]
	glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
	gdraw = ImageDraw.Draw(glow)
	for (px, py) in glints:
		gdraw.ellipse([px - 6, py - 6, px + 6, py + 6], fill=(255, 195, 70, 200))
	# Ore pile at the mouth (amber rocks).
	ore = [(cx - 18, gy - 4, 10), (cx - 2, gy - 1, 12), (cx + 16, gy - 3, 9), (cx + 6, gy - 9, 8)]
	for (ox, oy, orad) in ore:
		gdraw.ellipse([ox - orad, oy - orad, ox + orad, oy + orad], fill=(247, 178, 42, 160))
	glow = glow.filter(ImageFilter.GaussianBlur(4))
	img.alpha_composite(glow)
	draw = ImageDraw.Draw(img)
	for (px, py) in glints:
		draw.ellipse([px - 2, py - 2, px + 2, py + 2], fill=(255, 226, 130))
	for (ox, oy, orad) in ore:
		draw.ellipse([ox - orad, oy - orad, ox + orad, oy + orad], fill=(214, 150, 36))
		draw.ellipse([ox - orad, oy - orad, ox + orad // 2, oy], fill=(255, 206, 90))

	# Timber frame around the shaft: two posts + a lintel, with neon bolts.
	post = 8
	beam = (74, 50, 30)
	draw.rectangle([ax0 - post, ay0, ax0, gy], fill=beam)
	draw.rectangle([ax1, ay0, ax1 + post, gy], fill=beam)
	draw.rectangle([ax0 - post - 4, ay0 - post, ax1 + post + 4, ay0], fill=beam)
	for bx in (ax0 - 2, ax1 + 2):
		draw.ellipse([bx - 2, ay0 - post + 2, bx + 2, ay0 - 2], fill=NEON + (220,))

	img.save(OUT_DIR / "goldmine.png")
	print("WROTE assets/world/goldmine.png (%dx%d)" % (W, H))


def main() -> None:
	OUT_DIR.mkdir(parents=True, exist_ok=True)
	make_tree()
	make_goldmine()


if __name__ == "__main__":
	main()
