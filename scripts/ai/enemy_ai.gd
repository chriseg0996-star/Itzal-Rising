extends Node

const TICK_INTERVAL_INITIAL: float = 45.0
const TICK_INTERVAL_MIN: float = 20.0
const RAMP_PERIOD: float = 60.0
const RAMP_STEP: float = 5.0

const ENEMY_BASE_POS: Vector2 = Vector2(1600, 1600)
const BARRACKS_OFFSET_RANGE: float = 220.0
const ATTACK_FORCE_MIN: int = 5
const BARRACKS_COST: Dictionary = {"madera": 75}
const TOWER_COST: Dictionary = {"madera": 150}
## Fixed tower slots around the enemy TC, facing the player's approach.
const TOWER_OFFSETS: Array[Vector2] = [
	Vector2(-260.0, -60.0),
	Vector2(-60.0, -260.0),
	Vector2(-300.0, 180.0),
]
const MAP_MIN: float = 80.0
const MAP_MAX: float = 1968.0

var tick_timer: float = 0.0
var game_time: float = 0.0
var initialized: bool = false
var wave_interval: float = TICK_INTERVAL_INITIAL
var max_soldiers: int = 0  # 0 = uncapped
var max_towers: int = 2
## Resolved from the AI's town center at bootstrap so map layouts can move the
## base; falls back to the legacy constant if no TC is found.
var base_pos: Vector2 = ENEMY_BASE_POS

func _ready() -> void:
	call_deferred("_bootstrap")
	_apply_difficulty()

func reset() -> void:
	tick_timer = 0.0
	game_time = 0.0
	initialized = false
	_apply_difficulty()
	call_deferred("_bootstrap")

func _apply_difficulty() -> void:
	wave_interval = TICK_INTERVAL_INITIAL
	max_soldiers = 0
	max_towers = 2
	match GameSettings.difficulty:
		"easy":
			wave_interval *= 1.5
			max_soldiers = 3
			max_towers = 1
		"normal":
			pass  # unchanged
		"hard":
			wave_interval *= 0.7
			max_soldiers = 8
			max_towers = 3

func _bootstrap() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	base_pos = _resolve_base_pos()
	initialized = true
	_ai_tick()

func _resolve_base_pos() -> Vector2:
	for tc in get_tree().get_nodes_in_group("town_center"):
		if is_instance_valid(tc) and tc is Node2D and tc.get("faction_id") == FactionManager.ENEMY:
			return (tc as Node2D).global_position
	return ENEMY_BASE_POS

func _process(delta: float) -> void:
	if not initialized:
		return
	game_time += delta
	tick_timer += delta
	var interval: float = _current_interval()
	if tick_timer >= interval:
		tick_timer = 0.0
		_ai_tick()

func _current_interval() -> float:
	var ramps: int = int(game_time / RAMP_PERIOD)
	var interval: float = wave_interval - float(ramps) * RAMP_STEP
	return max(interval, TICK_INTERVAL_MIN)

func _ai_tick() -> void:
	_phase_train_at_barracks()
	_phase_recolectar()
	_phase_construir()
	_phase_atacar()

func _phase_train_at_barracks() -> void:
	var army: Array = _get_enemy_soldiers()
	if max_soldiers > 0 and army.size() >= max_soldiers:
		return
	# Keep roughly 1 archer per 2 melee. Classified via sprite_asset (node
	# names get auto-renamed on sibling conflicts, so they are unreliable).
	var archers: int = 0
	for s in army:
		if String(s.get("sprite_asset")).contains("archer"):
			archers += 1
	var melee: int = army.size() - archers
	for b in _get_enemy_buildings():
		if b.building_name == "Barracks" and b.queue.size() < b.MAX_QUEUE:
			var slot: int = 1 if (b.has_train_slot(1) and archers * 2 < melee) else 0
			b.try_queue_training(slot)

func _phase_recolectar() -> void:
	var villagers: Array = _get_enemy_villagers()
	var trees: Array = get_tree().get_nodes_in_group("resources")
	if trees.is_empty():
		return
	for v in villagers:
		if not is_instance_valid(v):
			continue
		if v.has_method("is_harvesting") and v.is_harvesting():
			continue
		var nearest: Node = _find_nearest_to(v, trees)
		if nearest != null:
			v.harvest(nearest)

