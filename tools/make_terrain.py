#!/usr/bin/env python3
"""Generate seamless tileable biome ground textures for the RTS world.

Each map's flat 2048x2048 ground is a single Sprite2D with texture_repeat
enabled, so these tiles must be SEAMLESS (wrap top/bottom and left/right).
Seamlessness is achieved by building the noise from sine waves whose periods
divide the tile size exactly — so the pattern is continuous across the edge.

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


def _seamless_noise(size: int, freqs: list[int], seed: int) -> np.ndarray:
    """Sum of sine gratings at integer frequencies (cycles per tile) with random
    phases/orientations. Integer freqs => period divides the tile => seamless.
    Returns a float field roughly in [-1, 1]."""
    rng = np.random.default_rng(seed)
    xs = np.linspace(0.0, 2.0 * np.pi, size, endpoint=False)
    gx, gy = np.meshgrid(xs, xs)
    field = np.zeros((size, size), dtype=np.float64)
    for f in freqs:
        ph = rng.uniform(0.0, 2.0 * np.pi)
        ang = rng.uniform(0.0, 2.0 * np.pi)
        ux, uy = np.cos(ang), np.sin(ang)
        field += np.sin(f * (gx * ux + gy * uy) + ph) / f
    field -= field.min()
    field /= max(field.max(), 1e-6)
    return field * 2.0 - 1.0  # [-1, 1]


def make_tile(name: str, base_rgb, accent_rgb, accent_amount: float,
              freqs: list[int], seed: int) -> None:
    """Blend a base colour with an accent by a seamless noise mask, plus a fine
    grain so it doesn't look flat. Output stays mid-luma."""
    base = np.array(base_rgb, dtype=np.float64) / 255.0
    accent = np.array(accent_rgb, dtype=np.float64) / 255.0

    mask = (_seamless_noise(SIZE, freqs, seed) * 0.5 + 0.5)  # [0,1]
    grain = _seamless_noise(SIZE, [32, 48, 64], seed + 99) * 0.05

    img = np.empty((SIZE, SIZE, 3), dtype=np.float64)
    for c in range(3):
        chan = base[c] + (accent[c] - base[c]) * (mask * accent_amount) + grain
        img[:, :, c] = np.clip(chan, 0.0, 1.0)

    out = OUT_DIR / ("%s.png" % name)
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    Image.fromarray((img * 255).astype(np.uint8), "RGB").save(out)
    print("WROTE %s (%dx%d)" % (out.relative_to(ROOT), SIZE, SIZE))


def main() -> None:
    # base, accent, accent_amount, frequencies, seed
    make_tile("grass", (62, 107, 71), (44, 84, 54), 0.7, [3, 5, 8, 13], 1)
    make_tile("sand_reef", (188, 168, 120), (120, 150, 140), 0.55, [2, 4, 7, 11], 2)
    make_tile("azure_coast", (150, 178, 196), (110, 150, 180), 0.6, [3, 6, 9, 14], 3)
    make_tile("volcanic", (74, 58, 52), (120, 60, 38), 0.5, [4, 6, 10, 16], 4)


if __name__ == "__main__":
    main()
