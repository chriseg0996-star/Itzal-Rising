extends Node

## Holds the campaign mission currently being played so the World (map_loader,
## game_end_panel) can detect campaign context across a scene change. Empty
## current_id == a plain skirmish (no overlay). Registered as the
## "ActiveMission" autoload.

var current_id: String = ""

func set_mission(mission_id: String) -> void:
	current_id = mission_id

func clear() -> void:
	current_id = ""

func is_active() -> bool:
	return current_id != ""

func get_data() -> Dictionary:
	return MissionConfig.get_mission(current_id)
