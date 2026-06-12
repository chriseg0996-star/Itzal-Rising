extends Node

## Match quicksave to user://saves/quicksave.json. Registered as the
## "SaveManager" autoload (it must survive World -> MainMenu -> World).
## Entities are identified by node.scene_file_path and rebuilt from it on
## load; live object refs (combat targets, harvest targets) are deliberately
## NOT saved — combat re-scans within scan_interval after load.

const SAVE_DIR: String = "user://saves"
const SAVE_PATH: String = "user://saves/quicksave.json"
const SAVE_VERSION: int = 1

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
			"atk_level": GameStats.atk_level,
			"armor_level": GameStats.armor_level,
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
