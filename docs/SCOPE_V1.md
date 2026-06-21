# Itzal Rising — Scope V1.0

Defines what ships in the **1.0 (Steam-ready) release** and what is explicitly
deferred. The bar for V1 is a complete, stable single-player RTS — not a feature
race. Anything not listed under *In scope* is out of scope for 1.0.

**Engine:** Godot 4.6 (Forward+) · **Language:** typed GDScript 2.0
**Primary target:** Windows Desktop · **Secondary:** Web (itch.io)

---

## 1. In scope (V1.0)

### Game modes
- **Campaign** — 5 ordered missions with per-mission modifiers; clearing one
  unlocks the next (persisted via `ProfileManager`).
- **Skirmish** — choose map + faction + difficulty vs AI.
- **Tutorial** — guided first run (Jungle Basin, easy).
- **Continue** — load quicksave from the main menu when present.
- **Settings** — audio + game options.

### Factions (3)
| ID | Faction | Identity |
|----|---------|----------|
| 0 | Itzal Resistance | Balanced; Jaguar's Vigor heal, Jaguar cavalry |
| 1 | Decay | Glass cannon (+10% ATK, −10% HP); Corruption Burst |
| 2 | Ix Architects | Defensive elite (+1 ARM); lattice units, no archers |

Each faction has a 3-slot ability kit (E / R / Q) and a signature tech.

### Maps (4)
Jungle Basin (default) · Sunken Reef · Azure Coast · Volcanic Crags.

### Core systems
- **Economy:** wood / food / gold; villagers, large nodes, berry/farm food,
  Storehouse drop-off; AoE4-style tuning.
- **Buildings:** Town Center, Barracks, Tower, Farm, Monument, Storehouse;
  ghost placement with cost preview.
- **Combat:** auto-engage, attack-move, armor/attack research, era advance,
  faction modifiers, projectiles, fog of war.
- **Units:** villagers + faction-specific military (composition over inheritance:
  movement / combat / harvest / selection components).
- **Enemy AI:** gather → build → wave attacks; difficulty scaling
  (easy / normal / hard).
- **Objectives / win-loss:** destroy all enemy buildings *or* hold a Monument
  3:00; defeat on Town Center loss. Campaign handicaps via `ActiveMission`.
- **Save / load:** quicksave + campaign progress (`SaveManager`,
  `ProfileManager`).
- **UI:** main menu, skirmish setup, campaign select, HUD, build/production
  panels, minimap, pause, game-end, controls reference (F1) — unified
  "Basalt & Neon" identity over a shared dimmed backdrop.
- **Audio:** menu + match music, 7 core SFX (graceful no-op if absent at
  runtime).

### Platforms & quality bar
- Windows Desktop export green; Web export builds.
- **0 open P0** (crash / softlock / broken win-loss / corrupt save).
- Headless QA gates pass: `gate_boot` (×3 factions) · `gate_saveload` ·
  `gate_audio`.
- Target ~50 simultaneous units at stable frame rate.

---

## 2. Out of scope (deferred past V1.0)

- **Multiplayer / online** — menu shows a placeholder (P1-004, by design).
- Additional factions, maps, or campaign acts beyond the 5 missions.
- Steam integration (achievements, cloud saves, workshop) and mod support.
- Localization beyond English UI text.
- Naval units, diplomacy, random map generation, replays, level editor.
- Controller / touch input; mobile or console targets.
- Procedural-art replacement of placeholder assets beyond what ships today.

---

## 3. Release checklist (V1.0)

- [ ] All QA gates green on CI (boot ×3, saveload, audio).
- [ ] `docs/BUGS_P0.md` shows 0 open P0 after a manual playtest pass.
- [ ] Each campaign mission completable; unlock chain verified end-to-end.
- [ ] Each faction × each map boots and is winnable on every difficulty.
- [ ] Windows export runs from a clean machine; quicksave round-trips.
- [ ] Main menu version string matches `project.godot` (`config/version`).
