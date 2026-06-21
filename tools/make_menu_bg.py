#!/usr/bin/env python3
"""Derive the shared secondary-menu background from the main-menu art.

Skirmish/Campaign previously used a cold teal blur of a different mockup, which
clashed with the warm sunset main menu. This blurs + dims the SAME main-menu art
so all three menus share one identity (the blur also hides its baked title/
buttons). Output: assets/ui/menu_bg.png.

Usage:  python tools/make_menu_bg.py
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageEnhance, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "assets" / "sprites" / "mainmenu_reference.png"
OUT = ROOT / "assets" / "ui" / "menu_bg.png"


def main() -> None:
	im = Image.open(SRC).convert("RGB")
	im = im.filter(ImageFilter.GaussianBlur(20))
	im = ImageEnhance.Brightness(im).enhance(0.45)  # darken so panels read
	im.save(OUT)
	print("WROTE %s (%dx%d)" % (OUT.relative_to(ROOT), im.width, im.height))


if __name__ == "__main__":
	main()
