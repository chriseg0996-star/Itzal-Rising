#!/usr/bin/env python3
"""Generate placeholder preview thumbnails for the three maps that have no art.

Each variant is the Jungle Basin thumbnail flipped/rotated (so the layouts read
as different maps) and duotone-tinted to match the map's ground tint in
MapConfig. Output lands next to the source; skirmish_setup.gd auto-discovers
assets/ui/map_<slug>.png, so no code change is needed.

Usage:  python tools/make_map_previews.py
"""

from pathlib import Path

from PIL import Image, ImageOps

UI_DIR = Path(__file__).resolve().parent.parent / "assets" / "ui"
SOURCE = UI_DIR / "map_jungle_basin.png"

# (output name, transpose, duotone black point, duotone white point)
VARIANTS = [
    ("map_sunken_reef.png", Image.Transpose.FLIP_LEFT_RIGHT, "#06283A", "#2FA8A0"),
    ("map_azure_coast.png", Image.Transpose.FLIP_TOP_BOTTOM, "#0A2A4A", "#57A8E0"),
    ("map_volcanic_crags.png", Image.Transpose.ROTATE_180, "#2A0F08", "#D86A2F"),
]


def main() -> None:
    src = Image.open(SOURCE).convert("RGB")
    for name, transpose, black, white in VARIANTS:
        img = src.transpose(transpose)
        img = ImageOps.colorize(ImageOps.grayscale(img), black=black, white=white)
        out = UI_DIR / name
        img.save(out)
        print(f"WROTE {out.name} {img.size}")


if __name__ == "__main__":
    main()
