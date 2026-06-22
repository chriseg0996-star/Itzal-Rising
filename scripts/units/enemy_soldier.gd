class_name EnemySoldier
extends CharacterBody2D

signal unit_died(unit: CharacterBody2D)

enum State { IDLE, MOVING, ATTACKING, DYING }

const DEATH_FADE_TIME: float = 0.5
const SELECTION_RADIUS: float = 22.0
const SELECTION_COLOR: Color = Color(0.27, 0.86, 0.50, 1.0)
const SELECTION_WIDTH: float = 3.0
const SELECTION_SEGMENTS: int = 32

var _selection_color: Color = SELECTION_COLOR

@export var map_bounds:      Rect2  = Rect2(4.0, 4.0, MapConfig.WORLD_SIZE - 8.0, MapConfig.WORLD_SIZE - 8.0)
@export var faction_id:      int    = 1
@export var sprite_asset:    String = "enemy_soldier"
@export var max_hp:          int    = 120

@onready var _hp_bar_fg:  ColorRect        = $HPBarFG
@onready var _detection:  Area2D           = $DetectionArea
@onready var _hitbox:     Area2D           = $Hitbox
@onready var _anim_sprite: AnimatedSprite2D = $AnimatedSprite2D

var selected:         bool    = false
var _state:           State   = State.IDLE:
	set(value):
		var changed: bool = _state != value
		_state = value
		if changed:
			_update_animation()
var _death_timer:     float   = 0.0
var _hp_bar_width:    float   = 32.0
var _movement_component: MovementComponent = null
var _stat:            StatComponent = null
var _base_modulate: Color = Color(1, 1, 1, 1)

func _ready() -> void:
	TextureGenerator.attach_shadow(self, 24.0, 10.0, 7.0, 0.32)
	add_to_group("soldiers")
	add_to_group("combat_units")
	var fac: FactionData = FactionManager.get_faction(faction_id)
	if fac != null:
		_selection_color = fac.primary_color
	if FactionManager.is_player_faction(faction_id):
		add_to_group("player_units")
	if _hp_bar_fg != null:
		_hp_bar_width = _hp_bar_fg.offset_right - _hp_bar_fg.offset_left
	UnitHpBar.enhance(self)
	var old_sprite := get_node_or_null("Sprite")
	if old_sprite != null and old_sprite is CanvasItem:
		(old_sprite as CanvasItem).visible = false
	_movement_component = get_node_or_null("MovementComponent") as MovementComponent
	_stat = get_node_or_null("StatComponent") as StatComponent
	if _stat != null:
		_stat.died.connect(_on_died)
		_stat.health_changed.connect(_on_health_changed)
	_base_modulate = modulate
	var combat := get_node_or_null("CombatComponent") as CombatComponent
	if combat != null:
		combat.attack_started.connect(_on_attack_started)
	if _anim_sprite != null:
		_anim_sprite.animation_finished.connect(_on_anim_finished)
	_update_hp_bar()
	_update_animation()
	await get_tree().physics_frame

func _on_died(_owner_unit: CharacterBody2D = null) -> void:
	_state = State.DYING
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

func _update_animation() -> void:
	if _anim_sprite == null:
		return
	match _state:
		State.IDLE:
			_anim_sprite.play("idle")
		State.MOVING:
			_anim_sprite.play("walk")
		State.ATTACKING:
			_anim_sprite.play("attack")
		State.DYING:
			_anim_sprite.play("death")

func _on_attack_started(_target: Node2D) -> void:
	if _anim_sprite == null or is_dying():
		return
	_anim_sprite.play("attack")

func _on_anim_finished() -> void:
	if _anim_sprite == null or is_dying():
		return
	if _anim_sprite.animation == &"attack":
		_update_animation()

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
	draw_arc(Vector2.ZERO, SELECTION_RADIUS, 0.0, TAU, SELECTION_SEGMENTS, _selection_color, SELECTION_WIDTH, true)
