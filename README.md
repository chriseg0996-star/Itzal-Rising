# RTS Game

A simple RTS game inspired by Age of Empires, built in Godot 4.

## Controls

| Input | Action |
| --- | --- |
| `W` `A` `S` `D` / mouse edge | Pan camera |
| Mouse wheel | Zoom in / out |
| Left click | Select unit or building |
| Left click + drag | Box-select multiple units |
| Right click on ground | Move selected units |
| Right click on tree / gold mine | Harvest resource (villagers) |
| `G` + right click | Attack-move (engage enemies en route) |
| `B` | Enter Barracks placement mode |
| `T` | Enter Town Center placement mode |
| Right click (in placement mode) | Cancel placement |
| `Esc` | Pause / resume |

## Objective

Destroy the enemy Town Center (purple base, bottom-right) to win. If your Town Center is destroyed, you lose.

You start with:

- 1 Town Center
- 3 villagers
- 200 wood, 200 food, 100 gold

The enemy AI gathers resources, builds a Barracks, and sends attack waves once it has 3 or more soldiers. After 3 minutes of play, the AI cycles 50% faster.

## Build & run

### Requirements

- Godot Engine 4.3 or newer (tested on 4.6).

### Run from the editor

1. Open the project folder in Godot.
2. Press `F5` or click the Play button. The Main Menu loads first; click **Play** to start a match.

### Export builds

The included `export_presets.cfg` defines two targets:

- **Windows Desktop** → `builds/windows/rts_game.exe`
- **Web** → `builds/web/index.html` (for itch.io and similar)

To export:

1. Install the matching export templates via *Editor → Manage Export Templates…*.
2. Open *Project → Export…*, pick the preset, and click *Export Project*.

For the Web build on itch.io, enable **SharedArrayBuffer support** in the project page settings — Godot 4 requires cross-origin isolation headers.

## Project layout

```
scenes/        Godot scene files (.tscn)
  buildings/   TownCenter, Barracks, enemy variants
  camera/      RTS camera
  ui/          HUD, BuildingPanel, MainMenu, PausePanel, Minimap, GameEndPanel
  units/       Villager, Soldier, EnemySoldier, EnemyVillager
  world/       World, Ground, ResourceNode, GoldMine, EnemyBase
scripts/       GDScript files mirroring the scene layout
  ai/          EnemyAI singleton
  buildings/   Building base + placer
  camera/      Camera controller
  managers/    ResourceManager
  ui/          UI controllers
  units/       Villager, Soldier, SelectionManager, SelectionBox
  world/       ResourceNode logic
assets/        Placeholder folder for future art
project.godot  Godot project config
export_presets.cfg  Windows + Web export presets
```
# Itzal-Rising
