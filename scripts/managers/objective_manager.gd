extends Node

## Tracks player campaign objectives. Polls GameStats / scene-tree state on a
## 1s throttle and emits objective_completed exactly once per objective id.

signal objective_completed(id: String, label: String)

const CHECK_INTERVAL: float = 1.0

const OBJECTIVES: Array[Dictionary] = [
	{
		"id": "train_first_soldier",
		"label": "Train your first soldier",
		"check": "soldiers_trained",
		"target": 1,
	},
	{
		"id": "gather_500_resources",
		"label": "Gather 500 resources",
		"check": "resources_gathered",
		"target": 500,
	},
	{
		"id": "build_barracks",
		"label": "Build a Barracks",
		"check": "building_count",
		"target": 1,
		"building_type": "Barracks",
	},
	{
		"id": "train_5_soldiers",
		"label": "Train 5 soldiers",
		"check": "soldiers_trained",
		"target": 5,
	},
	{
		"id": "survive_5_minutes",
		"label": "Survive 5 minutes",
		"check": "game_time_seconds",
		"target": 300,
	},
]

var _completed: Array[String] = []
var _accum: float = 0.0

func _process(delta: float) -> void:
	_accum += delta
	if _accum < CHECK_INTERVAL:
		return
	_accum = 0.0
	for obj in OBJECTIVES:
		var id: String = String(obj.get("id", ""))
		if _completed.has(id):
			continue
		if get_progress(obj) >= 1.0:
			_completed.append(id)
			objective_completed.emit(id, String(obj.get("label", "")))

## Returns the first 3 not-yet-completed objectives.
func get_active_objectives() -> Array[Dictionary]:
	var active: Array[Dictionary] = []
	for obj in OBJECTIVES:
		if _completed.has(String(obj.get("id", ""))):
			continue
		active.append(obj)
		if active.size() >= 3:
			break
	return active

## Normalized 0.0–1.0 completion ratio for a single objective.
func get_progress(obj: Dictionary) -> float:
	var target: float = float(obj.get("target", 1))
	if target <= 0.0:
		return 0.0
	return clampf(_get_check_value(obj) / target, 0.0, 1.0)

func is_complete(obj: Dictionary) -> bool:
	return _completed.has(String(obj.get("id", "")))

func reset() -> void:
	_completed.clear()
	_accum = 0.0

func _get_check_value(obj: Dictionary) -> float:
	match String(obj.get("check", "")):
		"soldiers_trained":
			return float(GameStats.units_trained)
		"resources_gathered":
			return float(GameStats.resources_gathered)
		"building_count":
			return float(_count_player_buildings(String(obj.get("building_type", ""))))
		"game_time_seconds":
			return GameStats.game_time
	return 0.0

func _count_player_buildings(building_type: String) -> int:
	if building_type.is_empty():
		return 0
	var count: int = 0
	for node in get_tree().get_nodes_in_group("buildings"):
		if not is_instance_valid(node):
			continue
		if not FactionManager.is_player_faction(int(node.get("faction_id"))):
			continue
		# Match the building_name property, not the node name — Ix/Decay scene
		# roots are named IxBarracks/EnemyBarracks but share building_name.
		if String(node.get("building_name")) == building_type:
			count += 1
	return count
