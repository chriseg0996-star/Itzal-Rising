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

var _factions: Dictionary = {}  # int faction_id -> FactionData

func _ready() -> void:
	_register(PLAYER, "Player", [ENEMY])
	_register(ENEMY, "Enemy", [PLAYER])

func _register(faction_id: int, display_name: String, hostile_to: Array[int]) -> void:
	var data := FactionData.new()
	data.id = faction_id
	data.display_name = display_name
	data.hostile_to = hostile_to
	_factions[faction_id] = data

func get_faction(faction_id: int) -> FactionData:
	return _factions.get(faction_id, null)

func is_hostile(faction_id: int, target_faction_id: int) -> bool:
	var data: FactionData = _factions.get(faction_id, null)
	if data == null:
		return false
	return target_faction_id in data.hostile_to

func is_player(faction_id: int) -> bool:
	return faction_id == PLAYER

func display_name_of(faction_id: int) -> String:
	var data: FactionData = _factions.get(faction_id, null)
	return data.display_name if data != null else ""
