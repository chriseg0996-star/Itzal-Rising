extends Node

## Starts a campaign mission: writes the mission's map/faction/difficulty to
## GameSettings, marks ActiveMission, runs the standard match reset chain (so
## EnemyAI picks up the difficulty + fast_aggro modifier), then loads the World.
## map_loader applies the remaining handicaps once the world exists.
## Registered as the "MissionLoader" autoload (autoloads aren't reachable from
## static functions, so this can't be a class_name helper).

const WORLD_SCENE: String = "res://scenes/world/World.tscn"

func start(mission_id: String) -> void:
	var m: Dictionary = MissionConfig.get_mission(mission_id)
	if m.is_empty():
		return
	GameSettings.selected_map = String(m.get("map", "Jungle Basin"))
	GameSettings.difficulty = String(m.get("difficulty", "normal"))
	GameSettings.player_faction_id = int(m.get("faction_id", 0))
	ActiveMission.set_mission(mission_id)
	_reset_and_load()

## Launches the guided tutorial on a fixed, gentle config. ActiveMission id
## "tutorial" is not in MISSIONS (so no map modifier), and the TutorialController
## node in World activates only for this id.
func start_tutorial() -> void:
	GameSettings.selected_map = "Jungle Basin"
	GameSettings.difficulty = "easy"
	GameSettings.player_faction_id = 0
	ActiveMission.set_mission("tutorial")
	_reset_and_load()

func _reset_and_load() -> void:
	ResourceManager.reset()
	SelectionManager.clear()
	SelectionManager.deselect_building()
	BuildingPlacer.cancel_placement()
	EnemyAI.reset()
	GameStats.reset()
	ObjectiveManager.reset()
	get_tree().paused = false
	get_tree().change_scene_to_file(WORLD_SCENE)
