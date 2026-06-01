extends CharacterBody2D

enum State { IDLE, MOVING, ATTACKING, DYING, HOLDING, PATROLLING }

const DEATH_FADE_TIME: float = 0.5
const SELECTION_RADIUS: float = 22.0
const SELECTION_COLOR: Color = Color(0.27, 0.86, 0.50, 1.0)
const SELECTION_WIDTH: float = 3.0
const SELECTION_SEGMENTS: int = 32

@export var faction: String = "player"
@export var sprite_asset: String = "soldier"
@export var max_hp: int = 120

@onready var hp_bar_fg: ColorRect = $HPBarFG
@onready var detection_area: Area2D = $DetectionArea
@onready var hitbox: Area2D = $Hitbox

var state: int = State.IDLE
var selected: bool = false
var death_timer: float = 0.0
var hp_bar_width: float = 32.0
var _movement_component: MovementComponent = null
var _stat: StatComponent = null

func _ready() -> void:
	add_to_group("soldiers")
	add_to_group("combat_units")
	if faction == "player":
		add_to_group("player_units")
	if hp_bar_fg != null:
		hp_bar_width = hp_bar_fg.offset_right - hp_bar_fg.offset_left
	_apply_sprite(sprite_asset)
	add_to_group("friendly_units")
	_movement_component = get_node_or_null("MovementComponent") as MovementComponent
	_stat = get_node_or_null("StatComponent") as StatComponent
	if _stat != null:
		_stat.died.connect(_on_died)
		_stat.health_changed.connect(_on_health_changed)
	_update_hp_bar()

func _on_died(_owner_unit: CharacterBody2D = null) -> void:
	if SelectionManager.has_method("deselect_unit"):
		SelectionManager.deselect_unit(self)
	set_physics_process(false)
	call_deferred("queue_free")

func _on_health_changed(_current: float, _maximum: float) -> void:
	_update_hp_bar()

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
	if _stat != null:
		return _stat.is_dead()
	return state == State.DYING

func set_selected(value: bool) -> void:
	if selected == value:
		return
	selected = value
	queue_redraw()

func move_to(target: Vector2) -> void:
	if state == State.DYING:
		return
	if state == State.HOLDING:
		_set_combat_enabled(true)
	state = State.MOVING
	if _movement_component != null:
		_movement_component.move_to(target)

func attack_move(target: Vector2) -> void:
	if state == State.DYING:
		return
	if state == State.HOLDING:
		_set_combat_enabled(true)
	state = State.MOVING
	if _movement_component != null:
		_movement_component.move_to(target)

func stop() -> void:
	if state == State.DYING:
		return
	if _movement_component != null:
		_movement_component.stop()
	_set_combat_enabled(true)
	state = State.IDLE

func hold() -> void:
	if state == State.DYING:
		return
	if _movement_component != null:
		_movement_component.stop()
	_set_combat_enabled(false)
	state = State.HOLDING

func patrol(target: Vector2) -> void:
	if state == State.DYING:
		return
	move_to(target)

func _set_combat_enabled(enabled: bool) -> void:
	var combat := get_node_or_null("CombatComponent")
	if combat == null:
		return
	combat.set_physics_process(enabled)
	if not enabled and combat.has_method("clear_target"):
		combat.clear_target()

func take_damage(amount: int) -> void:
	if _stat != null:
		_stat.take_damage(float(amount))

func _physics_process(delta: float) -> void:
	if state == State.DYING:
		_process_dying(delta)
		return
	match state:
		State.IDLE:
			pass
		State.MOVING:
			_move_step(delta)
		State.ATTACKING:
			pass  # CombatComponent owns attack logic
		State.HOLDING:
			pass  # hold ground; CombatComponent disabled in hold()
		State.PATROLLING:
			_move_step(delta)

func _move_step(_delta: float) -> void:
	if _movement_component == null or not _movement_component.is_moving():
		state = State.IDLE

func _update_hp_bar() -> void:
	if hp_bar_fg == null or _stat == null:
		return
	var ratio: float = _stat.get_health_ratio()
	hp_bar_fg.offset_right = hp_bar_fg.offset_left + hp_bar_width * ratio

func _enter_dying() -> void:
	state = State.DYING
	death_timer = 0.0
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
