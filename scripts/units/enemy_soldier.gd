class_name EnemySoldier
extends CharacterBody2D

signal unit_died(unit: CharacterBody2D)

enum State { IDLE, MOVING, ATTACKING, DYING }

const DEATH_FADE_TIME: float = 0.5
const SELECTION_RADIUS: float = 22.0
const SELECTION_COLOR: Color = Color(0.27, 0.86, 0.50, 1.0)
const SELECTION_WIDTH: float = 3.0
const SELECTION_SEGMENTS: int = 32

@export var map_bounds:      Rect2  = Rect2(4.0, 4.0, 2040.0, 2040.0)
@export var faction:         String = "enemy"
@export var sprite_asset:    String = "enemy_soldier"
@export var max_hp:          int    = 120

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
var _movement_component: MovementComponent = null

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
	add_to_group("enemy_units")
	_movement_component = get_node_or_null("MovementComponent") as MovementComponent
	var stat: Node = get_node_or_null("StatComponent")
	if stat != null:
		stat.died.connect(_on_died)
	await get_tree().physics_frame

func _on_died(_owner_unit: CharacterBody2D = null) -> void:
	if SelectionManager.has_method("deselect_unit"):
		SelectionManager.deselect_unit(self)
	set_physics_process(false)
	call_deferred("queue_free")

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
	if _movement_component != null:
		_movement_component.move_to(target)

func attack_move(target: Vector2) -> void:
	if _state == State.DYING:
		return
	_has_destination = true
	_destination = target
	_is_attack_move = true
	_current_target = null
	_attack_timer = 0.0
	_state = State.MOVING
	if _movement_component != null:
		_movement_component.move_to(target)

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
			pass
		State.MOVING:
			_process_moving(delta)
		State.ATTACKING:
			pass  # CombatComponent owns attack logic

func _process_moving(_delta: float) -> void:
	if _movement_component == null or not _movement_component.is_moving():
		_state = State.IDLE
		_has_destination = false
		_is_attack_move = false

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
