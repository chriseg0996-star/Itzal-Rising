extends SceneTree

## Headless boot gate: instance World with an optional faction override and run
## long enough for MapLoader, the deferred spawners and EnemyAI's 2-frame
## bootstrap + first tick to execute. Exit 0 = boot survived; script errors
## show up in the log.
## Usage: godot --headless --path . --script res://tools/gate_boot.gd
##        $env:GATE_FACTION='1' for a Decay-player boot, '2' for Ix.

var _frames: int = 0

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 1:
		# Autoloads exist by the first process frame, not during _initialize.
		var settings: Node = root.get_node("/root/GameSettings")
		if OS.has_environment("GATE_FACTION"):
			settings.set("player_faction_id", int(OS.get_environment("GATE_FACTION")))
		var packed: PackedScene = load("res://scenes/world/World.tscn")
		get_root().add_child(packed.instantiate())
	if _frames >= 90:
		print("GATE_BOOT_OK")
		quit(0)
	return false
