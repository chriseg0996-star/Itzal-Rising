#!/usr/bin/env python3
"""Generate seamless, DETAILED terrain tiles + a noise map for the splat shader.

The map ground is rendered by a shader that blends several of these tiles by
noise (see assets/shaders/terrain.gdshader), so each tile must be SEAMLESS and
carry baked fine detail (grass flecks, gravel) — that detail is what makes the
ground read as handcrafted up close instead of a flat fill. Seamlessness comes
from sine gratings with INTEGER wavevectors (each wraps the tile exactly).

Outputs (assets/terrain/): grass, grass_dry, dirt, noise, + biome bases
(sand_reef, azure_coast, volcanic).

Usage:  python tools/make_terrain.py
"""

from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
OUT_DIR = ROOT / "assets" / "terrain"
SIZE = 1024   # higher-res tiles so terrain matches the crisp assets


def _noise(size: int, n_waves: int, fmin: float, fmax: float, seed: int) -> np.ndarray:
    """Isotropic seamless value noise in [0,1] (integer wavevectors => seamless)."""
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
        field += np.sin(kx * gx + ky * gy + rng.uniform(0, 2 * np.pi)) / m
        made += 1
    field -= field.min()
    field /= max(field.max(), 1e-6)
    return field


def _tile(base, accent, accent_amt, dark, seed,
          fleck_light=None, fleck_dark=None, pebble=None, pebble_amt=0.0) -> np.ndarray:
    base = np.array(base, float) / 255.0
    accent = np.array(accent, float) / 255.0
    dark = np.array(dark, float) / 255.0
    patches = _noise(SIZE, 40, 2, 9, seed)
    mottle = _noise(SIZE, 48, 9, 22, seed + 7)
    grain = _noise(SIZE, 80, 24, 80, seed + 99) - 0.5
    img = np.empty((SIZE, SIZE, 3))
    for c in range(3):
        ch = base[c] + (accent[c] - base[c]) * (patches * accent_amt)
        ch += (dark[c] - ch) * (mottle * 0.20)   # gentle shading
        ch += grain * 0.025                       # grain unchanged (not more noise)
        img[:, :, c] = ch
    # baked fine detail — same density, but CRISP edges (high slope) so it reads
    # as sharp ground detail, not a soft wash.
    fl = _noise(SIZE, 90, 90, 230, seed + 11)     # finer, sharper flecks
    if fleck_light is not None:
        m = np.clip((fl - 0.80) * 12.0, 0, 1)[:, :, None]
        img = img * (1 - m) + np.array(fleck_light, float) / 255.0 * m
    if fleck_dark is not None:
        m = np.clip((0.20 - fl) * 12.0, 0, 1)[:, :, None]
        img = img * (1 - m) + np.array(fleck_dark, float) / 255.0 * m
    if pebble is not None and pebble_amt > 0.0:
        pb = _noise(SIZE, 60, 70, 170, seed + 23)
        m = np.clip((pb - (1.0 - pebble_amt)) * 8.0, 0, 1)[:, :, None]
        img = img * (1 - m) + np.array(pebble, float) / 255.0 * m
    return np.clip(img, 0, 1)


def _save(name: str, arr: np.ndarray) -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    out = OUT_DIR / ("%s.png" % name)
    Image.fromarray((arr * 255).astype(np.uint8), "RGB").save(out)
    print("WROTE %s (%dx%d)" % (out.relative_to(ROOT), SIZE, SIZE))


def main() -> None:
    _save("grass", _tile((74, 100, 62), (90, 112, 70), 0.4, (54, 76, 48), 1,
                         fleck_light=(98, 122, 76), fleck_dark=(58, 80, 50)))
    _save("grass_dry", _tile((116, 122, 78), (140, 142, 96), 0.4, (94, 100, 62), 5,
                            fleck_light=(150, 150, 104), fleck_dark=(100, 104, 64)))
    _save("dirt", _tile((100, 78, 52), (116, 94, 64), 0.4, (78, 58, 38), 6,
                       pebble=(140, 134, 124), pebble_amt=0.06,
                       fleck_dark=(78, 58, 38)))
    _save("sand_reef", _tile((188, 168, 120), (150, 158, 120), 0.55, (120, 110, 78), 2,
                            pebble=(170, 165, 150), pebble_amt=0.05))
    _save("azure_coast", _tile((150, 178, 196), (120, 156, 176), 0.6, (92, 120, 140), 3))
    _save("volcanic", _tile((74, 58, 52), (110, 64, 42), 0.5, (40, 30, 28), 4,
                           pebble=(120, 110, 105), pebble_amt=0.08))
    # grayscale macro/fine noise for the shader (sampled at several scales)
    nz = _noise(SIZE, 60, 3, 26, 1234)
    _save("noise", np.dstack([nz, nz, nz]))


if __name__ == "__main__":
    main()
