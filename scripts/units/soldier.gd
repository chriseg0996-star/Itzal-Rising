extends CharacterBody2D

enum State { IDLE, MOVING, ATTACKING, DYING, HOLDING, PATROLLING }

const DEATH_FADE_TIME: float = 0.5
const SELECTION_RADIUS: float = 22.0
const SELECTION_COLOR: Color = Color(0.27, 0.86, 0.50, 1.0)
const SELECTION_WIDTH: float = 3.0
const SELECTION_SEGMENTS: int = 32

var _selection_color: Color = SELECTION_COLOR

@export var faction_id: int = 0
@export var sprite_asset: String = "soldier"
@export var max_hp: int = 120
@export var sound_select: AudioStream
@export var sound_attack: AudioStream

@onready var hp_bar_fg: ColorRect = $HPBarFG
@onready var detection_area: Area2D = $DetectionArea
@onready var hitbox: Area2D = $Hitbox
@onready var _anim_sprite: AnimatedSprite2D = $AnimatedSprite2D

var state: int = State.IDLE:
	set(value):
		var changed: bool = state != value
		state = value
		if changed:
			_update_animation()
var selected: bool = false
var death_timer: float = 0.0
var hp_bar_width: float = 32.0
var _movement_component: MovementComponent = null
var _stat: StatComponent = null
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
	if hp_bar_fg != null:
		hp_bar_width = hp_bar_fg.offset_right - hp_bar_fg.offset_left
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
	var _sfx := AudioStreamPlayer.new()
	_sfx.name = "SFX"
	add_child(_sfx)
	var combat := get_node_or_null("CombatComponent") as CombatComponent
	if combat != null:
		combat.attack_landed.connect(_on_attack_landed)
		combat.attack_started.connect(_on_attack_started)
	if _anim_sprite != null:
		_anim_sprite.animation_finished.connect(_on_anim_finished)
	_update_hp_bar()
	_update_animation()

func _on_died(_owner_unit: CharacterBody2D = null) -> void:
	state = State.DYING
	SoundManager.play("unit_death", -3.0)
	Particles.spawn(get_parent(), "death_burst", global_position)
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

func _on_attack_landed(target: Node2D, _damage: float) -> void:
	_play_sound(sound_attack)
	SoundManager.play("unit_attack", -4.0)
	Particles.spawn(get_parent(), "attack_impact", target.global_position)

func _play_sound(stream: AudioStream) -> void:
	if stream == null:
		return
	var sfx := get_node_or_null("SFX") as AudioStreamPlayer
	if sfx == null:
		return
	sfx.stream = stream
	sfx.play()

func is_dying() -> bool:
	if _stat != null:
		return _stat.is_dead()
	return state == State.DYING

func set_selected(value: bool) -> void:
	if selected == value:
		return
	selected = value
	queue_redraw()
	if value:
		_play_sound(sound_select)

func move_to(target: Vector2) -> void:
	if state == State.DYING:
		return
	# Plain move = disengage: suspend auto-combat so the order is obeyed and the
	# unit can retreat instead of being dragged back by target re-acquisition.
	# Combat resumes on arrival (_move_step) or via Stop/attack-move.
	_set_combat_enabled(false)
	state = State.MOVING
	if _movement_component != null:
		_movement_component.move_to(target)

func attack_move(target: Vector2) -> void:
	if state == State.DYING:
		return
	# Attack-move keeps auto-combat on so the unit engages anything en route.
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
	attack_move(target)

func set_stance(s: int) -> void:
	var combat := get_node_or_null("CombatComponent") as CombatComponent
	if combat != null:
		combat.set_stance(s)

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
		# Arrived: resume auto-defense (a plain move had suspended it).
		_set_combat_enabled(true)

func _update_hp_bar() -> void:
	if hp_bar_fg == null or _stat == null:
		return
	var ratio: float = _stat.get_health_ratio()
	hp_bar_fg.offset_right = hp_bar_fg.offset_left + hp_bar_width * ratio

func _update_animation() -> void:
	if _anim_sprite == null:
		return
	match state:
		State.IDLE, State.HOLDING:
			_anim_sprite.play("idle")
		State.MOVING, State.PATROLLING:
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
	draw_arc(Vector2.ZERO, SELECTION_RADIUS, 0.0, TAU, SELECTION_SEGMENTS, _selection_color, SELECTION_WIDTH, true)
