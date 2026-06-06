#!/usr/bin/env python3
"""Inject an AnimatedSprite2D (with a sliced SpriteFrames) into each unit scene.

Each sheet is a uniform 6x2 grid. Frame -> clip split (per spec default):
  row 0: idle (cols 0-1), walk (cols 2-5)
  row 1: <attack|harvest> (cols 0-2), death (cols 3-5)

Adds, per scene: 1 Texture2D ext_resource, 12 AtlasTexture sub_resources, 1
SpriteFrames sub_resource, and an AnimatedSprite2D node (scale 0.08, centered).
Idempotent-ish: refuses to run twice (skips a scene that already has the node).
"""

import re
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SPEED = 8.0

SCENES = [
    ("scenes/units/Soldier.tscn",        "soldier_sheet.png",          "attack",  False),
    ("scenes/units/Archer.tscn",         "archer_sheet.png",           "attack",  False),
    ("scenes/units/EnemySoldier.tscn",   "enemy_soldier_sheet.png",    "attack",  False),
    ("scenes/units/IxLatticeGuard.tscn", "ix_lattice_guard_sheet.png", "attack",  False),
    ("scenes/units/EnemyVillager.tscn",  "enemy_villager_sheet.png",   "harvest", True),
    ("scenes/units/IxWeaver.tscn",       "ix_weaver_sheet.png",        "harvest", True),
]


def grid(w, h, cols=6, rows=2):
    xs = [round(c * w / cols) for c in range(cols + 1)]
    ys = [round(r * h / rows) for r in range(rows + 1)]
    def region(row, col):
        return (xs[col], ys[row], xs[col + 1] - xs[col], ys[row + 1] - ys[row])
    return region


def build(scene_rel, sheet, third, third_loop):
    scene = ROOT / scene_rel
    text = scene.read_text(encoding="utf-8")
    if "AnimatedSprite2D" in text:
        print(f"SKIP {scene_rel}: already has an AnimatedSprite2D")
        return

    w, h = Image.open(ROOT / "assets" / "sprites" / sheet).size
    region = grid(w, h)

    clips = [
        ("idle",  [(0, 0), (0, 1)], True),
        ("walk",  [(0, 2), (0, 3), (0, 4), (0, 5)], True),
        (third,   [(1, 0), (1, 1), (1, 2)], third_loop),
        ("death", [(1, 3), (1, 4), (1, 5)], False),
    ]

    tex_id = "sheet_tex"
    atlas_blocks, anim_entries = [], []
    for name, cells, loop in clips:
        frame_refs = []
        for i, (r, c) in enumerate(cells):
            aid = f"AT_{name}_{i}"
            x, y, cw, ch = region(r, c)
            atlas_blocks.append(
                f'[sub_resource type="AtlasTexture" id="{aid}"]\n'
                f'atlas = ExtResource("{tex_id}")\n'
                f'region = Rect2({x}, {y}, {cw}, {ch})\n'
            )
            frame_refs.append(
                '{\n"duration": 1.0,\n"texture": SubResource("%s")\n}' % aid
            )
        anim_entries.append(
            '{\n"frames": [%s],\n"loop": %s,\n"name": &"%s",\n"speed": %s\n}'
            % (", ".join(frame_refs), "true" if loop else "false", name, SPEED)
        )

    sf_block = (
        '[sub_resource type="SpriteFrames" id="SpriteFrames_unit"]\n'
        "animations = [%s]\n" % ", ".join(anim_entries)
    )
    ext_line = f'[ext_resource type="Texture2D" path="res://assets/sprites/{sheet}" id="{tex_id}"]\n'
    node_block = (
        '\n[node name="AnimatedSprite2D" type="AnimatedSprite2D" parent="."]\n'
        "scale = Vector2(0.08, 0.08)\n"
        'sprite_frames = SubResource("SpriteFrames_unit")\n'
        'animation = &"idle"\n'
        "centered = true\n"
    )

    # bump load_steps by (1 ext + 12 atlas + 1 spriteframes) = 14
    text = re.sub(r"load_steps=(\d+)", lambda m: f"load_steps={int(m.group(1)) + 14}", text, count=1)

    lines = text.splitlines(keepends=True)
    # insert ext_resource after the last existing ext_resource line
    last_ext = max(i for i, ln in enumerate(lines) if ln.startswith("[ext_resource"))
    lines.insert(last_ext + 1, ext_line)
    # insert sub_resources just before the first node
    first_node = next(i for i, ln in enumerate(lines) if ln.startswith("[node "))
    lines.insert(first_node, "\n".join(atlas_blocks) + "\n" + sf_block + "\n")
    # append AnimatedSprite2D node at the end (drawn on top; placeholder hidden in script)
    out = "".join(lines)
    if not out.endswith("\n"):
        out += "\n"
    out += node_block
    scene.write_text(out, encoding="utf-8")
    print(f"OK   {scene_rel}: clips idle/walk/{third}/death, {w}x{h}")


def main():
    for s in SCENES:
        build(*s)


if __name__ == "__main__":
    main()
