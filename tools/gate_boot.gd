extends SceneTree

## Headless boot gate: instance World with an optional faction override and run
## long enough for MapLoader, the deferred spawners and EnemyAI's 2-frame
## bootstrap + first tick to execute. Exit 0 = boot survived; script errors
## show up in the log.
## Usage: godot --headless --path . --script res://tools/gate_boot.gd
##        $env:GATE_FACTION='1' for a Decay-player boot, '2' for Ix.
##        $env:GATE_MAP='Sunken Reef' to boot a non-default map layout.

var _frames: int = 0

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 1:
		# Autoloads exist by the first process frame, not during _initialize.
		var settings: Node = root.get_node("/root/GameSettings")
		var faction: int = 0
		if OS.has_environment("GATE_FACTION"):
			faction = int(OS.get_environment("GATE_FACTION"))
			settings.set("player_faction_id", faction)
		var map_name: String = "Jungle Basin"
		if OS.has_environment("GATE_MAP"):
			map_name = OS.get_environment("GATE_MAP")
			settings.set("selected_map", map_name)
		print("GATE_BOOT combo: faction=%d map=%s" % [faction, map_name])
		var packed: PackedScene = load("res://scenes/world/World.tscn")
		get_root().add_child(packed.instantiate())
	if _frames >= 90:
		print("GATE_BOOT_OK")
		quit(0)
	return false
