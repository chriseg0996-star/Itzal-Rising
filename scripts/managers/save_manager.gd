extends Node

## Match quicksave to user://saves/quicksave.json. Registered as the
## "SaveManager" autoload (it must survive World -> MainMenu -> World).
## Entities are identified by node.scene_file_path and rebuilt from it on
## load; live object refs (combat targets, harvest targets) are deliberately
## NOT saved — combat re-scans within scan_interval after load.

const SAVE_DIR: String = "user://saves"
const SAVE_PATH: String = "user://saves/quicksave.json"
const SAVE_VERSION: int = 1
const WORLD_SCENE: String = "res://scenes/world/World.tscn"
## World boot is fully settled by frame 4 (MapLoader frame 0, spawners
## deferred, EnemyAI 2-frame bootstrap + first tick) — apply at 5.
const APPLY_FRAME: int = 5

var _pending: Dictionary = {}
var _frames_in_world: int = 0
var _applying: bool = false

func _ready() -> void:
	# Must keep counting frames even if something leaves the tree paused.
	process_mode = Node.PROCESS_MODE_ALWAYS

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func save_game() -> bool:
	var data: Dictionary = _snapshot()
	if data.is_empty():
		return false
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var f: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	return true

## Parse the quicksave, restore the match config (the World's boot actors read
## it), run the standard reset chain and reload the World; the snapshot is
## applied over the freshly booted world a few frames later.
func request_load() -> void:
	if not has_save():
		return
	var f: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if not (parsed is Dictionary):
		return
	var data: Dictionary = parsed
	# A loaded quicksave is a plain skirmish — drop any campaign context.
	ActiveMission.clear()
	var settings: Dictionary = data.get("settings", {})
	GameSettings.player_faction_id = int(settings.get("player_faction_id", 0))
	GameSettings.selected_map = String(settings.get("selected_map", "Jungle Basin"))
	GameSettings.difficulty = String(settings.get("difficulty", "normal"))
	ResourceManager.reset()
	SelectionManager.clear()
	SelectionManager.deselect_building()
	BuildingPlacer.cancel_placement()
	EnemyAI.reset()
	GameStats.reset()
	ObjectiveManager.reset()
	_pending = data
	_frames_in_world = 0
	get_tree().paused = false
	get_tree().change_scene_to_file(WORLD_SCENE)

func _process(_delta: float) -> void:
	if _pending.is_empty() or _applying:
		return
	var cs: Node = get_tree().current_scene
	if cs == null or cs.scene_file_path != WORLD_SCENE:
		_frames_in_world = 0
		return
	_frames_in_world += 1
	if _frames_in_world >= APPLY_FRAME:
		_applying = true
		var data: Dictionary = _pending
		_pending = {}
		_apply(data)

func _apply(data: Dictionary) -> void:
	var tree: SceneTree = get_tree()
	# Pause freezes GameEndPanel's win checks (it would see the emptied
	# enemy_buildings group as VICTORY mid-rebuild) and the AI.
	tree.paused = true
	for group in ["combat_units", "buildings", "resources"]:
		for n in tree.get_nodes_in_group(group):
			if is_instance_valid(n):
				n.queue_free()
	await tree.process_frame
	await tree.process_frame

	var stats: Dictionary = data.get("stats", {})
	GameStats.game_time = float(stats.get("game_time", 0.0))
	GameStats.units_trained = int(stats.get("units_trained", 0))
	GameStats.resources_gathered = int(stats.get("resources_gathered", 0))
	GameStats.enemies_killed = int(stats.get("enemies_killed", 0))
	GameStats.units_lost = int(stats.get("units_lost", 0))
	GameStats.buildings_destroyed = int(stats.get("buildings_destroyed", 0))
	GameStats.atk_level = int(stats.get("atk_level", 0))
	GameStats.armor_level = int(stats.get("armor_level", 0))
	GameStats.cavalry_level = int(stats.get("cavalry_level", 0))
	var res: Dictionary = data.get("resources", {})
	ResourceManager.restore(res.get("player", {}), res.get("enemy", {}))
	var completed: Array[String] = []
	for id in (data.get("objectives_completed", []) as Array):
		completed.append(String(id))
	ObjectiveManager._completed = completed

	var world: Node = tree.current_scene
	if world == null:
		tree.paused = false
		_applying = false
		return
	# Buildings before units: villager _ready resolves its home TC.
	for bentry in (data.get("buildings", []) as Array):
		_spawn_building(bentry, world)
	for rentry in (data.get("resource_nodes", []) as Array):
		_spawn_simple(rentry, world)
	for uentry in (data.get("units", []) as Array):
		_spawn_unit(uentry, world)

	var ai: Dictionary = data.get("enemy_ai", {})
	EnemyAI.tick_timer = float(ai.get("tick_timer", 0.0))
	EnemyAI.game_time = float(ai.get("game_time", GameStats.game_time))
	EnemyAI._next_all_in = float(ai.get("next_all_in", EnemyAI._next_all_in))
	EnemyAI.base_pos = EnemyAI._resolve_base_pos()

	var ability: Node = tree.get_first_node_in_group("ability_panel")
	if ability != null and data.has("ability"):
		ability.set_cooldown(float((data["ability"] as Dictionary).get("cooldown_remaining", 0.0)))
	var end_panel: Node = world.get_node_or_null("GameEndPanel")
	if end_panel != null and data.has("monument"):
		var mon: Dictionary = data["monument"]
		end_panel.set_monument_state(bool(mon.get("countdown_active", false)), float(mon.get("time_left", 0.0)))
	var fog: Node = tree.get_first_node_in_group("fog_of_war")
	if fog != null and data.has("fog"):
		fog.set_explored(Marshalls.base64_to_raw(String((data["fog"] as Dictionary).get("explored_b64", ""))))

	tree.paused = false
	_applying = false
	AlertManager.push("Game loaded", "info")

