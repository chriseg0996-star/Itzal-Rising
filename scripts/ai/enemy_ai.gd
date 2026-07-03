extends Node

const TICK_INTERVAL_INITIAL: float = 45.0
const TICK_INTERVAL_MIN: float = 20.0
const RAMP_PERIOD: float = 60.0
const RAMP_STEP: float = 5.0

## Late game: past ESCALATION_TIME the AI attacks with smaller forces, trains
## past its difficulty cap and launches periodic all-in pushes. The period and
## training bonus are difficulty-scaled (see _apply_difficulty).
const ESCALATION_TIME: float = 360.0
const ALL_IN_PERIOD: float = 150.0  # normal-difficulty default
const ATTACK_FORCE_LATE: int = 3

const ENEMY_BASE_POS: Vector2 = Vector2(1600, 1600)
const BARRACKS_OFFSET_RANGE: float = 220.0
const ATTACK_FORCE_MIN: int = 5
const BARRACKS_COST: Dictionary = {"madera": 75}
const PYLON_COST: Dictionary = {"madera": 75, "oro": 25}
const BEACON_COST: Dictionary = {"madera": 400, "oro": 300}
const BEACON_TIME: float = 480.0   # hard only: start its own Ascension at ~8 min
const TOWER_COST: Dictionary = {"madera": 150}
## Fixed tower slots around the enemy TC, facing the player's approach.
const TOWER_OFFSETS: Array[Vector2] = [
	Vector2(-260.0, -60.0),
	Vector2(-60.0, -260.0),
	Vector2(-300.0, 180.0),
]
const MAP_MIN: float = 80.0
const MAP_MAX: float = MapConfig.WORLD_SIZE - 80.0

## "Farming phase": the AI gathers, builds and trains but does not march out
## before this, giving both sides an uncontested economy/build-up window
## (AoE-style pacing). The bigger map also delays first contact on its own.
const FIRST_ATTACK_TIME: float = 180.0

## The AI advances eras on a timer so it keeps stat parity with a teching player.
const AI_ERA2_TIME: float = 240.0
const AI_ERA3_TIME: float = 480.0

var tick_timer: float = 0.0
var game_time: float = 0.0
var initialized: bool = false
var wave_interval: float = TICK_INTERVAL_INITIAL
var max_soldiers: int = 0  # 0 = uncapped
var max_towers: int = 2
## Difficulty-scaled endgame: easy disables all-ins (period 0) and trains a
## smaller late-game bonus; hard pushes harder.
var all_in_period: float = ALL_IN_PERIOD
var late_cap_bonus: int = 6
## Resolved from the AI's town center at bootstrap so map layouts can move the
## base; falls back to the legacy constant if no TC is found.
var base_pos: Vector2 = ENEMY_BASE_POS
var _next_all_in: float = ESCALATION_TIME + ALL_IN_PERIOD
## The faction this AI drives. Decay by default; when the human plays Decay,
## the AI takes over Itzal instead.
var ai_faction_id: int = FactionManager.ENEMY
## Campaign "fast_aggro" mission modifier scales the wave interval (1.0 = none).
var mission_wave_mult: float = 1.0

func _ready() -> void:
	call_deferred("_bootstrap")
	_apply_difficulty()

func reset() -> void:
	tick_timer = 0.0
	game_time = 0.0
	initialized = false
	# Resolve campaign modifiers here so a later skirmish (ActiveMission inactive)
	# always falls back to 1.0.
	mission_wave_mult = 1.0
	if ActiveMission.is_active() and String(ActiveMission.get_data().get("modifier", "")) == "fast_aggro":
		mission_wave_mult = 0.6
	_apply_difficulty()
	_next_all_in = ESCALATION_TIME + all_in_period
	call_deferred("_bootstrap")

func _apply_difficulty() -> void:
	wave_interval = TICK_INTERVAL_INITIAL
	max_soldiers = 0
	max_towers = 2
	all_in_period = ALL_IN_PERIOD
	late_cap_bonus = 6
	match GameSettings.difficulty:
		"easy":
			wave_interval *= 1.5
			max_soldiers = 3
			max_towers = 1
			all_in_period = 0.0  # no all-in pushes — stays beatable for new players
			late_cap_bonus = 3
		"normal":
			pass  # unchanged
		"hard":
			wave_interval *= 0.7
			max_soldiers = 8
			max_towers = 3
			all_in_period = 120.0
	wave_interval *= mission_wave_mult

