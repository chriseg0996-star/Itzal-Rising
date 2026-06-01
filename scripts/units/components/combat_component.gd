class_name CombatComponent
extends Node

signal attack_started(target: CharacterBody2D)
signal attack_landed(target: CharacterBody2D, damage: float)

enum State { IDLE, CHASING, ATTACKING }

@export var aggro_range: float = 250.0
@export var attack_damage: float = 10.0
@export var attack_range: float = 80.0
@export var attack_cooldown: float = 1.0
@export var scan_interval: float = 0.3
@export var enemy_group: String = "enemy_units"

var _state: State = State.IDLE
var _owner_unit: CharacterBody2D = null
var _target: CharacterBody2D = null
var _forced_target: bool = false
var _cooldown_timer: float = 0.0
var _scan_timer: float = 0.0

func _ready() -> void:
	_owner_unit = get_parent() as CharacterBody2D

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
	var nearest: CharacterBody2D = null
	var nearest_dist: float = INF
	for node in get_tree().get_nodes_in_group(enemy_group):
		var unit: CharacterBody2D = node as CharacterBody2D
		if unit == null or not is_instance_valid(unit):
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
	var stat: Node = _target.get_node_or_null("StatComponent")
	if stat == null or not stat.has_method("take_damage"):
		return
	_cooldown_timer = attack_cooldown
	attack_started.emit(_target)
	stat.take_damage(attack_damage)
	attack_landed.emit(_target, attack_damage)
	_spawn_impact(_target.global_position)

func _is_unit_dead(unit: Node) -> bool:
	var stat: Node = unit.get_node_or_null("StatComponent")
	if stat != null and stat.has_method("is_dead"):
		return stat.is_dead()
	return false

func force_target(unit: CharacterBody2D) -> void:
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