func _spawn_building(bentry: Dictionary, world: Node) -> void:
	var packed: PackedScene = load(String(bentry.get("scene", "")))
	if packed == null:
		return
	var building: Node = packed.instantiate()
	building.set("faction_id", int(bentry.get("faction_id", 0)))
	world.add_child(building)
	if building is Node2D:
		var pos: Array = bentry.get("pos", [0.0, 0.0])
		(building as Node2D).global_position = Vector2(float(pos[0]), float(pos[1]))
	# hp after add_child: _ready set hp = max_hp (and lattice may bump it).
	building.set("hp", int(bentry.get("hp", building.get("max_hp"))))
	var queue: Array = []
	for q in (bentry.get("queue", []) as Array):
		var qd: Dictionary = q
		if qd.has("research_id"):
			queue.append({"scene": null, "duration": float(qd["duration"]), "research_id": String(qd["research_id"])})
		else:
			var ps: PackedScene = load(String(qd.get("scene", "")))
			if ps != null:
				queue.append({"scene": ps, "duration": float(qd["duration"])})
	building.set("queue", queue)
	building.set("production_timer", float(bentry.get("production_timer", 0.0)))
	if bentry.has("rally") and building.has_method("set_rally_point"):
		var rp: Array = bentry["rally"]
		building.set_rally_point(Vector2(float(rp[0]), float(rp[1])))

func _spawn_simple(rentry: Dictionary, world: Node) -> void:
	var packed: PackedScene = load(String(rentry.get("scene", "")))
	if packed == null:
		return
	var node: Node = packed.instantiate()
	world.add_child(node)
	if node is Node2D:
		var pos: Array = rentry.get("pos", [0.0, 0.0])
		(node as Node2D).global_position = Vector2(float(pos[0]), float(pos[1]))
	node.set("amount", int(rentry.get("amount", 0)))

func _spawn_unit(uentry: Dictionary, world: Node) -> void:
	var packed: PackedScene = load(String(uentry.get("scene", "")))
	if packed == null:
		return
	var unit: Node = packed.instantiate()
	world.add_child(unit)
	if unit is Node2D:
		var pos: Array = uentry.get("pos", [0.0, 0.0])
		(unit as Node2D).global_position = Vector2(float(pos[0]), float(pos[1]))
	if uentry.has("health"):
		var stat: Node = unit.get_node_or_null("StatComponent")
		if stat != null and stat.has_method("restore_health"):
			stat.restore_health(float(uentry["health"]))
	# Mid-carry villagers walk their load home via the existing RETURNING flow.
	if int(uentry.get("carrying", 0)) > 0:
		var hc: Node = unit.get_node_or_null("HarvestComponent")
		if hc != null:
			hc.set("_carrying", int(uentry["carrying"]))
			hc.set("_carry_type", StringName(String(uentry.get("carry_type", ""))))
			hc.call("_set_state", HarvestComponent.State.RETURNING)
			unit.set("_state", 2)  # villager State.HARVESTING — drives component.tick

