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
@export var faction_id:      int    = 1
@export var sprite_asset:    String = "enemy_soldier"
@export var max_hp:          int    = 120

@onready var _hp_bar_fg:  ColorRect        = $HPBarFG
@onready var _detection:  Area2D           = $DetectionArea
@onready var _hitbox:     Area2D           = $Hitbox

var selected:         bool    = false
var _state:           State   = State.IDLE
var _death_timer:     float   = 0.0
var _hp_bar_width:    float   = 32.0
var _movement_component: MovementComponent = null
var _stat:            StatComponent = null
var _base_modulate: Color = Color(1, 1, 1, 1)

func _ready() -> void:
	add_to_group("soldiers")
	add_to_group("combat_units")
	if faction_id == FactionManager.PLAYER:
		add_to_group("player_units")
	if _hp_bar_fg != null:
		_hp_bar_width = _hp_bar_fg.offset_right - _hp_bar_fg.offset_left
	_apply_sprite(sprite_asset)
	add_to_group("enemy_units")
	_movement_component = get_node_or_null("MovementComponent") as MovementComponent
	_stat = get_node_or_null("StatComponent") as StatComponent
	if _stat != null:
		_stat.died.connect(_on_died)
		_stat.health_changed.connect(_on_health_changed)
	_base_modulate = modulate
	_update_hp_bar()
	await get_tree().physics_frame

func _on_died(_owner_unit: CharacterBody2D = null) -> void:
	if SelectionManager.has_method("deselect_unit"):
		SelectionManager.deselect_unit(self)
	set_physics_process(false)
	set_process(false)
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.4)
	tween.tween_callback(queue_free)

func _on_health_changed(_current: float, _maximum: float) -> void:
	_update_hp_bar()
	_flash_hit()

func _flash_hit() -> void:
	if is_dying():
		return
	modulate = Color(2.0, 2.0, 2.0, _base_modulate.a)
	var tween := create_tween()
	tween.tween_property(self, "modulate", _base_modulate, 0.1)

func is_dying() -> bool:
	if _stat != null:
		return _stat.is_dead()
	return _state == State.DYING

func set_selected(value: bool) -> void:
	if selected == value:
		return
	selected = value
	queue_redraw()

func move_to(target: Vector2) -> void:
	if _state == State.DYING:
		return
	_state = State.MOVING
	if _movement_component != null:
		_movement_component.move_to(target)

func attack_move(target: Vector2) -> void:
	if _state == State.DYING:
		return
	_state = State.MOVING
	if _movement_component != null:
		_movement_component.move_to(target)

func take_damage(amount: int) -> void:
	if _stat != null:
		_stat.take_damage(float(amount))

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

func _update_hp_bar() -> void:
	if _hp_bar_fg == null or _stat == null:
		return
	var ratio: float = _stat.get_health_ratio()
	_hp_bar_fg.offset_right = _hp_bar_fg.offset_left + _hp_bar_width * ratio

func _enter_dying() -> void:
	_state = State.DYING
	_death_timer = 0.0
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
