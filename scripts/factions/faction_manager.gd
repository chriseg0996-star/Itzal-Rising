extends Node

## Central registry of factions (teams) and hostility relationships.
## Registered as the "FactionManager" autoload.
## NOTE: no `class_name` — an autoload sharing its name with a global class
## raises "Class hides an autoload singleton" in Godot 4. Access via the singleton.
##
## Faction ids are stable integers used across units, buildings, the economy
## (ResourceManager pools) and combat targeting:
##   0 = player, 1 = enemy.

const PLAYER: int = 0
const ENEMY: int = 1
const IX: int = 2

const PLAYER_COLOR: Color = Color(0.27, 0.86, 0.50)  # teal/green
const ENEMY_COLOR: Color = Color(0.65, 0.41, 0.74)   # purple
const IX_COLOR: Color = Color(1.0, 0.6, 0.1)         # amber

var _factions: Dictionary = {}  # int faction_id -> FactionData

func _ready() -> void:
	# 0 = player and 2 = Ix are both player-aligned (never hostile to each other).
	# 1 = Decay is hostile to BOTH so the AI engages whichever the human controls.
	_register(PLAYER, "Player", [ENEMY], PLAYER_COLOR)
	_register(ENEMY, "Decay", [PLAYER, IX], ENEMY_COLOR)
	_register(IX, "Ix Architects", [ENEMY], IX_COLOR)

func _register(faction_id: int, display_name: String, hostile_to: Array[int], primary_color: Color) -> void:
	var data := FactionData.new()
	data.id = faction_id
	data.display_name = display_name
	data.hostile_to = hostile_to
	data.primary_color = primary_color
	_factions[faction_id] = data

func get_faction(faction_id: int) -> FactionData:
	return _factions.get(faction_id, null)

func is_hostile(faction_id: int, target_faction_id: int) -> bool:
	var data: FactionData = _factions.get(faction_id, null)
	if data == null:
		return false
	return target_faction_id in data.hostile_to

## True for the side the human player controls this match. When the player is
## Decay (1), only Decay is player-aligned. Otherwise factions 0 and 2 are both
## player-aligned: an Ix player's starting TC is still the faction-0 PlayerTC
## node, so 0 must stay on the player's side in Itzal/Ix matches.
func is_player_faction(faction_id: int) -> bool:
	if GameSettings.player_faction_id == ENEMY:
		return faction_id == ENEMY
	return faction_id == PLAYER or faction_id == IX

func display_name_of(faction_id: int) -> String:
	var data: FactionData = _factions.get(faction_id, null)
	return data.display_name if data != null else ""
