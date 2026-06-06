#!/usr/bin/env python3
"""Strip a baked-in transparency checkerboard from sprite-sheet PNGs.

Some exported sheets flatten the editor's transparency grid into *opaque* grey
pixels instead of keeping a real alpha channel, so the checkerboard renders in
game over the ground. This detects the neutral-grey checkerboard colours from
each image's 1px border (guaranteed background) and makes matching near-neutral
mid-grey pixels transparent -- clearing the surrounding background AND the
islands trapped between limbs -- then saves PNG-32.

Idempotent and safe: a file whose border has no neutral mid-grey checkerboard is
skipped untouched (e.g. a solid-white reference image). Originals are copied to
assets/sprites/_original/ before the first overwrite.

Usage:  python tools/strip_checkerboard.py
"""

from __future__ import annotations

import shutil
from pathlib import Path

import numpy as np
from PIL import Image

ASSETS_DIR = Path(__file__).resolve().parent.parent / "assets" / "sprites"
BACKUP_DIR = ASSETS_DIR / "_original"

NEUTRAL_THRESHOLD = 20   # max RGB channel spread to count a pixel as "neutral grey"
BAND_MIN = 20            # only neutral greys in this luminance band are checkerboard...
BAND_MAX = 255           # ...this excludes near-black and most figure tones (white checker allowed)
TOL = 10                 # expand the keyed band around the detected greys


def _checker_band(arr: np.ndarray):
    """Return (dark_shade, light_shade) luminances of the checkerboard, detected
    from the four corner blocks (guaranteed background). Uses the *dominant*
    neutral shades by pixel count -- the flat checker squares have thousands of
    pixels, while faint ghosts/shadows and figure edges do not -- so the floor
    sits at the real dark checker, never on a sparse darker pixel. This protects
    dark figure detail (e.g. Ix black armor) that is darker than the checker."""
    h, w = arr.shape[0], arr.shape[1]
    bs = max(8, min(200, h // 4, w // 8))
    blocks = [arr[0:bs, 0:bs], arr[0:bs, w - bs:w], arr[h - bs:h, 0:bs], arr[h - bs:h, w - bs:w]]
    samp = np.concatenate([b.reshape(-1, 4) for b in blocks], axis=0).astype(np.int16)
    rgb = samp[:, :3]
    alpha = samp[:, 3]
    spread = rgb.max(axis=1) - rgb.min(axis=1)
    lum = np.rint(rgb.mean(axis=1)).astype(int)
    keep = (alpha > 0) & (spread <= NEUTRAL_THRESHOLD) & (lum >= BAND_MIN) & (lum <= BAND_MAX)
    lums = lum[keep]
    if lums.size == 0:
        return None
    vals, counts = np.unique(lums, return_counts=True)
    dominant = vals[counts >= counts.max() * 0.2]
    return float(dominant.min()), float(dominant.max())


def strip(path: Path) -> bool:
    img = Image.open(path).convert("RGBA")
    arr = np.array(img)  # H x W x 4, uint8

    band = _checker_band(arr)
    if band is None:
        print(f"SKIP  {path.name}: no neutral checkerboard in corners")
        return False

    lo = band[0] - TOL
    hi = band[1] + TOL

    rgb = arr[:, :, :3].astype(np.int16)
    alpha = arr[:, :, 3]
    spread = rgb.max(axis=2) - rgb.min(axis=2)
    lum = rgb.mean(axis=2)

    mask = (alpha > 0) & (spread <= NEUTRAL_THRESHOLD) & (lum >= lo) & (lum <= hi)
    cleared = int(mask.sum())
    arr[mask, 3] = 0

    Image.fromarray(arr, "RGBA").save(path)
    print(f"FIXED {path.name}: grey band {lo:.0f}-{hi:.0f}, cleared {cleared} px")
    return True


def main() -> None:
    import sys
    args = sys.argv[1:]
    if args:
        files = [Path(a).resolve() for a in args if Path(a).exists()]
    else:
        files = sorted(ASSETS_DIR.glob("*.png.png"))
    if not files:
        print(f"No input files (args or *.png.png in {ASSETS_DIR})")
        return
    BACKUP_DIR.mkdir(exist_ok=True)
    for f in files:
        backup = BACKUP_DIR / f.name
        if not backup.exists():
            shutil.copy2(f, backup)
    for f in files:
        strip(f)


if __name__ == "__main__":
    main()
