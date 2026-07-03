extends Node

const ATK_BONUS_PER_LEVEL: float = 3.0
const ARMOR_BONUS_PER_LEVEL: float = 2.0
## Signature "cavalry charge" tech: each level adds this much cavalry damage.
const CAVALRY_BONUS_PER_LEVEL: float = 0.5

## Eras (AoE-style ages). Advancing at the Town Center grants every one of that
## side's units a flat attack + armour bump (dynamic, so it applies retroactively
## to units already on the field). The AI advances on a timer for parity.
const MAX_ERA: int = 3
const ERA_ATK_BONUS: float = 3.0     # per era above the first
const ERA_ARMOR_BONUS: float = 1.0

var game_time: float = 0.0
var units_trained: int = 0
var resources_gathered: int = 0

## Combat tallies (player's perspective): hostiles killed, own units lost,
## enemy buildings razed.
var enemies_killed: int = 0
var units_lost: int = 0
var buildings_destroyed: int = 0

## Per-match research levels (player side only), keyed by research id.
var atk_level: int = 0
var armor_level: int = 0
var cavalry_level: int = 0

## Eras: player-controlled, AI auto-advances (see EnemyAI). 1..MAX_ERA.
var era: int = 1
var ai_era: int = 1

## Player training-speed multiplier (Deals buff). AlertManager owns the timer
## and resets it to 1.0 when the buff expires.
var train_speed_mult: float = 1.0

func reset() -> void:
	train_speed_mult = 1.0
	game_time = 0.0
	units_trained = 0
	resources_gathered = 0
	enemies_killed = 0
	units_lost = 0
	buildings_destroyed = 0
	atk_level = 0
	armor_level = 0
	cavalry_level = 0
	era = 1
	ai_era = 1

func advance_era() -> void:
	if era < MAX_ERA:
		era += 1
		AlertManager.push("Advanced to Era %d!" % era, "info")

func set_ai_era(value: int) -> void:
	ai_era = clampi(value, 1, MAX_ERA)

## Flat per-side era bonuses, read live in combat/stat for player AND AI units.
func era_atk_bonus(is_player: bool) -> float:
	return float((era if is_player else ai_era) - 1) * ERA_ATK_BONUS

func era_armor_bonus(is_player: bool) -> float:
	return float((era if is_player else ai_era) - 1) * ERA_ARMOR_BONUS

func get_research_level(research_id: String) -> int:
	match research_id:
		"atk":
			return atk_level
		"armor":
			return armor_level
		"cavalry":
			return cavalry_level
		"era":
			return era - 1  # era 1 = level 0 (Era II buyable), etc.
	return 0

func complete_research(research_id: String) -> void:
	match research_id:
		"atk":
			atk_level += 1
			AlertManager.push("Attack upgrade %d complete" % atk_level, "info")
		"armor":
			armor_level += 1
			AlertManager.push("Armor upgrade %d complete" % armor_level, "info")
		"cavalry":
			cavalry_level += 1
			AlertManager.push("Cavalry charge complete", "info")
		"era":
			advance_era()

func player_atk_bonus() -> float:
	return float(atk_level) * ATK_BONUS_PER_LEVEL

func player_armor_bonus() -> float:
	return float(armor_level) * ARMOR_BONUS_PER_LEVEL

## Damage multiplier for player-side cavalry from the signature tech.
func player_cavalry_mult() -> float:
	return 1.0 + float(cavalry_level) * CAVALRY_BONUS_PER_LEVEL

func _process(delta: float) -> void:
	game_time += delta

func format_time() -> String:
	var total: int = int(game_time)
	@warning_ignore("integer_division")
	var minutes: int = total / 60
	var seconds: int = total % 60
	return "%02d:%02d" % [minutes, seconds]
