extends SceneTree

## Headless campaign-mission boot gate: replicates MissionLoader.start() for one
## mission (GATE_MISSION env: m1..m5, or "tutorial") — sets the map/faction/
## difficulty, marks ActiveMission, runs the reset chain — then instances World
## and runs long enough for map_loader to apply the mission modifier
## (enemy_eco_boost / fast_aggro / player_handicap) and EnemyAI to tick.
## Exit 0 + GATE_CAMPAIGN_OK = the mission booted; script errors show in the log.
## Usage: $env:GATE_MISSION='m3'; godot --headless --path . --script res://tools/gate_campaign.gd

var _frames: int = 0

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 1:
		var mission_id: String = "m1"
		if OS.has_environment("GATE_MISSION"):
			mission_id = OS.get_environment("GATE_MISSION")
		var settings: Node = root.get_node("/root/GameSettings")
		var active: Node = root.get_node("/root/ActiveMission")
		var modifier: String = "none"
		if mission_id == "tutorial":
			settings.set("selected_map", "Jungle Basin")
			settings.set("difficulty", "easy")
			settings.set("player_faction_id", 0)
		else:
			var m: Dictionary = MissionConfig.get_mission(mission_id)
			if m.is_empty():
				push_error("unknown mission '%s'" % mission_id)
				quit(1)
				return true
			settings.set("selected_map", String(m.get("map", "Jungle Basin")))
			settings.set("difficulty", String(m.get("difficulty", "normal")))
			settings.set("player_faction_id", int(m.get("faction_id", 0)))
			modifier = String(m.get("modifier", "none"))
		active.set_mission(mission_id)
		# Match the loader's reset chain so EnemyAI picks up difficulty/fast_aggro.
		root.get_node("/root/ResourceManager").reset()
		root.get_node("/root/EnemyAI").reset()
		root.get_node("/root/GameStats").reset()
		root.get_node("/root/ObjectiveManager").reset()
		print("GATE_CAMPAIGN combo: mission=%s modifier=%s" % [mission_id, modifier])
		var packed: PackedScene = load("res://scenes/world/World.tscn")
		get_root().add_child(packed.instantiate())
	if _frames >= 90:
		print("GATE_CAMPAIGN_OK")
		quit(0)
	return false
