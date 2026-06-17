#!/usr/bin/env python3
"""Generate procedural siege-engine sprites for Itzal Rising (per faction).

A wheeled catapult: dark frame + throwing arm with a glowing loaded projectile,
faction-coloured neon accents. Output: assets/units/siege_{itzal,decay,ix}.png,
used as a static Sprite2D in the siege unit scenes.

Usage:  python tools/make_siege_sprites.py
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
OUT_DIR = ROOT / "assets" / "units"

W, H = 88, 84
FRAME = (44, 40, 34)
FRAME_DARK = (28, 25, 20)
WHEEL = (32, 30, 26)
WHEEL_HUB = (70, 64, 52)

# faction id -> (neon accent, projectile core)
FACTIONS = {
	"itzal": ((0, 235, 205), (120, 255, 240)),
	"decay": ((150, 70, 200), (180, 255, 90)),
	"ix": ((255, 176, 40), (255, 224, 130)),
}


def _glow(size, draw_fn, blur):
	g = Image.new("RGBA", size, (0, 0, 0, 0))
	draw_fn(ImageDraw.Draw(g))
	return g.filter(ImageFilter.GaussianBlur(blur))


def make(name: str, accent, core) -> None:
	img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
	cx = W // 2
	gy = H - 14  # ground line (wheel centres)
	# Ground shadow.
	sh = Image.new("RGBA", (W, H), (0, 0, 0, 0))
	ImageDraw.Draw(sh).ellipse([cx - 34, gy - 4, cx + 34, gy + 12], fill=(0, 0, 0, 90))
	img.alpha_composite(sh.filter(ImageFilter.GaussianBlur(3)))
	draw = ImageDraw.Draw(img)

	# Two wheels.
	for wx in (cx - 22, cx + 22):
		draw.ellipse([wx - 13, gy - 13, wx + 13, gy + 13], fill=WHEEL, outline=FRAME_DARK, width=2)
		draw.ellipse([wx - 4, gy - 4, wx + 4, gy + 4], fill=WHEEL_HUB)
		draw.line([wx, gy - 13, wx, gy + 13], fill=accent + (160,), width=1)
		draw.line([wx - 13, gy, wx + 13, gy], fill=accent + (160,), width=1)

	# Frame: a low chassis trapezoid.
	draw.polygon([(cx - 30, gy - 2), (cx + 30, gy - 2), (cx + 22, gy - 16), (cx - 22, gy - 16)], fill=FRAME)
	draw.line([(cx - 30, gy - 2), (cx - 22, gy - 16)], fill=accent + (180,), width=2)
	draw.line([(cx + 30, gy - 2), (cx + 22, gy - 16)], fill=accent + (180,), width=2)

	# Throwing arm (diagonal beam) up to the right, with a loaded glowing orb.
	arm_top = (cx + 18, gy - 54)
	arm_base = (cx - 14, gy - 14)
	draw.line([arm_base, arm_top], fill=FRAME_DARK, width=6)
	draw.line([arm_base, arm_top], fill=FRAME, width=3)
	# A-frame support.
	draw.line([(cx - 18, gy - 16), (cx + 2, gy - 40)], fill=FRAME, width=4)
	draw.line([(cx + 16, gy - 16), (cx + 2, gy - 40)], fill=FRAME, width=4)

	# Glowing projectile at the arm tip.
	glow = _glow((W, H), lambda d: d.ellipse([arm_top[0] - 12, arm_top[1] - 12, arm_top[0] + 12, arm_top[1] + 12],
		fill=accent + (220,)), 5)
	img.alpha_composite(glow)
	draw = ImageDraw.Draw(img)
	draw.ellipse([arm_top[0] - 8, arm_top[1] - 8, arm_top[0] + 8, arm_top[1] + 8], fill=accent)
	draw.ellipse([arm_top[0] - 4, arm_top[1] - 5, arm_top[0] + 3, arm_top[1] + 1], fill=core)

	img.save(OUT_DIR / ("siege_%s.png" % name))
	print("WROTE assets/units/siege_%s.png (%dx%d)" % (name, W, H))


def main() -> None:
	OUT_DIR.mkdir(parents=True, exist_ok=True)
	for name, (accent, core) in FACTIONS.items():
		make(name, accent, core)


if __name__ == "__main__":
	main()
