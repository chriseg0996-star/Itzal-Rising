#!/usr/bin/env python3
"""Build 4 stone/ore mine resource sprites from the source renders.

Some sources carry real alpha, others are flattened on a near-white background.
We use the existing alpha when present, otherwise key the near-white background
to transparent, then erode the fringe and crop to content.
Output: assets/world/mine_a..d.png.

Usage:  python tools/make_mine_assets.py
"""

from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "world"
SRC = Path("C:/Users/chris/Downloads")
SOURCES = [
    "ChatGPT Image Jun 21, 2026, 07_32_00 PM.png",
    "ChatGPT Image Jun 21, 2026, 07_29_54 PM.png",
    "ChatGPT Image Jun 21, 2026, 07_27_58 PM.png",
    "ChatGPT Image Jun 21, 2026, 07_27_55 PM.png",
]


def _process(name: str) -> Image.Image:
    im = Image.open(SRC / name).convert("RGBA")
    arr = np.array(im)
    if arr[:, :, 3].min() >= 250:  # opaque: key the near-white background
        rgb = arr[:, :, :3].astype(np.int16)
        spread = rgb.max(2) - rgb.min(2)
        lum = rgb.mean(2)
        arr[(spread <= 18) & (lum >= 232), 3] = 0
        im = Image.fromarray(arr, "RGBA")
    # Erode ~2px to drop the anti-aliased halo, soften, crop to content.
    a = im.getchannel("A").filter(ImageFilter.MinFilter(3)).filter(ImageFilter.MinFilter(3))
    a = a.filter(ImageFilter.GaussianBlur(0.6))
    im.putalpha(a)
    bb = a.getbbox()
    return im.crop(bb) if bb else im


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for i, name in enumerate(SOURCES):
        out = _process(name)
        path = OUT / ("mine_%s.png" % "abcd"[i])
        out.save(path)
        print("WROTE %s (%dx%d)" % (path.relative_to(ROOT), out.width, out.height))


if __name__ == "__main__":
    main()
