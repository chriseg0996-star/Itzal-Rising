#!/usr/bin/env python3
"""Generate seamless tileable biome ground textures for the RTS world.

Each map's ground is one Sprite2D with texture_repeat, so the tiles must be
SEAMLESS (wrap on both axes). Seamlessness comes from summing sine waves with
INTEGER wavevectors (kx, ky) — each term is exactly periodic over the tile.
Using many random integer wavevectors (rather than a few fixed orientations)
makes the noise isotropic, which kills the diagonal moiré "fabric" banding the
old 4-grating version produced.

Keep luma in ~0.4-0.6 so per-map MapConfig tints (Jungle = white = identity,
Volcanic = warm 1.15x) don't blow out to white.

Usage:  python tools/make_terrain.py
"""

from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
OUT_DIR = ROOT / "assets" / "terrain"
SIZE = 512


def _seamless_noise(size: int, n_waves: int, fmin: float, fmax: float, seed: int) -> np.ndarray:
    """Isotropic seamless value noise: sum of sine gratings with random INTEGER
    wavevectors of magnitude in [fmin, fmax], 1/|k| (pink) weighting. Integer
    wavevectors => each grating wraps the tile exactly => seamless. Returns a
    field in [-1, 1]."""
    rng = np.random.default_rng(seed)
    xs = np.linspace(0.0, 2.0 * np.pi, size, endpoint=False)
    gx, gy = np.meshgrid(xs, xs)
    field = np.zeros((size, size), dtype=np.float64)
    made = 0
    while made < n_waves:
        kx = int(rng.integers(-int(fmax), int(fmax) + 1))
        ky = int(rng.integers(-int(fmax), int(fmax) + 1))
        m = float(np.hypot(kx, ky))
        if m < fmin or m > fmax:
            continue
        ph = rng.uniform(0.0, 2.0 * np.pi)
        field += np.sin(kx * gx + ky * gy + ph) / m
        made += 1
    field -= field.min()
    field /= max(field.max(), 1e-6)
    return field * 2.0 - 1.0


def make_tile(name: str, base_rgb, accent_rgb, accent_amount: float, seed: int,
              dark_rgb=None) -> None:
    """Blend base->accent by a low-frequency seamless mask (broad tonal patches),
    darken with a second mask (mottled shade), and add fine grain so it reads as
    organic ground, not a flat fill."""
    base = np.array(base_rgb, dtype=np.float64) / 255.0
    accent = np.array(accent_rgb, dtype=np.float64) / 255.0
    dark = np.array(dark_rgb if dark_rgb else accent_rgb, dtype=np.float64) / 255.0

    patches = _seamless_noise(SIZE, 40, 2.0, 9.0, seed) * 0.5 + 0.5          # broad tone
    mottle = _seamless_noise(SIZE, 48, 9.0, 22.0, seed + 7) * 0.5 + 0.5      # mid shade
    grain = _seamless_noise(SIZE, 80, 24.0, 80.0, seed + 99) * 0.045         # fine grain

    img = np.empty((SIZE, SIZE, 3), dtype=np.float64)
    for c in range(3):
        chan = base[c] + (accent[c] - base[c]) * (patches * accent_amount)
        chan += (dark[c] - chan) * (mottle * 0.28)
        chan += grain
        img[:, :, c] = np.clip(chan, 0.0, 1.0)

    out = OUT_DIR / ("%s.png" % name)
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    Image.fromarray((img * 255).astype(np.uint8), "RGB").save(out)
    print("WROTE %s (%dx%d)" % (out.relative_to(ROOT), SIZE, SIZE))


def main() -> None:
    # base, accent, accent_amount, seed, dark
    make_tile("grass", (74, 102, 64), (96, 120, 70), 0.7, 1, dark_rgb=(40, 58, 36))
    make_tile("sand_reef", (188, 168, 120), (150, 158, 120), 0.55, 2, dark_rgb=(120, 110, 78))
    make_tile("azure_coast", (150, 178, 196), (120, 156, 176), 0.6, 3, dark_rgb=(92, 120, 140))
    make_tile("volcanic", (74, 58, 52), (110, 64, 42), 0.5, 4, dark_rgb=(40, 30, 28))


if __name__ == "__main__":
    main()
