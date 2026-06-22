#!/usr/bin/env python3
"""Build 4 berry-bush resource sprites from the 3 source renders.

The sources already carry real alpha (transparent background), so we just crop
each to its content box. The 4th variant is a horizontal mirror of the 1st for
extra silhouette variety. Output: assets/world/berry_a..d.png.

Usage:  python tools/make_berry_assets.py
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageOps

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "world"
SRC = Path("C:/Users/chris/Downloads")
SOURCES = [
    "ChatGPT Image Jun 21, 2026, 07_05_16 PM.png",
    "ChatGPT Image Jun 21, 2026, 07_04_29 PM.png",
    "ChatGPT Image Jun 21, 2026, 07_03_14 PM.png",
]


def _crop(name: str) -> Image.Image:
    im = Image.open(SRC / name).convert("RGBA")
    bb = im.getchannel("A").getbbox()
    return im.crop(bb) if bb else im


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    a = _crop(SOURCES[0])
    b = _crop(SOURCES[1])
    c = _crop(SOURCES[2])
    d = ImageOps.mirror(a)  # 4th variant: mirror of the first
    for name, img in [("berry_a", a), ("berry_b", b), ("berry_c", c), ("berry_d", d)]:
        path = OUT / ("%s.png" % name)
        img.save(path)
        print("WROTE %s (%dx%d)" % (path.relative_to(ROOT), img.width, img.height))


if __name__ == "__main__":
    main()
