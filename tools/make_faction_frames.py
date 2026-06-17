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
from PIL import Image
from scipy import ndimage

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "assets" / "ui" / "icons_src"
OUT = ROOT / "assets" / "ui"
NAMES = ["itzal", "decay", "ix"]
# The dark interior (≈10,10,10) and the outer checkerboard are all neutral grey;
# the ornate borders are coloured (teal stone, tan bone, amber gold). So: build a
# neutral-grey mask (any brightness, both checkerboard shades), then clear the
# connected grey regions that reach the centre/edges or are large — i.e. the
# interior + outer margin — leaving the coloured border intact.
NEUTRAL_TOL = 24
BIG_AREA = 1500


def main() -> None:
	for name in NAMES:
		src = SRC / ("frame_%s.png.png" % name)
		if not src.exists():
			print("skip %s (missing %s)" % (name, src.name))
			continue
		im = Image.open(src).convert("RGBA")
		im = im.crop(im.getbbox())
		arr = np.array(im).astype(np.int32)
		r, g, b, al = arr[:, :, 0], arr[:, :, 1], arr[:, :, 2], arr[:, :, 3]
		mx = np.maximum(np.maximum(r, g), b)
		mn = np.minimum(np.minimum(r, g), b)
		neutral = ((mx - mn) <= NEUTRAL_TOL) & (al > 12)

		lbl, n = ndimage.label(neutral)
		h, w = neutral.shape
		seeds = [(0, 0), (0, w - 1), (h - 1, 0), (h - 1, w - 1), (h // 2, w // 2),
			(0, w // 2), (h - 1, w // 2), (h // 2, 0), (h // 2, w - 1)]
		drop: set = set()
		for (y, x) in seeds:
			if lbl[y, x] != 0:
				drop.add(int(lbl[y, x]))
		if n > 0:
			sizes = ndimage.sum(np.ones_like(lbl), lbl, index=range(1, n + 1))
			for i, s in enumerate(sizes, start=1):
				if s > BIG_AREA:
					drop.add(i)
		clear = np.isin(lbl, list(drop)) if drop else np.zeros_like(neutral)

		out_arr = np.array(im)
		out_arr[clear, 3] = 0
		out = Image.fromarray(out_arr, "RGBA")
		out = out.crop(out.getbbox())
		out.save(OUT / ("frame_%s.png" % name))
		print("WROTE assets/ui/frame_%s.png  (%dx%d, cleared %d px)" % (
			name, out.width, out.height, int(clear.sum())))


if __name__ == "__main__":
	main()