func _phase_construir() -> void:
	if not _has_enemy_barracks():
		_try_build_barracks()
		return
	_try_build_tower()

func _try_build_barracks() -> void:
	if not ResourceManager.can_afford(BARRACKS_COST, FactionManager.ENEMY):
		return
	ResourceManager.spend(BARRACKS_COST, FactionManager.ENEMY)
	var pos: Vector2 = base_pos + Vector2(
		randf_range(-BARRACKS_OFFSET_RANGE, BARRACKS_OFFSET_RANGE),
		randf_range(-BARRACKS_OFFSET_RANGE, BARRACKS_OFFSET_RANGE)
	)
	_place_enemy_building("res://scenes/buildings/EnemyBarracks.tscn", pos)

## One tower per AI tick, at fixed slots around the TC, capped by difficulty.
func _try_build_tower() -> void:
	var towers: int = _count_enemy_towers()
	if towers >= max_towers:
		return
	if not ResourceManager.can_afford(TOWER_COST, FactionManager.ENEMY):
		return
	ResourceManager.spend(TOWER_COST, FactionManager.ENEMY)
	var pos: Vector2 = base_pos + TOWER_OFFSETS[towers % TOWER_OFFSETS.size()]
	_place_enemy_building("res://scenes/buildings/EnemyTower.tscn", pos)

func _place_enemy_building(scene_path: String, pos: Vector2) -> void:
	pos.x = clamp(pos.x, MAP_MIN, MAP_MAX)
	pos.y = clamp(pos.y, MAP_MIN, MAP_MAX)
	var packed: PackedScene = load(scene_path)
	if packed == null:
		return
	var building: Node = packed.instantiate()
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return
	scene_root.add_child(building)
	if building is Node2D:
		(building as Node2D).global_position = pos

func _phase_atacar() -> void:
	var soldiers: Array = _get_enemy_soldiers()
	if soldiers.size() < ATTACK_FORCE_MIN:
		return
	var player_tc: Node = _get_player_tc()
	if player_tc == null:
		return
	var target_pos: Vector2 = (player_tc as Node2D).global_position
	for s in soldiers:
		if is_instance_valid(s) and s.has_method("attack_move"):
			s.attack_move(target_pos)

func _get_enemy_buildings() -> Array:
	return get_tree().get_nodes_in_group("enemy_buildings")

func _get_enemy_villagers() -> Array:
	var result: Array = []
	for v in get_tree().get_nodes_in_group("villagers"):
		if is_instance_valid(v) and v.get("faction_id") == FactionManager.ENEMY:
			result.append(v)
	return result

func _get_enemy_soldiers() -> Array:
	var result: Array = []
	for s in get_tree().get_nodes_in_group("soldiers"):
		if not is_instance_valid(s):
			continue
		if s.get("faction_id") != FactionManager.ENEMY:
			continue
		if s.has_method("is_dying") and s.is_dying():
			continue
		result.append(s)
	return result

func _has_enemy_barracks() -> bool:
	for b in _get_enemy_buildings():
		if b.building_name == "Barracks":
			return true
	return false

func _count_enemy_towers() -> int:
	var count: int = 0
	for b in _get_enemy_buildings():
		if is_instance_valid(b) and b.building_name == "Tower":
			count += 1
	return count

func _get_player_tc() -> Node:
	for b in get_tree().get_nodes_in_group("player_buildings"):
		if b.building_name == "Town Center":
			return b
	return null

func _find_nearest_to(node: Node2D, candidates: Array) -> Node:
	var nearest: Node = null
	var nearest_dist: float = INF
	for c in candidates:
		if not is_instance_valid(c):
			continue
		var n2d := c as Node2D
		if n2d == null:
			continue
		var d: float = node.global_position.distance_to(n2d.global_position)
		if d < nearest_dist:
			nearest_dist = d
			nearest = c
	return nearest
