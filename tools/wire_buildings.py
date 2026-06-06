#!/usr/bin/env python3
"""Wire a static building sprite (Sprite2D) into each building scene.

Per scene: add a Texture2D ext_resource, disable the TextureGenerator placeholder
(sprite_asset = ""), hide the placeholder ColorRect + Label, and append a Sprite2D
(scale 0.08, offset = (0, -H/2) so the image's base sits on the tile origin).
Idempotent: skips a scene that already has a BuildingSprite.
"""

import re
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SCALE = 0.08

BUILDINGS = [
    ("scenes/buildings/TownCenter.tscn",      "tc_sheet.png"),
    ("scenes/buildings/Barracks.tscn",        "barracks_sheet.png"),
    ("scenes/buildings/Tower.tscn",           "tower_sheet.png"),
    ("scenes/buildings/EnemyTownCenter.tscn", "enemy_tc_sheet.png"),
    ("scenes/buildings/EnemyBarracks.tscn",   "enemy_barracks_sheet.png"),
]


def wire(scene_rel, tex):
    scene = ROOT / scene_rel
    text = scene.read_text(encoding="utf-8")
    if "BuildingSprite" in text:
        print(f"SKIP {scene_rel}: already wired")
        return
    h = Image.open(ROOT / "assets" / "sprites" / tex).size[1]
    offy = h // 2

    text = re.sub(r"load_steps=(\d+)", lambda m: f"load_steps={int(m.group(1)) + 1}", text, count=1)
    text = re.sub(r'sprite_asset = "[^"]*"', 'sprite_asset = ""', text, count=1)

    lines = text.splitlines(keepends=True)
    last_ext = max(i for i, ln in enumerate(lines) if ln.startswith("[ext_resource"))
    lines.insert(last_ext + 1, f'[ext_resource type="Texture2D" path="res://assets/sprites/{tex}" id="bld_tex"]\n')
    text = "".join(lines)

    text = text.replace(
        '[node name="Sprite" type="ColorRect" parent="."]\n',
        '[node name="Sprite" type="ColorRect" parent="."]\nvisible = false\n', 1)
    text = text.replace(
        '[node name="Label" type="Label" parent="."]\n',
        '[node name="Label" type="Label" parent="."]\nvisible = false\n', 1)

    if not text.endswith("\n"):
        text += "\n"
    text += (
        '\n[node name="BuildingSprite" type="Sprite2D" parent="."]\n'
        f'texture = ExtResource("bld_tex")\n'
        f'scale = Vector2({SCALE}, {SCALE})\n'
        f'offset = Vector2(0, -{offy})\n'
    )
    scene.write_text(text, encoding="utf-8")
    print(f"OK   {scene_rel}: {tex} (offset_y=-{offy})")


def main():
    for s in BUILDINGS:
        wire(*s)


if __name__ == "__main__":
    main()
