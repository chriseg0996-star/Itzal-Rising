extends SceneTree

## Save/load round-trip gate: boot World, snapshot counts + player wood,
## save, mutate the world (free 2 units, research level), request_load,
## then assert everything round-tripped. Exit 0 = pass.
## Usage: godot --headless --path . --script res://tools/gate_saveload.gd
##        $env:GATE_FACTION='1' for the Decay-player variant.

var _frames: int = 0
var _phase: String = "boot"
var _saved_units: int = 0
var _saved_buildings: int = 0
var _saved_wood: int = 0
const BEACON_CHARGE: float = 42.0

func _process(_delta: float) -> bool:
	_frames += 1
	match _phase:
		"boot":
			if _frames == 1:
				var settings: Node = root.get_node("/root/GameSettings")
				if OS.has_environment("GATE_FACTION"):
					settings.set("player_faction_id", int(OS.get_environment("GATE_FACTION")))
				var world: Node = (load("res://scenes/world/World.tscn") as PackedScene).instantiate()
				get_root().add_child(world)
				current_scene = world
			if _frames >= 40:
				_do_save()
		"wait_load":
			if _frames >= 40:
				_verify()
	return false

## Drop a charging Ascension Beacon into the world so the save must persist an
## alternate-victory-in-progress (regression guard for the reset-to-zero bug).
func _spawn_beacon() -> void:
	var pf: int = int(root.get_node("/root/GameSettings").get("player_faction_id"))
	var b: Node = (load("res://scenes/buildings/AscensionBeacon.tscn") as PackedScene).instantiate()
	b.set("faction_id", pf)
	current_scene.add_child(b)
	if b is Node2D:
		(b as Node2D).global_position = Vector2(1200, 1200)
	b.set("charge", BEACON_CHARGE)

func _do_save() -> void:
	_spawn_beacon()
	var stats: Node = root.get_node("/root/GameStats")
	stats.set("atk_level", 1)
	_saved_units = get_nodes_in_group("combat_units").size()
	_saved_buildings = get_nodes_in_group("buildings").size()
	var rm: Node = root.get_node("/root/ResourceManager")
	_saved_wood = rm.get_resource("wood", int(root.get_node("/root/GameSettings").get("player_faction_id")))
	var sm: Node = root.get_node("/root/SaveManager")
	if not sm.save_game():
		print("GATE_SAVELOAD_FAIL: save_game returned false")
		quit(1)
		return
	# Mutate: kill two units, distort research, zero the beacon charge, then load.
	var units: Array = get_nodes_in_group("combat_units")
	for i in mini(2, units.size()):
		units[i].free()
	stats.set("atk_level", 0)
	for bn in get_nodes_in_group("beacons"):
		bn.set("charge", 0.0)
	sm.request_load()
	_frames = 0
	_phase = "wait_load"

func _verify() -> void:
	var failed: bool = false
	var units: int = get_nodes_in_group("combat_units").size()
	var buildings: int = get_nodes_in_group("buildings").size()
	if units != _saved_units:
		print("GATE_SAVELOAD_FAIL: units %d != %d" % [units, _saved_units])
		failed = true
	if buildings != _saved_buildings:
		print("GATE_SAVELOAD_FAIL: buildings %d != %d" % [buildings, _saved_buildings])
		failed = true
	var rm: Node = root.get_node("/root/ResourceManager")
	var wood: int = rm.get_resource("wood", int(root.get_node("/root/GameSettings").get("player_faction_id")))
	if wood != _saved_wood:
		print("GATE_SAVELOAD_FAIL: wood %d != %d" % [wood, _saved_wood])
		failed = true
	if int(root.get_node("/root/GameStats").get("atk_level")) != 1:
		print("GATE_SAVELOAD_FAIL: atk_level did not round-trip")
		failed = true
	# Beacon charge must come back (it charges a little post-load, so band-check).
	var beacons: Array = get_nodes_in_group("beacons")
	if beacons.is_empty():
		print("GATE_SAVELOAD_FAIL: beacon missing after load")
		failed = true
	else:
		var ch: float = float(beacons[0].get("charge"))
		if ch < BEACON_CHARGE - 1.0 or ch > BEACON_CHARGE + 5.0:
			print("GATE_SAVELOAD_FAIL: beacon charge %.1f != ~%.1f" % [ch, BEACON_CHARGE])
			failed = true
	if failed:
		quit(1)
	else:
		print("GATE_SAVELOAD_OK")
		quit(0)
