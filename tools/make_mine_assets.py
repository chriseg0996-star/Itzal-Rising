#!/usr/bin/env python3
"""Crop the 2x2 gold-mine reference sheet into 4 transparent mine sprites.

The source flattens the editor transparency grid into opaque light grey/white
checker pixels. We split into quadrants, key out the neutral-light checker to
real alpha (band detected from each quadrant's border), erode the fringe, and
trim to content. Output: assets/world/mine_a..d.png (used by the gold node).

Usage:  python tools/make_mine_assets.py
"""

from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "world"
SRC = "C:/Users/chris/Downloads/ChatGPT Image Jun 21, 2026, 07_44_15 PM.png"


def _key_checker(q: np.ndarray) -> np.ndarray:
    h, w = q.shape[:2]
    border = np.concatenate([
        q[0:8, :].reshape(-1, 4), q[h - 8:h, :].reshape(-1, 4),
        q[:, 0:8].reshape(-1, 4), q[:, w - 8:w].reshape(-1, 4)]).astype(np.int16)
    brgb = border[:, :3]
    neutral = (brgb.max(1) - brgb.min(1)) <= 24
    blum = brgb.mean(1)
    lo = float(blum[neutral].min()) - 12 if neutral.any() else 165.0
    rgb = q[:, :, :3].astype(np.int16)
    spread = rgb.max(2) - rgb.min(2)
    lum = rgb.mean(2)
    q[(spread <= 26) & (lum >= lo), 3] = 0
    return q


def _process(q: np.ndarray) -> Image.Image:
    img = Image.fromarray(_key_checker(q), "RGBA")
    a = img.getchannel("A").filter(ImageFilter.MinFilter(3)).filter(ImageFilter.MinFilter(3))
    a = a.filter(ImageFilter.GaussianBlur(0.6))
    img.putalpha(a)
    bb = a.getbbox()
    return img.crop(bb) if bb else img


def main() -> None:
    im = np.array(Image.open(SRC).convert("RGBA"))
    h, w = im.shape[:2]
    hw, hh = w // 2, h // 2
    quads = {
        "mine_a": im[0:hh, 0:hw], "mine_b": im[0:hh, hw:w],
        "mine_c": im[hh:h, 0:hw], "mine_d": im[hh:h, hw:w],
    }
    OUT.mkdir(parents=True, exist_ok=True)
    for name, q in quads.items():
        out = _process(q.copy())
        path = OUT / ("%s.png" % name)
        out.save(path)
        print("WROTE %s (%dx%d)" % (path.relative_to(ROOT), out.width, out.height))


if __name__ == "__main__":
    main()
