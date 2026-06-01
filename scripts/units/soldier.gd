extends Node2D

enum State { IDLE, MOVING, ATTACKING, DYING }

const DEATH_FADE_TIME: float = 0.5
const SELECTION_RADIUS: float = 22.0
const SELECTION_COLOR: Color = Color(0.27, 0.86, 0.50, 1.0)
const SELECTION_WIDTH: float = 3.0
const SELECTION_SEGMENTS: int = 32

@export var faction: String = "player"
@export var sprite_asset: String = "soldier"
@export var max_hp: int = 120
@export var damage: int = 12
@export var attack_range: float = 80.0
@export var attack_interval: float = 1.2
@export var move_speed: float = 120.0

@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D
@onready var hp_bar_fg: ColorRect = $HPBarFG
@onready var detection_area: Area2D = $DetectionArea
@onready var hitbox: Area2D = $Hitbox

var hp: int = 0
var state: int = State.IDLE
var selected: bool = false
var has_destination: bool = false
var destination: Vector2 = Vector2.ZERO
var is_attack_move: bool = false
var current_target: Node = null
var attack_timer: float = 0.0
var death_timer: float = 0.0
var hp_bar_width: float = 32.0

func _ready() -> void:
	add_to_group("soldiers")
	add_to_group("combat_units")
	if faction == "player":
		add_to_group("player_units")
	hp = max_hp
	if hp_bar_fg != null:
		hp_bar_width = hp_bar_fg.offset_right - hp_bar_fg.offset_left
	_update_hp_bar()
	_apply_sprite(sprite_asset)

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

func is_dying() -> bool:
	return state == State.DYING

func set_selected(value: bool) -> void:
	if selected == value:
		return
	selected = value
	queue_redraw()

func move_to(target: Vector2) -> void:
	if state == State.DYING:
		return
	has_destination = true
	destination = target
	is_attack_move = false
	current_target = null
	attack_timer = 0.0
	state = State.MOVING
	nav_agent.target_position = target

func attack_move(target: Vector2) -> void:
	if state == State.DYING:
		return
	has_destination = true
	destination = target
	is_attack_move = true
	current_target = null
	attack_timer = 0.0
	state = State.MOVING
	nav_agent.target_position = target

func take_damage(amount: int) -> void:
	if state == State.DYING:
		return
	hp = max(0, hp - amount)
	_update_hp_bar()
	if hp <= 0:
		_enter_dying()

func _physics_process(delta: float) -> void:
	if state == State.DYING:
		_process_dying(delta)
		return
	match state:
		State.IDLE:
			_scan_and_engage()
		State.MOVING:
			if is_attack_move:
				_scan_and_engage()
				if state == State.ATTACKING:
					return
			_move_step(delta)
		State.ATTACKING:
			_attack_step(delta)

func _scan_and_engage() -> void:
	var target := _find_target()
	if target != null:
		current_target = target
		attack_timer = 0.0
		state = State.ATTACKING

func _move_step(delta: float) -> void:
	if nav_agent.is_navigation_finished():
		state = State.IDLE
		has_destination = false
		is_attack_move = false
		return
	var next_pos: Vector2 = nav_agent.get_next_path_position()
	var to_next: Vector2 = next_pos - global_position
	var dist: float = to_next.length()
	if dist < 0.5:
		return
	var step: Vector2 = to_next / dist * move_speed * delta
	if step.length() > dist:
		step = to_next
	global_position += step

func _attack_step(delta: float) -> void:
	if not _is_target_alive(current_target):
		_leave_attacking()
		return
	if not _target_in_range(current_target):
		_leave_attacking()
		return
	attack_timer += delta
	if attack_timer >= attack_interval:
		attack_timer = 0.0
		if current_target.has_method("take_damage"):
			current_target.take_damage(damage)

func _leave_attacking() -> void:
	current_target = null
	attack_timer = 0.0
	if has_destination:
		state = State.MOVING
		nav_agent.target_position = destination
	else:
		state = State.IDLE

func _find_target() -> Node:
	if detection_area == null:
		return null
	var overlapping := detection_area.get_overlapping_areas()
	var nearest: Node = null
	var nearest_dist: float = INF
	for area in overlapping:
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
	var d = t.get("dying")
	if d == true:
		return false
	var s = t.get("state")
	if s == State.DYING:
		return false
	var h = t.get("hp")
	if h != null and int(h) <= 0:
		return false
	return true

func _target_in_range(t) -> bool:
	if t == null or not is_instance_valid(t):
		return false
	if detection_area == null:
		return false
	for area in detection_area.get_overlapping_areas():
		if area.get_parent() == t:
			return true
	return false

func _update_hp_bar() -> void:
	if hp_bar_fg == null:
		return
	var ratio: float = clampf(float(hp) / float(max_hp), 0.0, 1.0)
	hp_bar_fg.offset_right = hp_bar_fg.offset_left + hp_bar_width * ratio

func _enter_dying() -> void:
	state = State.DYING
	death_timer = 0.0
	current_target = null
	if hitbox != null:
		hitbox.monitorable = false
		hitbox.monitoring = false
	if detection_area != null:
		detection_area.monitoring = false

func _process_dying(delta: float) -> void:
	death_timer += delta
	var t: float = clampf(death_timer / DEATH_FADE_TIME, 0.0, 1.0)
	modulate.a = 1.0 - t
	if death_timer >= DEATH_FADE_TIME:
		queue_free()

func _draw() -> void:
	if not selected or state == State.DYING:
		return
	draw_arc(Vector2.ZERO, SELECTION_RADIUS, 0.0, TAU, SELECTION_SEGMENTS, SELECTION_COLOR, SELECTION_WIDTH, true)