func _snapshot() -> Dictionary:
	var tree: SceneTree = get_tree()
	var data: Dictionary = {
		"version": SAVE_VERSION,
		"timestamp": Time.get_datetime_string_from_system(),
		"settings": {
			"player_faction_id": GameSettings.player_faction_id,
			"selected_map": GameSettings.selected_map,
			"difficulty": GameSettings.difficulty,
		},
		"stats": {
			"game_time": GameStats.game_time,
			"units_trained": GameStats.units_trained,
			"resources_gathered": GameStats.resources_gathered,
			"enemies_killed": GameStats.enemies_killed,
			"units_lost": GameStats.units_lost,
			"buildings_destroyed": GameStats.buildings_destroyed,
			"atk_level": GameStats.atk_level,
			"armor_level": GameStats.armor_level,
			"cavalry_level": GameStats.cavalry_level,
		},
		"resources": ResourceManager.snapshot(),
		"objectives_completed": ObjectiveManager._completed.duplicate(),
		"enemy_ai": {
			"tick_timer": EnemyAI.tick_timer,
			"game_time": EnemyAI.game_time,
			"next_all_in": EnemyAI._next_all_in,
		},
		"units": [],
		"buildings": [],
		"resource_nodes": [],
	}
	var ability: Node = tree.get_first_node_in_group("ability_panel")
	if ability != null:
		data["ability"] = {"cooldown_remaining": ability.get_cooldown()}
	var end_panel: Node = tree.current_scene.get_node_or_null("GameEndPanel") if tree.current_scene != null else null
	if end_panel != null and end_panel.has_method("get_monument_state"):
		data["monument"] = end_panel.get_monument_state()
	var fog: Node = tree.get_first_node_in_group("fog_of_war")
	if fog != null:
		data["fog"] = {"explored_b64": Marshalls.raw_to_base64(fog.get_explored())}

	for u in tree.get_nodes_in_group("combat_units"):
		if not (is_instance_valid(u) and u is Node2D):
			continue
		if u.has_method("is_dying") and u.is_dying():
			continue
		var entry: Dictionary = {
			"scene": (u as Node).scene_file_path,
			"pos": [(u as Node2D).global_position.x, (u as Node2D).global_position.y],
		}
		var stat: Node = u.get_node_or_null("StatComponent")
		if stat != null:
			entry["health"] = float(stat.get("_current_health"))
		var hc: Node = u.get_node_or_null("HarvestComponent")
		if hc != null and int(hc.get("_carrying")) > 0:
			entry["carrying"] = int(hc.get("_carrying"))
			entry["carry_type"] = String(hc.get("_carry_type"))
			entry["returning"] = int(hc.get("_state")) == HarvestComponent.State.RETURNING
		(data["units"] as Array).append(entry)

	for b in tree.get_nodes_in_group("buildings"):
		if not (is_instance_valid(b) and b is Node2D) or bool(b.get("dying")):
			continue
		var bentry: Dictionary = {
			"scene": (b as Node).scene_file_path,
			"pos": [(b as Node2D).global_position.x, (b as Node2D).global_position.y],
			"hp": int(b.get("hp")),
			"faction_id": int(b.get("faction_id")),
			"production_timer": float(b.get("production_timer")),
			"queue": [],
		}
		for qentry in (b.get("queue") as Array):
			var q: Dictionary = qentry
			if q.has("research_id"):
				(bentry["queue"] as Array).append({
					"research_id": String(q["research_id"]),
					"duration": float(q["duration"]),
				})
			elif q.get("scene") != null:
				(bentry["queue"] as Array).append({
					"scene": (q["scene"] as PackedScene).resource_path,
					"duration": float(q["duration"]),
				})
		if bool(b.get("has_rally_point")):
			var rp: Vector2 = b.get("rally_point")
			bentry["rally"] = [rp.x, rp.y]
		(data["buildings"] as Array).append(bentry)

	for r in tree.get_nodes_in_group("resources"):
		if not (is_instance_valid(r) and r is Node2D):
			continue
		var amount: Variant = r.get("amount")
		if amount == null:
			continue
		(data["resource_nodes"] as Array).append({
			"scene": (r as Node).scene_file_path,
			"pos": [(r as Node2D).global_position.x, (r as Node2D).global_position.y],
			"amount": int(amount),
		})
	return data
