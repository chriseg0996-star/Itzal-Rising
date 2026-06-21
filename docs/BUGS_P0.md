# Bugs P0 — Itzal Rising

Critical issues only: crash, softlock, broken win/lose, corrupt save, impossible mission.

**Last static review:** 2026-06-21  
**Reviewed files:** `main_menu.gd`, `skirmish_setup.gd`, `mission_loader.gd`, `game_end_panel.gd`, `save_manager.gd`

## Open P0

| ID | Severidad | Descripción | Repro | Estado |
|----|-----------|-------------|-------|--------|
| — | — | *Ninguno confirmado* | — | Pendiente playtest manual |

## Notas de review (no P0)

| ID | Severidad | Descripción | Repro | Estado |
|----|-----------|-------------|-------|--------|
| P1-001 | P1 | `skirmish_setup.gd` no llama `ObjectiveManager.reset()` al iniciar partida. | Campaña → skirmish | **Cerrado** (`ObjectiveManager.reset()` en `_on_start_pressed`) |
| P1-002 | P1 | Export templates 4.6.3 | headless export | **Cerrado** (templates + `builds/windows/itzal_rising.exe` ~100 MB) |
| P1-003 | P1 | `map_loader.gd` — `add_child()` en `_ready` | `gate_boot.gd` | **Cerrado** (`add_child.call_deferred`) |
| P1-004 | P1 | Multiplayer = “coming soon” en menú | Main Menu → Multiplayer | Conocido |

## Cómo reportar

1. Pasos exactos para reproducir.
2. Mapa, facción, dificultad, modo.
3. Log de Godot si hay crash.
4. Clasifica P0 / P1 / P2.

---

## QA gates — resultados

**Fecha:** 2026-06-21 (smoke F1 — post UI restyle)  
**Godot:** 4.6.3

| Comando | Resultado | Notas |
|---------|-----------|-------|
| `gate_boot.gd` | **PASS** | `GATE_BOOT_OK`; 0× `add_child() failed` |
| `gate_saveload.gd` | **PASS** | `GATE_SAVELOAD_OK` |
| `gate_audio.gd` | **PASS** | `GATE_AUDIO_OK` (7/7 SFX presentes) |
| `gate_boot` + `GATE_FACTION=1/2` | **PASS** | Decay / Ix boot |
| boot matriz (4 mapas × 3 facciones) | **PASS** | 12/12 combos `GATE_BOOT_OK` (local + CI) |
| Export Windows | **PASS** | `builds/windows/itzal_rising.exe` (~99.7 MB) |

> Los gates corren además en CI (`.github/workflows/ci.yml`) en cada push/PR.

### Re-ejecutar (PowerShell)

```powershell
$godot = "C:\Users\chris\OneDrive\Desktop\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe"
cd c:\Users\chris\RTS
& $godot --headless --path . --script res://tools/gate_boot.gd
& $godot --headless --path . --export-release "Windows Desktop" builds/windows/itzal_rising.exe
```
