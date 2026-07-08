# Slice the villager animation sheet (Gemini/ChatGPT gen, baked checkerboard bg,
# irregular grid) into a clean uniform SpriteFrames sheet for villager.gd.
# Keys out the light checkerboard, detects 5 row bands + variable frames per row
# by content projection, then feet-aligns each frame (global scale) into 96px
# cells: rows = idle/walk/harvest/build/death. Re-run after regenerating the art.
import os, sys, numpy as np, statistics
from PIL import Image
src = sys.argv[1] if len(sys.argv) > 1 else os.path.expanduser(
    '~/Downloads/ChatGPT Image Jul 7, 2026, 10_21_50 PM.png')
im = Image.open(src).convert('RGB')
a = np.asarray(im).astype(np.int32); H, W, _ = a.shape
lum = a.mean(axis=2); sat = a.max(axis=2) - a.min(axis=2)
fg = ~((lum > 190) & (sat < 22))
full = Image.fromarray(np.dstack([np.asarray(im), np.where(fg, 255, 0).astype(np.uint8)]).astype(np.uint8), 'RGBA')
def bands_of(mask):
    s = mask.sum(axis=1); t = s.max() * 0.06; out = []; inb = False
    for y in range(len(s)):
        if s[y] > t and not inb: y0 = y; inb = True
        elif s[y] <= t and inb:
            if y - y0 > 40: out.append((y0, y))
            inb = False
    if inb: out.append((y0, len(s)))
    return out
def frames_of(y0, y1):
    col = fg[y0:y1].sum(axis=0); t = col.max() * 0.06; out = []; inr = False
    for x in range(W):
        if col[x] > t and not inr: x0 = x; inr = True
        elif col[x] <= t and inr:
            if x - x0 > 20: out.append((x0, x))
            inr = False
    if inr: out.append((x0, W))
    return out
bands = bands_of(fg)
CELL, COLS, ROWS = 96, 8, 5
ref = []
for r in (0, 1):
    y0, y1 = bands[r]
    for (x0, x1) in frames_of(y0, y1):
        bb = full.crop((x0, y0, x1, y1)).getbbox()
        if bb: ref.append(bb[3] - bb[1])
scale = (CELL - 8) / statistics.median(ref)
sheet = Image.new('RGBA', (CELL * COLS, CELL * ROWS), (0, 0, 0, 0)); counts = []
for r in range(ROWS):
    y0, y1 = bands[r]; fr = frames_of(y0, y1); counts.append(len(fr))
    for i, (x0, x1) in enumerate(fr[:COLS]):
        c = full.crop((x0, y0, x1, y1)); bb = c.getbbox()
        if bb: c = c.crop(bb)
        nc = c.resize((max(1, int(c.width * scale)), max(1, int(c.height * scale))), Image.LANCZOS)
        sheet.alpha_composite(nc, (i * CELL + (CELL - nc.width) // 2, r * CELL + (CELL - nc.height - 3)))
sheet.save('assets/units/villager_sheet.png')
print('villager_sheet.png frame counts:', counts)
