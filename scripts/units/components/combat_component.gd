class_name CombatComponent
extends Node

signal attack_started(target: Node2D)
signal attack_landed(target: Node2D, damage: float)

enum State { IDLE, CHASING, ATTACKING }

## Attack ranges above this fire a Projectile (deferred damage) instead of
## instant hitscan — archers/ranged read as ranged; melee stays instant.
const RANGED_THRESHOLD: float = 120.0

## Rock-paper-scissors: each class deals COUNTER_MULT vs the class it counters.
const COUNTERS: Dictionary = {&"cavalry": &"ranged", &"ranged": &"infantry", &"infantry": &"cavalry"}
const COUNTER_MULT: float = 1.5

@export var aggro_range: float = 250.0
@export var attack_damage: float = 10.0
@export var attack_range: float = 80.0
@export var attack_cooldown: float = 1.0
@export var scan_interval: float = 0.3
@export var unit_class: StringName = &"infantry"
## Broad group scanned for candidates; hostility is decided by FactionManager.
@export var scan_group: String = "combat_units"

var _state: State = State.IDLE
var _owner_unit: CharacterBody2D = null
var _target: Node2D = null
var _forced_target: bool = false
var _cooldown_timer: float = 0.0
var _scan_timer: float = 0.0

func _ready() -> void:
	_owner_unit = get_parent() as CharacterBody2D
	if _owner_unit != null:
		var fac: FactionData = FactionManager.get_faction(int(_owner_unit.get("faction_id")))
		if fac != null:
			attack_damage *= fac.atk_mult

func _physics_process(delta: float) -> void:
	if _cooldown_timer > 0.0:
		_cooldown_timer -= delta
	_scan_timer -= delta
	if _scan_timer <= 0.0:
		_scan_timer = scan_interval
		if not _forced_target:
			_scan_for_target()
	_validate_target()
	_run_state()

func _scan_for_target() -> void:
	if _owner_unit == null:
		return
	var own_fid: int = int(_owner_unit.get("faction_id"))
	var nearest: CharacterBody2D = null
	var nearest_dist: float = INF
	for node in get_tree().get_nodes_in_group(scan_group):
		var unit: CharacterBody2D = node as CharacterBody2D
		if unit == null or not is_instance_valid(unit) or unit == _owner_unit:
			continue
		var tfid: Variant = unit.get("faction_id")
		if tfid == null or not FactionManager.is_hostile(own_fid, int(tfid)):
			continue
		if _is_unit_dead(unit):
			continue
		var d: float = _owner_unit.global_position.distance_to(unit.global_position)
		if d > aggro_range:
			continue
		if d < nearest_dist:
			nearest_dist = d
			nearest = unit
	if nearest != null:
		_target = nearest
		return
	# No hostile unit in aggro: fall back to hostile buildings (lets armies
	# raze bases instead of idling next to them). Units always take priority.
	var nearest_building: Node2D = null
	nearest_dist = INF
	for node in get_tree().get_nodes_in_group("buildings"):
		var building: Node2D = node as Node2D
		if building == null or not is_instance_valid(building):
			continue
		var bfid: Variant = building.get("faction_id")
		if bfid == null or not FactionManager.is_hostile(own_fid, int(bfid)):
			continue
		if _is_unit_dead(building):
			continue
		var d: float = _owner_unit.global_position.distance_to(building.global_position)
		if d > aggro_range:
			continue
		if d < nearest_dist:
			nearest_dist = d
			nearest_building = building
	if nearest_building != null:
		_target = nearest_building

func _validate_target() -> void:
	if _target == null:
		_state = State.IDLE
		return
	if not is_instance_valid(_target) or _is_unit_dead(_target):
		_target = null
		_forced_target = false
		_state = State.IDLE

func _run_state() -> void:
	if _owner_unit == null or _target == null:
		_state = State.IDLE
		return
	var dist: float = _owner_unit.global_position.distance_to(_target.global_position)
	if dist > attack_range:
		_state = State.CHASING
		_chase()
	else:
		_state = State.ATTACKING
		_attack()

