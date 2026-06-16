class_name MovementComponent
extends Node

signal arrived(unit: CharacterBody2D)

@export var speed: float = 120.0
@export var arrival_threshold: float = 8.0
@export var map_bounds: Rect2 = Rect2(0, 0, 2048, 2048)

## Local separation so units never stack on the same pixel — they fan out while
## moving, while fighting, and even when idle in a clump (so you can count them).
const SEPARATION_RADIUS: float = 28.0
const SEPARATION_STRENGTH: float = 65.0
const SEPARATION_GROUP: StringName = &"combat_units"

var _target_position: Vector2 = Vector2.ZERO
var _moving: bool = false
var _owner_unit: CharacterBody2D

func _ready() -> void:
	_owner_unit = get_parent() as CharacterBody2D
	assert(_owner_unit != null, "MovementComponent must be a child of a CharacterBody2D")

func _physics_process(_delta: float) -> void:
	var sep: Vector2 = _separation()
	if _moving:
		var to_target: Vector2 = _target_position - _owner_unit.global_position
		var dist: float = to_target.length()
		if dist > arrival_threshold:
			_owner_unit.velocity = (to_target / dist) * speed + sep
			_owner_unit.move_and_slide()
			_clamp()
			return
		# Reached the goal — stop steering, but still let separation settle below.
		_moving = false
		arrived.emit(_owner_unit)
	# Idle: ease apart from any overlapping neighbours, otherwise rest.
	if sep.length() > 2.0:
		_owner_unit.velocity = sep
		_owner_unit.move_and_slide()
		_clamp()
	else:
		_owner_unit.velocity = Vector2.ZERO

## Sum of push-away vectors from nearby units, stronger the closer they are.
func _separation() -> Vector2:
	var push: Vector2 = Vector2.ZERO
	var pos: Vector2 = _owner_unit.global_position
	var r2: float = SEPARATION_RADIUS * SEPARATION_RADIUS
	for other in _owner_unit.get_tree().get_nodes_in_group(SEPARATION_GROUP):
		if other == _owner_unit or not is_instance_valid(other) or not (other is Node2D):
			continue
		var op: Vector2 = (other as Node2D).global_position
		var d2: float = pos.distance_squared_to(op)
		if d2 >= r2:
			continue
		if d2 <= 0.0001:
			# Exactly coincident: nudge in a per-unit fixed direction so they
			# still split apart instead of cancelling to zero.
			push += Vector2.from_angle(float(_owner_unit.get_instance_id() % 16) / 16.0 * TAU)
			continue
		var d: float = sqrt(d2)
		push += (pos - op) / d * (1.0 - d / SEPARATION_RADIUS)
	return push * SEPARATION_STRENGTH

func _clamp() -> void:
	if map_bounds.size != Vector2.ZERO:
		_owner_unit.global_position = _owner_unit.global_position.clamp(map_bounds.position, map_bounds.end)

func move_to(pos: Vector2) -> void:
	_target_position = pos
	_moving = true

func stop() -> void:
	_moving = false
	_owner_unit.velocity = Vector2.ZERO

func is_moving() -> bool:
	return _moving
