#!/usr/bin/env python3
"""Turn the Gemini icon cards (assets/ui/icons_src/*.png.png) into clean,
transparent HUD icons (assets/ui/icons/*.png).

Each card has a neon glyph on a dark background plus a baked-in number, a card
frame and a sparkle watermark. We:
  1. keep only the glyph region (drop the frame, number and sparkle by position),
  2. key the dark background to transparent from luminance (neon stays, dark goes),
  3. autocrop to the glyph and fit it into a 96x96 transparent square.

Usage:  python tools/process_gemini_icons.py
"""

from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "assets" / "ui" / "icons_src"
OUT = ROOT / "assets" / "ui" / "icons"
TARGET = 96
FIT = 88
LO = 60.0   # luminance below this -> transparent
HI = 145.0  # luminance above this -> fully opaque

# name -> (source file, keep-x range, keep-y range, optional bottom-right remove)
CARDS: dict = {
	"pop":  ("pop.png.png",  (0.13, 0.40), (0.17, 0.82), None),
	"wood": ("wood.png.png", (0.06, 0.94), (0.07, 0.93), (0.60, 0.64)),
	"gold": ("gold.png.png", (0.06, 0.94), (0.07, 0.93), (0.60, 0.62)),
	"food": ("food.png.png", (0.06, 0.94), (0.07, 0.90), (0.60, 0.62)),
}


def process(name: str, spec) -> None:
	src_file, kx, ky, remove = spec
	im = Image.open(SRC / src_file).convert("RGBA")
	arr = np.array(im).astype(np.float32)
	h, w = arr.shape[:2]
	rgb = arr[:, :, :3]
	lum = 0.299 * rgb[:, :, 0] + 0.587 * rgb[:, :, 1] + 0.114 * rgb[:, :, 2]
	alpha = np.clip((lum - LO) / (HI - LO), 0.0, 1.0)

	xs = (np.arange(w)[None, :] + 0.5) / w
	ys = (np.arange(h)[:, None] + 0.5) / h
	keep = (xs >= kx[0]) & (xs <= kx[1]) & (ys >= ky[0]) & (ys <= ky[1])
	if remove is not None:
		keep = keep & ~((xs > remove[0]) & (ys > remove[1]))
	alpha = alpha * keep

	# Crop to the glyph by the alpha channel only (rgb still holds the dark bg).
	mask = alpha > 0.08
	if not mask.any():
		print("SKIP %s: nothing kept" % name)
		return
	rows = np.where(mask.any(axis=1))[0]
	cols = np.where(mask.any(axis=0))[0]
	y0, y1, x0, x1 = rows[0], rows[-1] + 1, cols[0], cols[-1] + 1

	out = np.dstack([rgb, alpha * 255.0]).astype(np.uint8)
	glyph = Image.fromarray(out, "RGBA").crop((x0, y0, x1, y1))

	# Fit into a centered square, preserving aspect.
	gw, gh = glyph.size
	scale = float(FIT) / float(max(gw, gh))
	glyph = glyph.resize((max(1, int(gw * scale)), max(1, int(gh * scale))), Image.LANCZOS)
	canvas = Image.new("RGBA", (TARGET, TARGET), (0, 0, 0, 0))
	canvas.alpha_composite(glyph, ((TARGET - glyph.width) // 2, (TARGET - glyph.height) // 2))
	OUT.mkdir(parents=True, exist_ok=True)
	canvas.save(OUT / ("%s.png" % name))
	print("WROTE %s  (glyph %dx%d)" % ((OUT / ("%s.png" % name)).relative_to(ROOT), gw, gh))


def main() -> None:
	for name, spec in CARDS.items():
		process(name, spec)


if __name__ == "__main__":
	main()