func _chase() -> void:
	var mover: Node = _owner_unit.get_node_or_null("MovementComponent")
	if mover != null and mover.has_method("move_to"):
		mover.move_to(_target.global_position)

func _attack() -> void:
	if _cooldown_timer > 0.0:
		return
	if _target == null or not is_instance_valid(_target):
		return
	# Player-side units carry the match's attack research bonus, and player
	# cavalry the signature charge multiplier.
	var dmg: float = attack_damage
	if _owner_unit != null and FactionManager.is_player_faction(int(_owner_unit.get("faction_id"))):
		dmg += GameStats.player_atk_bonus()
		if unit_class == &"cavalry":
			dmg *= GameStats.player_cavalry_mult()
	# Rock-paper-scissors counter bonus vs the class this unit counters.
	var is_counter: bool = COUNTERS.get(unit_class, &"") == _target_class(_target)
	if is_counter:
		dmg *= COUNTER_MULT
	var num_color: Color = Color(1.0, 0.5, 0.1) if is_counter else Color(0.95, 0.95, 0.95)
	var num_prefix: String = "+" if is_counter else ""
	# Ranged: launch a projectile that applies the damage on impact. We must NOT
	# also apply damage or spawn an impact here — the projectile owns both.
	if attack_range > RANGED_THRESHOLD:
		_cooldown_timer = attack_cooldown
		attack_started.emit(_target)
		var color: Color = Color(1.0, 0.85, 0.3, 1.0)
		var fac: FactionData = FactionManager.get_faction(int(_owner_unit.get("faction_id")))
		if fac != null:
			color = fac.primary_color
		Projectile.fire(get_tree().current_scene, _owner_unit.global_position, _target, dmg, color, is_counter)
		attack_landed.emit(_target, dmg)
		return
	var stat: Node = _target.get_node_or_null("StatComponent")
	if stat != null and stat.has_method("take_damage"):
		_cooldown_timer = attack_cooldown
		attack_started.emit(_target)
		stat.take_damage(dmg)
		attack_landed.emit(_target, dmg)
		_spawn_impact(_target.global_position)
		DamageNumbers.spawn(get_tree().current_scene, dmg, _target.global_position, num_color, num_prefix)
	elif _target.has_method("take_damage"):
		# Buildings carry hp on the node itself (building.gd), no StatComponent.
		_cooldown_timer = attack_cooldown
		attack_started.emit(_target)
		_target.take_damage(int(dmg))
		attack_landed.emit(_target, dmg)
		_spawn_impact(_target.global_position)

## The combat class of a target, or &"none" if it has no CombatComponent
## (workers, buildings) — those are never countered.
func _target_class(target: Node) -> StringName:
	if target == null or not is_instance_valid(target):
		return &"none"
	var cc: Node = target.get_node_or_null("CombatComponent")
	if cc != null:
		return StringName(cc.get("unit_class"))
	return &"none"

func _is_unit_dead(unit: Node) -> bool:
	var stat: Node = unit.get_node_or_null("StatComponent")
	if stat != null and stat.has_method("is_dead"):
		return stat.is_dead()
	var dying: Variant = unit.get("dying")
	if dying != null:
		return bool(dying)
	return false

func force_target(unit: Node2D) -> void:
	_target = unit
	_forced_target = true

func clear_target() -> void:
	_target = null
	_forced_target = false
	_state = State.IDLE

func is_engaged() -> bool:
	return _state != State.IDLE and _target != null

func _spawn_impact(target_pos: Vector2) -> void:
	var rect := ColorRect.new()
	rect.color = Color(0.0, 1.0, 0.9, 0.8)
	rect.size = Vector2(8, 8)
	rect.position = target_pos - Vector2(4, 4)
	get_tree().current_scene.add_child(rect)
	var tween := rect.create_tween()
	tween.tween_property(rect, "modulate:a", 0.0, 0.2)
	tween.tween_callback(rect.queue_free)
