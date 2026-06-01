class_name EnemySoldier
extends CharacterBody2D

signal unit_died(unit: CharacterBody2D)

enum State { IDLE, MOVING, ATTACKING, DYING }

const DEATH_FADE_TIME: float = 0.5
const SELECTION_RADIUS: float = 22.0
const SELECTION_COLOR: Color = Color(0.27, 0.86, 0.50, 1.0)
const SELECTION_WIDTH: float = 3.0
const SELECTION_SEGMENTS: int = 32

@export var speed:           float  = 110.0
@export var map_bounds:      Rect2  = Rect2(4.0, 4.0, 2040.0, 2040.0)
@export var faction:         String = "enemy"
@export var sprite_asset:    String = "enemy_soldier"
@export var max_hp:          int    = 120
@export var damage:          int    = 12
@export var attack_range:    float  = 80.0
@export var attack_interval: float  = 1.2

@onready var _nav_agent: NavigationAgent2D = $NavigationAgent2D
@onready var _hp_bar_fg:  ColorRect        = $HPBarFG
@onready var _detection:  Area2D           = $DetectionArea
@onready var _hitbox:     Area2D           = $Hitbox

var hp:               int     = 0
var selected:         bool    = false
var _state:           State   = State.IDLE
var _has_destination: bool    = false
var _destination:     Vector2 = Vector2.ZERO
var _is_attack_move:  bool    = false
var _current_target:  Node    = null
var _attack_timer:    float   = 0.0
var _death_timer:     float   = 0.0
var _hp_bar_width:    float   = 32.0

func _ready() -> void:
	add_to_group("soldiers")
	add_to_group("combat_units")
	if faction == "player":
		add_to_group("player_units")
	hp = max_hp
	if _hp_bar_fg != null:
		_hp_bar_width = _hp_bar_fg.offset_right - _hp_bar_fg.offset_left
	_update_hp_bar()
	_apply_sprite(sprite_asset)
	await get_tree().physics_frame

func is_dying() -> bool:
	return _state == State.DYING

func set_selected(value: bool) -> void:
	if selected == value:
		return
	selected = value
	queue_redraw()

func move_to(target: Vector2) -> void:
	if _state == State.DYING:
		return
	_has_destination = true
	_destination = target
	_is_attack_move = false
	_current_target = null
	_attack_timer = 0.0
	_state = State.MOVING
	_nav_agent.target_position = target

func attack_move(target: Vector2) -> void:
	if _state == State.DYING:
		return
	_has_destination = true
	_destination = target
	_is_attack_move = true
	_current_target = null
	_attack_timer = 0.0
	_state = State.MOVING
	_nav_agent.target_position = target

func take_damage(amount: int) -> void:
	if _state == State.DYING:
		return
	hp = max(0, hp - amount)
	_update_hp_bar()
	if hp <= 0:
		_enter_dying()

func _physics_process(delta: float) -> void:
	if _state == State.DYING:
		_process_dying(delta)
		return
	match _state:
		State.IDLE:
			_scan_and_engage()
		State.MOVING:
			if _is_attack_move:
				_scan_and_engage()
				if _state == State.ATTACKING:
					return
			_process_moving(delta)
		State.ATTACKING:
			_attack_step(delta)

func _scan_and_engage() -> void:
	var target := _find_target()
	if target != null:
		_current_target = target
		_attack_timer = 0.0
		_state = State.ATTACKING

func _process_moving(delta: float) -> void:
	if _nav_agent.is_navigation_finished():
		_state = State.IDLE
		_has_destination = false
		_is_attack_move = false
		return
	var next: Vector2 = _nav_agent.get_next_path_position()
	var to_next: Vector2 = next - global_position
	var dist: float = to_next.length()
	if dist < 0.5:
		return
	var step: Vector2 = to_next / dist * speed * delta
	if step.length() > dist:
		step = to_next
	global_position += step
	var b: Rect2 = map_bounds.grow(-4.0)
	global_position = global_position.clamp(b.position, b.end)

func _attack_step(delta: float) -> void:
	if not _is_target_alive(_current_target):
		_leave_attacking()
		return
	if not _target_in_range(_current_target):
		_leave_attacking()
		return
	_attack_timer += delta
	if _attack_timer >= attack_interval:
		_attack_timer = 0.0
		if _current_target.has_method("take_damage"):
			_current_target.take_damage(damage)

func _leave_attacking() -> void:
	_current_target = null
	_attack_timer = 0.0
	if _has_destination:
		_state = State.MOVING
		_nav_agent.target_position = _destination
	else:
		_state = State.IDLE

func _find_target() -> Node:
	if _detection == null:
		return null
	var nearest: Node = null
	var nearest_dist: float = INF
	for area in _detection.get_overlapping_areas():
		var parent: Node = area.get_parent()
		if parent == self or not is_instance_valid(parent):
			continue
		if not (parent.is_in_group("combat_units") or parent.is_in_group("buildings")):
			continue
		var f = parent.get("faction")
		if f == null or f == faction:
			continue
		if not _is_target_alive(parent):
			continue
		var d: float = global_position.distance_to((parent as Node2D).global_position)
		if d < nearest_dist:
			nearest_dist = d
			nearest = parent
	return nearest

func _is_target_alive(t) -> bool:
	if t == null or not is_instance_valid(t):
		return false
	if t.get("dying") == true:
		return false
	if t.has_method("is_dying") and t.is_dying():
		return false
	var h = t.get("hp")
	if h != null and int(h) <= 0:
		return false
	return true

func _target_in_range(t) -> bool:
	if t == null or not is_instance_valid(t):
		return false
	if _detection == null:
		return false
	for area in _detection.get_overlapping_areas():
		if area.get_parent() == t:
			return true
	return false

func _update_hp_bar() -> void:
	if _hp_bar_fg == null:
		return
	var ratio: float = clampf(float(hp) / float(max_hp), 0.0, 1.0)
	_hp_bar_fg.offset_right = _hp_bar_fg.offset_left + _hp_bar_width * ratio

func _enter_dying() -> void:
	_state = State.DYING
	_death_timer = 0.0
	_current_target = null
	if _hitbox != null:
		_hitbox.monitorable = false
		_hitbox.monitoring = false
	if _detection != null:
		_detection.monitoring = false

func _process_dying(delta: float) -> void:
	_death_timer += delta
	var t: float = clampf(_death_timer / DEATH_FADE_TIME, 0.0, 1.0)
	modulate.a = 1.0 - t
	if _death_timer >= DEATH_FADE_TIME:
		die()

func die() -> void:
	unit_died.emit(self)
	queue_free()

func _draw() -> void:
	if not selected or _state == State.DYING:
		return
	draw_arc(Vector2.ZERO, SELECTION_RADIUS, 0.0, TAU, SELECTION_SEGMENTS, SELECTION_COLOR, SELECTION_WIDTH, true)

func _apply_sprite(asset: String) -> void:
	if asset == "":
		return
	var existing := get_node_or_null("Sprite")
	if existing != null and existing is CanvasItem:
		(existing as CanvasItem).visible = false
	var sprite_2d := Sprite2D.new()
	sprite_2d.texture = TextureGenerator.get_texture(asset)
	sprite_2d.centered = true
	add_child(sprite_2d)
	if existing != null:
		move_child(sprite_2d, existing.get_index() + 1)