func _bootstrap() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if GameSettings.player_faction_id == FactionManager.ENEMY:
		ai_faction_id = FactionManager.PLAYER
	else:
		ai_faction_id = FactionManager.ENEMY
	base_pos = _resolve_base_pos()
	initialized = true
	_ai_tick()

func _resolve_base_pos() -> Vector2:
	for tc in get_tree().get_nodes_in_group("town_center"):
		if is_instance_valid(tc) and tc is Node2D and tc.get("faction_id") == ai_faction_id:
			return (tc as Node2D).global_position
	return ENEMY_BASE_POS

func _process(delta: float) -> void:
	if not initialized:
		return
	game_time += delta
	GameStats.set_ai_era(1 + (1 if game_time >= AI_ERA2_TIME else 0) + (1 if game_time >= AI_ERA3_TIME else 0))
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
	_phase_all_in()

func _phase_train_at_barracks() -> void:
	var army: Array = _get_enemy_soldiers()
	var cap: int = max_soldiers
	if cap > 0 and game_time >= ESCALATION_TIME:
		cap += late_cap_bonus
	if cap > 0 and army.size() >= cap:
		return
	# Aim for a ~2:1:1 melee:archer:cavalry mix. Classified via sprite_asset
	# (node names get auto-renamed on sibling conflicts, so they're unreliable).
	var archers: int = 0
	var cavalry: int = 0
	var siege: int = 0
	for s in army:
		var asset: String = String(s.get("sprite_asset"))
		if asset.contains("archer"):
			archers += 1
		elif asset.contains("raider"):
			cavalry += 1
		elif asset.contains("siege"):
			siege += 1
	var melee: int = army.size() - archers - cavalry - siege
	for b in _get_enemy_buildings():
		if b.building_name == "Barracks" and b.queue.size() < b.MAX_QUEUE:
			var slot: int = 0
			# A couple of siege engines once teched + with an army to escort them.
			if b.has_train_slot(3) and siege < 2 and army.size() >= 6:
				slot = 3
			elif b.has_train_slot(2) and cavalry * 2 < melee:
				slot = 2
			elif b.has_train_slot(1) and archers * 2 < melee:
				slot = 1
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
	# Supply first: with <2 headroom the next waves stall, so a pylon outranks
	# everything else in the build order.
	if ResourceManager.get_supply_cap(ai_faction_id) - ResourceManager.get_supply_used(ai_faction_id) < 2:
		_try_build_pylon()
		return
	if not _has_enemy_barracks():
		_try_build_barracks()
		return
	# Hard only: press the win-condition button too — an own Ascension Beacon
	# once the late game arrives.
	if GameSettings.difficulty == "hard" and game_time >= BEACON_TIME and not _has_enemy_beacon():
		_try_build_beacon()
		return
	_try_build_tower()

func _has_enemy_beacon() -> bool:
	for b in get_tree().get_nodes_in_group("beacons"):
		if is_instance_valid(b) and int(b.get("faction_id")) == ai_faction_id and not bool(b.get("dying")):
			return true
	return false

func _try_build_beacon() -> void:
	if not ResourceManager.can_afford(BEACON_COST, ai_faction_id):
		return
	ResourceManager.spend(BEACON_COST, ai_faction_id)
	var packed: PackedScene = BuildingPlacer.get_building_scene(ai_faction_id, &"beacon")
	if packed == null:
		return
	# The shared beacon scene defaults to faction 0 — set the owner BEFORE
	# adding to the tree so _ready joins the right groups.
	var beacon: Node = packed.instantiate()
	beacon.set("faction_id", ai_faction_id)
	var pos: Vector2 = base_pos + Vector2(randf_range(-160.0, 160.0), randf_range(-160.0, 160.0))
	pos.x = clamp(pos.x, MAP_MIN, MAP_MAX)
	pos.y = clamp(pos.y, MAP_MIN, MAP_MAX)
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		beacon.queue_free()
		return
	scene_root.add_child(beacon)
	if beacon is Node2D:
		(beacon as Node2D).global_position = pos

