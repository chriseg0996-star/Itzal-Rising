#!/usr/bin/env python3
"""Crop the 2x2 forest reference sheet into 4 transparent forest sprites.

The source flattens the editor transparency grid into opaque light grey/white
checker pixels. We split into quadrants, key out the neutral-light checker to
real alpha (detected from each quadrant's border, so it adapts), feather the
1px edge to kill the grey halo, then trim to the content bbox.

Output: assets/world/forest_a.png .. forest_d.png  (Godot assets path; the game
is Godot, not a /public web project).

Usage:  python tools/make_forest_assets.py "<source.png>"
"""

from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "world"
DEFAULT_SRC = "C:/Users/chris/Downloads/ChatGPT Image Jun 21, 2026, 06_30_11 PM.png"


def _key_checker(q: np.ndarray) -> np.ndarray:
    """Make the neutral light checkerboard transparent. Band detected from the
    8px border (guaranteed background)."""
    h, w = q.shape[:2]
    border = np.concatenate([
        q[0:8, :].reshape(-1, 4), q[h - 8:h, :].reshape(-1, 4),
        q[:, 0:8].reshape(-1, 4), q[:, w - 8:w].reshape(-1, 4)]).astype(np.int16)
    brgb = border[:, :3]
    bspread = brgb.max(1) - brgb.min(1)
    blum = brgb.mean(1)
    neutral = bspread <= 24
    lo = float(blum[neutral].min()) - 12 if neutral.any() else 165.0

    rgb = q[:, :, :3].astype(np.int16)
    spread = rgb.max(2) - rgb.min(2)
    lum = rgb.mean(2)
    mask = (spread <= 26) & (lum >= lo)
    q[mask, 3] = 0
    return q


def _process(q: np.ndarray) -> Image.Image:
    q = _key_checker(q)
    img = Image.fromarray(q, "RGBA")
    # Erode the alpha ~2px so the light anti-aliased fringe (white halo) is gone,
    # then a tiny blur to keep the cut edge soft rather than jagged.
    a = img.getchannel("A")
    a = a.filter(ImageFilter.MinFilter(3)).filter(ImageFilter.MinFilter(3))
    a = a.filter(ImageFilter.GaussianBlur(0.6))
    img.putalpha(a)
    bbox = a.getbbox()
    if bbox:
        img = img.crop(bbox)
    return img


def main() -> None:
    src = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_SRC
    im = np.array(Image.open(src).convert("RGBA"))
    h, w = im.shape[:2]
    hw, hh = w // 2, h // 2
    quads = {
        "forest_a": im[0:hh, 0:hw],
        "forest_b": im[0:hh, hw:w],
        "forest_c": im[hh:h, 0:hw],
        "forest_d": im[hh:h, hw:w],
    }
    OUT.mkdir(parents=True, exist_ok=True)
    for name, q in quads.items():
        out = _process(q.copy())
        path = OUT / ("%s.png" % name)
        out.save(path)
        print("WROTE %s (%dx%d)" % (path.relative_to(ROOT), out.width, out.height))


if __name__ == "__main__":
    main()
