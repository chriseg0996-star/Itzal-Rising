extends Node

const ATK_BONUS_PER_LEVEL: float = 3.0
const ARMOR_BONUS_PER_LEVEL: float = 2.0
## Signature "cavalry charge" tech: each level adds this much cavalry damage.
const CAVALRY_BONUS_PER_LEVEL: float = 0.5

var game_time: float = 0.0
var units_trained: int = 0
var resources_gathered: int = 0

## Per-match research levels (player side only), keyed by research id.
var atk_level: int = 0
var armor_level: int = 0
var cavalry_level: int = 0

func reset() -> void:
	game_time = 0.0
	units_trained = 0
	resources_gathered = 0
	atk_level = 0
	armor_level = 0
	cavalry_level = 0

func get_research_level(research_id: String) -> int:
	match research_id:
		"atk":
			return atk_level
		"armor":
			return armor_level
		"cavalry":
			return cavalry_level
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
