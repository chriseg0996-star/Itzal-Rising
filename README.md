# Itzal Rising

A single-player RTS inspired by *Age of Empires*, built in **Godot 4.6**.

## Game modes

| Mode | Description |
| --- | --- |
| **Campaign** | 5 missions with escalating difficulty and modifiers |
| **Skirmish** | Pick map, faction, and difficulty vs AI |
| **Tutorial** | Guided first-run intro (Jungle Basin, easy) |
| **Continue** | Loads quicksave from the main menu (when available) |
| **Settings** | Audio and game options |

Multiplayer is not implemented yet; the menu button shows a placeholder message.

## Factions

| ID | Faction | Identity |
| --- | --- | --- |
| 0 | **Itzal Resistance** | Balanced baseline; heal ability, Jaguar cavalry |
| 1 | **Decay** | Glass cannon (+10% attack, −10% HP); corruption ability |
| 2 | **Ix Architects** | Defensive elite (+1 armor); no archers, lattice units |

## Maps

- Jungle Basin (default)
- Sunken Reef
- Azure Coast
- Volcanic Crags

## Controls

| Input | Action |
| --- | --- |
| `W` `A` `S` `D` / mouse edge | Pan camera |
| Mouse wheel | Zoom in / out |
| Left click | Select unit or building |
| Left click + drag | Box-select multiple units |
| Right click on ground | Move selected units |
| Right click on tree / gold mine / food | Harvest resource (villagers) |
| `G` + right click | Attack-move (engage enemies en route) |
| `B` | Barracks placement mode |
| `T` | Town Center placement mode |
| `Y` | Tower placement mode |
| `F` | Farm placement mode |
| `M` | Monument placement mode |
| `E` / `R` / `Q` | Faction abilities (slots 1–3) |
| Right click (in placement mode) | Cancel placement |
| `Esc` | Pause / resume |
| `F1` | Toggle controls reference panel |

## Victory and defeat

### Skirmish

- **Victory:** Destroy all enemy buildings, **or** build a Monument and hold it for 3:00 without it being destroyed.
- **Defeat:** Your Town Center is destroyed (after you had one).

### Campaign

Same win/lose rules as skirmish. Missions may apply handicaps (eco boost, fast aggro, etc.) via `ActiveMission`. Clearing a mission unlocks the next from the end screen.

## Starting resources

Both player and AI start each match with:

- **300** wood
- **250** food
- **150** gold

(Plus starting Town Center, villagers, and map-specific layout from `MapConfig`.)

## Build and run

### Requirements

- Godot Engine **4.3+** (developed on **4.6**, Forward Plus).

### Run from the editor

1. Open this folder in Godot.
2. Press `F5` or click Play. The main menu loads first.

### Export builds

`export_presets.cfg` defines two targets:

| Preset | Output |
| --- | --- |
| **Windows Desktop** | `builds/windows/itzal_rising.exe` |
| **Web** | `builds/web/index.html` |

**Manual export:** *Project → Export…*, pick a preset, click *Export Project*. Install export templates via *Editor → Manage Export Templates…* if prompted.

**Headless export** (Godot on `PATH`):

```powershell
godot --headless --path . --export-release "Windows Desktop" builds/windows/itzal_rising.exe
godot --headless --path . --export-release "Web" builds/web/index.html
```

Assign an application icon in *Project → Export → Windows Desktop → Application → Icon* if you want a custom `.exe` icon (optional for local builds).

For the Web build on itch.io, enable **SharedArrayBuffer support** — Godot 4 requires cross-origin isolation headers.

Exported binaries live under `builds/` (gitignored).

## QA gates (headless)

Smoke tests that boot the world or round-trip save/load without script errors:

```powershell
godot --headless --path . --script res://tools/gate_boot.gd
godot --headless --path . --script res://tools/gate_saveload.gd
```

Optional faction boot variants:

```powershell
$env:GATE_FACTION='1'; godot --headless --path . --script res://tools/gate_boot.gd
$env:GATE_FACTION='2'; godot --headless --path . --script res://tools/gate_boot.gd
```

Strict audio asset check (requires all SFX WAV files on disk):

```powershell
godot --headless --path . --script res://tools/gate_audio.gd
```

`SoundManager` tolerates missing SFX at runtime (silent no-op); `gate_audio` is stricter and fails if files are absent. See `docs/BUGS_P0.md` for latest gate results.

Known P0 bugs are tracked in [`docs/BUGS_P0.md`](docs/BUGS_P0.md).

## Project layout

```
scenes/
  buildings/    TownCenter, Barracks, Tower, Farm, Monument, …
  camera/       RTS camera
  ui/           HUD, menus, panels, tutorial
  units/        Villager, soldiers, faction units, enemies
  world/        World, Ground, resources, spawners
scripts/
  ai/           EnemyAI
  buildings/    Building base, placer
  campaign/     Missions, loader, active mission state
  factions/     FactionData, FactionManager
  managers/     Resources, save, stats, objectives, sound, …
  tutorial/     Tutorial controller
  ui/           Menu and HUD controllers
  units/        Units, selection, components (combat, movement, harvest)
  world/        Map loader, fog of war, projectiles
  utils/        Texture generator, particles, damage numbers
tools/          Headless QA gates, asset pipeline scripts
assets/         UI theme, terrain, sprites, sfx, music
docs/           BUGS_P0.md and project notes
project.godot   Godot project config
export_presets.cfg  Windows + Web export presets
```
