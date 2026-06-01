class_name MovementComponent
extends Node

signal arrived(unit: CharacterBody2D)

@export var speed: float = 120.0
@export var arrival_threshold: float = 8.0
@export var map_bounds: Rect2 = Rect2(0, 0, 2048, 2048)

var _target_position: Vector2 = Vector2.ZERO
var _moving: bool = false
var _owner_unit: CharacterBody2D

func _ready() -> void:
	_owner_unit = get_parent() as CharacterBody2D
	assert(_owner_unit != null, "MovementComponent must be a child of a CharacterBody2D")

func _physics_process(_delta: float) -> void:
	if not _moving:
		return
	var to_target: Vector2 = _target_position - _owner_unit.global_position
	var dist: float = to_target.length()
	if dist <= arrival_threshold:
		_moving = false
		_owner_unit.velocity = Vector2.ZERO
		arrived.emit(_owner_unit)
		return
	var direction: Vector2 = to_target / dist
	_owner_unit.velocity = direction * speed
	_owner_unit.move_and_slide()
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
