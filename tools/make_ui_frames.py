#!/usr/bin/env python3
"""Generate the HUD panel frames (nine-patch textures) — the AAA plate look.

Two tiers give the HUD hierarchy instead of identical flat boxes:
  frame_console.png — heavy bottom-console plate: chamfered top corners,
                      vertical gradient, bright top edge, inner shadow.
  frame_chip.png    — light chip for secondary panels: small chamfer, flat
                      fill, thin border.
Both are used as StyleBoxTexture with matching margins (MenuKit helpers).

Usage:  python tools/make_ui_frames.py
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "ui"

TEAL = (0, 217, 199)


def _chamfer_mask(size: int, cut: int) -> Image.Image:
    m = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(m)
    d.polygon([(cut, 0), (size - 1 - cut, 0), (size - 1, cut), (size - 1, size - 1),
               (0, size - 1), (0, cut)], fill=255)
    return m


def console(size: int = 96, cut: int = 14) -> None:
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    # vertical gradient fill
    grad = Image.new("RGBA", (size, size))
    gd = ImageDraw.Draw(grad)
    top = (16, 22, 30, 242)
    bot = (9, 12, 17, 248)
    for y in range(size):
        t = y / (size - 1)
        gd.line([(0, y), (size, y)],
                fill=tuple(int(top[i] + (bot[i] - top[i]) * t) for i in range(4)))
    mask = _chamfer_mask(size, cut)
    img.paste(grad, (0, 0), mask)
    d = ImageDraw.Draw(img)
    outline = [(cut, 0), (size - 1 - cut, 0), (size - 1, cut), (size - 1, size - 1),
               (0, size - 1), (0, cut), (cut, 0)]
    # bright top edge (the "lit rim"), dimmer sides/bottom
    d.line([(cut, 0), (size - 1 - cut, 0)], fill=TEAL + (150,), width=2)
    d.line([(cut, 0), (0, cut)], fill=TEAL + (150,), width=2)
    d.line([(size - 1 - cut, 0), (size - 1, cut)], fill=TEAL + (150,), width=2)
    d.line([(0, cut), (0, size - 1)], fill=TEAL + (55,), width=1)
    d.line([(size - 1, cut), (size - 1, size - 1)], fill=TEAL + (55,), width=1)
    d.line([(0, size - 1), (size - 1, size - 1)], fill=TEAL + (35,), width=1)
    # subtle inner glow line under the top rim
    d.line([(cut + 2, 3), (size - 3 - cut, 3)], fill=TEAL + (35,), width=1)
    img.save(OUT / "frame_console.png")
    print("WROTE assets/ui/frame_console.png")


def chip(size: int = 48, cut: int = 7) -> None:
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    fill = Image.new("RGBA", (size, size), (12, 16, 22, 216))
    img.paste(fill, (0, 0), _chamfer_mask(size, cut))
    d = ImageDraw.Draw(img)
    d.line([(cut, 0), (size - 1 - cut, 0), (size - 1, cut), (size - 1, size - 1),
            (0, size - 1), (0, cut), (cut, 0)], fill=TEAL + (70,), width=1)
    img.save(OUT / "frame_chip.png")
    print("WROTE assets/ui/frame_chip.png")


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    console()
    chip()
