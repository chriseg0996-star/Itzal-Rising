extends SceneTree

## Terminal-condition gate (A2): boots World, forces ONE win/loss condition, and
## asserts game_end_panel actually reaches an end state with the right title.
## Guards the P0 category "impossible mission / broken win-loss" per faction.
##
## Usage: GATE_FACTION=<0|2> GATE_WINLOSS=<defeat|victory|ascension|enemy_ascension>
##        godot --headless --path . --script res://tools/gate_winloss.gd
## Prints GATE_WINLOSS_OK / GATE_WINLOSS_FAIL: <reason>.

const BEACON: String = "res://scenes/buildings/AscensionBeacon.tscn"

var _frames: int = 0
var _phase: String = "settle"
var _cond: String = ""
var _panel: Node = null

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 1:
		var settings: Node = root.get_node("/root/GameSettings")
		if OS.has_environment("GATE_FACTION"):
			settings.set("player_faction_id", int(OS.get_environment("GATE_FACTION")))
		_cond = OS.get_environment("GATE_WINLOSS") if OS.has_environment("GATE_WINLOSS") else "defeat"
		var world: Node = (load("res://scenes/world/World.tscn") as PackedScene).instantiate()
		get_root().add_child(world)
		current_scene = world
		return false
	if _phase == "settle" and _frames >= 60:
		# TC present for >=1 frame so player_had_tc latched → DEFEAT can fire.
		_panel = root.find_child("GameEndPanel", true, false)
		if _panel == null:
			_fail("GameEndPanel not found")
			return false
		_apply()
		_phase = "wait"
		_frames = 0
	elif _phase == "wait" and _frames >= 30:
		_verify()
	return false

func _apply() -> void:
	match _cond:
		"defeat":
			for b in get_nodes_in_group("player_buildings"):
				if String(b.get("building_name")) == "Town Center":
					b.free()
		"victory":
			for b in get_nodes_in_group("enemy_buildings"):
				b.free()
		"ascension":
			_spawn_beacon(int(root.get_node("/root/GameSettings").get("player_faction_id")))
		"enemy_ascension":
			_spawn_beacon(_enemy_faction())
		_:
			_fail("unknown condition %s" % _cond)

func _spawn_beacon(fid: int) -> void:
	var b: Node = (load(BEACON) as PackedScene).instantiate()
	b.set("faction_id", fid)
	current_scene.add_child(b)
	if b is Node2D:
		(b as Node2D).global_position = Vector2(1400, 1400)
	b.set("charge", 9999.0)   # fully charged → instant ascension

func _enemy_faction() -> int:
	var pf: int = int(root.get_node("/root/GameSettings").get("player_faction_id"))
	return 1 if pf != 1 else 0

func _verify() -> void:
	var over: bool = bool(_panel.get("game_over"))
	var title: String = ""
	var tl: Node = _panel.get_node_or_null("Center/Panel/Margin/VBox/Title")
	if tl != null:
		title = String(tl.get("text"))
	if not over:
		_fail("no end state fired for '%s' (title='%s')" % [_cond, title])
		return
	var want_win: bool = _cond == "victory" or _cond == "ascension"
	var is_win: bool = title.begins_with("VICTORY") or title.begins_with("ASCENSION")
	if want_win != is_win:
		_fail("'%s' produced wrong outcome '%s'" % [_cond, title])
		return
	print("GATE_WINLOSS_OK (%s -> %s)" % [_cond, title])
	quit(0)

func _fail(reason: String) -> void:
	print("GATE_WINLOSS_FAIL: %s" % reason)
	quit(1)
