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
BAND_MIN = 70            # only neutral greys in this luminance band are checkerboard...
BAND_MAX = 225           # ...this excludes pure white/black and most figure tones
TOL = 10                 # expand the keyed band around the detected greys


def _border_neutral_lums(arr: np.ndarray) -> np.ndarray:
    """Luminances of opaque, neutral, mid-grey pixels on the 1px border."""
    rows = np.concatenate([arr[0, :, :], arr[-1, :, :]], axis=0)
    cols = np.concatenate([arr[:, 0, :], arr[:, -1, :]], axis=0)
    border = np.concatenate([rows, cols], axis=0).astype(np.int16)
    rgb = border[:, :3]
    alpha = border[:, 3]
    spread = rgb.max(axis=1) - rgb.min(axis=1)
    lum = rgb.mean(axis=1)
    keep = (alpha > 0) & (spread <= NEUTRAL_THRESHOLD) & (lum >= BAND_MIN) & (lum <= BAND_MAX)
    return lum[keep]


def strip(path: Path) -> bool:
    img = Image.open(path).convert("RGBA")
    arr = np.array(img)  # H x W x 4, uint8

    border_lums = _border_neutral_lums(arr)
    if border_lums.size == 0:
        print(f"SKIP  {path.name}: no neutral mid-grey checkerboard on border")
        return False

    lo = float(border_lums.min()) - TOL
    hi = float(border_lums.max()) + TOL

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
    files = sorted(ASSETS_DIR.glob("*.png.png"))
    if not files:
        print(f"No *.png.png files found in {ASSETS_DIR}")
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
