#!/usr/bin/env python3
"""Slice the generated UI art pack into game assets.

Inputs (Downloads): icon sheet 5x3, two panel plates, three faction emblems.
Outputs: assets/ui/icons/* (consistent set), assets/ui/frame_console.png /
frame_chip.png (nine-patch plates), assets/ui/emblem_{0,1,2}.png.
"""
from PIL import Image
DL = "C:/Users/chris/Downloads/"
ICONS = DL + "ChatGPT Image Jul 2, 2026, 10_13_50 PM.png"
PANELS = DL + "23ec1e91-75c0-42a7-bee4-9e40f759b5fb.png"
EMBLEMS = DL + "8d2af34f-e4f6-4483-86b7-499a6038fb35.png"

def cell_crop(im, cx, cy, cols, rows):
    w, h = im.size
    cw, ch = w / cols, h / rows
    box = (int(cx * cw), int(cy * ch), int((cx + 1) * cw), int((cy + 1) * ch))
    c = im.crop(box)
    bb = c.getchannel("A").getbbox()
    return c.crop(bb) if bb else c

def square(im, size):
    side = max(im.size)
    sq = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    sq.paste(im, ((side - im.width) // 2, (side - im.height) // 2))
    return sq.resize((size, size), Image.LANCZOS)

# 1) icons 5x3
names = [
    ["bld_tc", "bld_farm", "bld_storehouse", "bld_house", "bld_pylon"],
    ["bld_barracks", "bld_tower", "bld_monument", "bld_beacon", "unit_villager"],
    ["unit_soldier", "unit_archer", "unit_raider", "unit_siege", "icon_attack"],
]
sheet = Image.open(ICONS).convert("RGBA")
for r in range(3):
    for c in range(5):
        icon = square(cell_crop(sheet, c, r, 5, 3), 96)
        icon.save("assets/ui/icons/%s.png" % names[r][c])
        print("icon", names[r][c])

# 2) panels: left square console, right chip
p = Image.open(PANELS).convert("RGBA")
w, h = p.size
left = p.crop((0, 0, int(w * 0.55), h)); bb = left.getchannel("A").getbbox(); left = left.crop(bb)
right = p.crop((int(w * 0.55), 0, w, h)); bb = right.getchannel("A").getbbox(); right = right.crop(bb)
left.save("assets/ui/frame_console.png")
right.save("assets/ui/frame_chip.png")
print("console", left.size, "chip", right.size)

# 3) emblems: thirds
e = Image.open(EMBLEMS).convert("RGBA")
for i in range(3):
    em = cell_crop(e, i, 0, 3, 1)
    square(em, 256).save("assets/ui/emblem_%d.png" % i)
    print("emblem", i)
