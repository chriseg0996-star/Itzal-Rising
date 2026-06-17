#!/usr/bin/env python3
"""Process the Gemini faction card-frame art into game-ready assets.

The Gemini frames come with an ornate border around a *checkerboard* centre
(Gemini's fake "transparency") which is actually opaque and would hide the card
content. We crop to the frame's alpha bbox, then flood-fill the centre to TRUE
transparency (stopping at the saturated neon inner glow of the border). Output:
assets/ui/frame_{itzal,decay,ix}.png, used as overlays on the Skirmish cards.

Usage:  python tools/make_faction_frames.py
"""

from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "assets" / "ui" / "icons_src"
OUT = ROOT / "assets" / "ui"
NAMES = ["itzal", "decay", "ix"]
SENT = (255, 0, 255)
THRESH = 92


def main() -> None:
	for name in NAMES:
		src = SRC / ("frame_%s.png.png" % name)
		if not src.exists():
			print("skip %s (missing %s)" % (name, src.name))
			continue
		im = Image.open(src).convert("RGBA")
		im = im.crop(im.getbbox())  # drop the outer transparent margin
		w, h = im.size
		# Flood-fill the centre (and a few interior seeds) to a sentinel colour;
		# the border's bright neon glow is far enough in colour to stop the fill.
		rgb = im.convert("RGB")
		# Interior seeds clear the centre; corner/edge seeds clear the outer
		# checkerboard margin between the ornate art and the texture edge.
		seeds = [(w // 2, h // 2), (w // 2, h // 3), (w // 2, 2 * h // 3),
			(w // 3, h // 2), (2 * w // 3, h // 2),
			(w // 2, int(h * 0.42)), (w // 2, int(h * 0.58)),
			(1, 1), (w - 2, 1), (1, h - 2), (w - 2, h - 2),
			(w // 2, 1), (w // 2, h - 2), (1, h // 2), (w - 2, h // 2)]
		for s in seeds:
			ImageDraw.floodfill(rgb, s, SENT, thresh=THRESH)
		arr = np.array(im)
		flat = np.array(rgb)
		mask = (flat[:, :, 0] == 255) & (flat[:, :, 1] == 0) & (flat[:, :, 2] == 255)
		arr[mask, 3] = 0
		out = Image.fromarray(arr, "RGBA")
		out = out.crop(out.getbbox())
		out.save(OUT / ("frame_%s.png" % name))
		print("WROTE assets/ui/frame_%s.png  (%dx%d, cleared %d px)" % (
			name, out.width, out.height, int(mask.sum())))


if __name__ == "__main__":
	main()
