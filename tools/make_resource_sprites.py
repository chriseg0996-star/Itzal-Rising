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
	W, H = 152, 116
	img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
	draw = ImageDraw.Draw(img)
	cx, cy = W // 2, H - 34
	_ground_shadow(img, cx, H - 16, 58, 18)
	draw = ImageDraw.Draw(img)
	# Basalt mound: stacked dark ellipses with a top highlight.
	draw.ellipse([cx - 60, cy - 30, cx + 60, cy + 40], fill=(34, 36, 44))
	draw.ellipse([cx - 44, cy - 40, cx + 40, cy + 18], fill=(46, 49, 58))
	draw.ellipse([cx - 30, cy - 44, cx + 18, cy - 6], fill=(58, 62, 72))
	# Neon-teal rim light along the top of the rock.
	draw.arc([cx - 60, cy - 34, cx + 60, cy + 36], 195, 345, fill=NEON + (160,), width=2)
	# Glowing amber crystal shards.
	shards = [(cx - 24, cy - 6, 16, 34), (cx + 6, cy - 16, 20, 48),
		(cx + 30, cy + 2, 14, 28), (cx - 4, cy + 6, 12, 24)]
	glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
	gdraw = ImageDraw.Draw(glow)
	for (sx, sy, sw, sh) in shards:
		gdraw.polygon([(sx, sy - sh), (sx - sw // 2, sy), (sx + sw // 2, sy)],
			fill=(255, 190, 60, 200))
	glow = glow.filter(ImageFilter.GaussianBlur(5))
	img.alpha_composite(glow)
	draw = ImageDraw.Draw(img)
	for (sx, sy, sw, sh) in shards:
		draw.polygon([(sx, sy - sh), (sx - sw // 2, sy), (sx + sw // 2, sy)],
			fill=(247, 178, 42))
		# Bright facet + tip.
		draw.polygon([(sx, sy - sh), (sx, sy), (sx + sw // 2, sy)], fill=(255, 214, 92))
		draw.line([(sx, sy - sh), (sx, sy)], fill=(255, 245, 200), width=1)
	img.save(OUT_DIR / "goldmine.png")
	print("WROTE assets/world/goldmine.png (%dx%d)" % (W, H))


def main() -> None:
	OUT_DIR.mkdir(parents=True, exist_ok=True)
	make_tree()
	make_goldmine()


if __name__ == "__main__":
	main()