func _try_build_pylon() -> void:
	if not ResourceManager.can_afford(PYLON_COST, ai_faction_id):
		return
	ResourceManager.spend(PYLON_COST, ai_faction_id)
	var pos: Vector2 = base_pos + Vector2(
		randf_range(-BARRACKS_OFFSET_RANGE, BARRACKS_OFFSET_RANGE),
		randf_range(-BARRACKS_OFFSET_RANGE, BARRACKS_OFFSET_RANGE)
	)
	_place_enemy_building(BuildingPlacer.get_building_scene(ai_faction_id, &"pylon"), pos)

func _try_build_barracks() -> void:
	if not ResourceManager.can_afford(BARRACKS_COST, ai_faction_id):
		return
	ResourceManager.spend(BARRACKS_COST, ai_faction_id)
	var pos: Vector2 = base_pos + Vector2(
		randf_range(-BARRACKS_OFFSET_RANGE, BARRACKS_OFFSET_RANGE),
		randf_range(-BARRACKS_OFFSET_RANGE, BARRACKS_OFFSET_RANGE)
	)
	_place_enemy_building(BuildingPlacer.get_building_scene(ai_faction_id, &"barracks"), pos)

## One tower per AI tick, at fixed slots around the TC, capped by difficulty.
func _try_build_tower() -> void:
	var towers: int = _count_enemy_towers()
	if towers >= max_towers:
		return
	if not ResourceManager.can_afford(TOWER_COST, ai_faction_id):
		return
	ResourceManager.spend(TOWER_COST, ai_faction_id)
	var pos: Vector2 = base_pos + TOWER_OFFSETS[towers % TOWER_OFFSETS.size()]
	_place_enemy_building(BuildingPlacer.get_building_scene(ai_faction_id, &"tower"), pos)

func _place_enemy_building(packed: PackedScene, pos: Vector2) -> void:
	pos.x = clamp(pos.x, MAP_MIN, MAP_MAX)
	pos.y = clamp(pos.y, MAP_MIN, MAP_MAX)
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
	# Hold during the farming phase (a monument still triggers force_attack).
	if game_time < FIRST_ATTACK_TIME:
		return
	var soldiers: Array = _get_enemy_soldiers()
	var threshold: int = ATTACK_FORCE_MIN if game_time < ESCALATION_TIME else ATTACK_FORCE_LATE
	if soldiers.size() < threshold:
		return
	var target: Node = _get_attack_target()
	if target == null:
		return
	var target_pos: Vector2 = (target as Node2D).global_position
	for s in soldiers:
		if is_instance_valid(s) and s.has_method("attack_move"):
			s.attack_move(target_pos)

## Periodic late-game all-in: every soldier attacks regardless of force size.
## Disabled on easy (all_in_period == 0).
func _phase_all_in() -> void:
	if all_in_period <= 0.0:
		return
	if game_time < _next_all_in:
		return
	_next_all_in += all_in_period
	var target: Node = _get_attack_target()
	if target == null:
		return
	if force_attack((target as Node2D).global_position):
		AlertManager.push("Enemy all-in incoming!", "warning")
		var cam: Node = get_tree().get_first_node_in_group("rts_camera")
		if cam != null and cam.has_method("shake"):
			cam.shake(8.0, 0.4)

## Sends every AI soldier at a position immediately, ignoring force thresholds.
## Used by the monument countdown so a fresh monument is contested right away
## instead of waiting out the next AI tick.
func force_attack(target_pos: Vector2) -> bool:
	var pushed: bool = false
	for s in _get_enemy_soldiers():
		if is_instance_valid(s) and s.has_method("attack_move"):
			s.attack_move(target_pos)
			pushed = true
	return pushed

## A player Monument outranks the TC as the AI's objective.
func _get_attack_target() -> Node:
	var monument: Node = _get_player_monument()
	if monument != null:
		return monument
	return _get_player_tc()

func _get_player_monument() -> Node:
	for b in get_tree().get_nodes_in_group("player_buildings"):
		if is_instance_valid(b) and b.building_name == "Monument":
			return b
	return null

func _get_enemy_buildings() -> Array:
	return get_tree().get_nodes_in_group("enemy_buildings")

func _get_enemy_villagers() -> Array:
	var result: Array = []
	for v in get_tree().get_nodes_in_group("villagers"):
		if is_instance_valid(v) and v.get("faction_id") == ai_faction_id:
			result.append(v)
	return result

func _get_enemy_soldiers() -> Array:
	var result: Array = []
	for s in get_tree().get_nodes_in_group("soldiers"):
		if not is_instance_valid(s):
			continue
		if s.get("faction_id") != ai_faction_id:
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
