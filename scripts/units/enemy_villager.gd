class_name EnemyVillager
extends CharacterBody2D

signal unit_died(unit: CharacterBody2D)

enum State { IDLE, MOVING, HARVESTING, DYING }

const DEATH_FADE_TIME: float = 0.5
const SELECTION_RADIUS: float = 22.0
const SELECTION_COLOR: Color = Color(0.27, 0.86, 0.50, 1.0)
const SELECTION_WIDTH: float = 3.0
const SELECTION_SEGMENTS: int = 32

@export var speed:        float  = 100.0
@export var map_bounds:   Rect2  = Rect2(4.0, 4.0, 2040.0, 2040.0)
@export var faction_id:   int    = 1
@export var sprite_asset: String = "enemy_villager"

@onready var _nav_agent:         NavigationAgent2D = $NavigationAgent2D
@onready var _harvest_component: HarvestComponent  = $HarvestComponent
@onready var _hitbox:            Area2D            = $Area2D
@onready var _hp_bar_fg:         ColorRect         = $HPBarFG
@onready var _anim_sprite:       AnimatedSprite2D  = $AnimatedSprite2D

var _stat:         StatComponent = null
var selected:      bool   = false
var _state:        State  = State.IDLE:
	set(value):
		var changed: bool = _state != value
		_state = value
		if changed:
			_update_animation()
var _home:         Node2D = null
var _death_timer:  float  = 0.0
var _hp_bar_width: float  = 32.0
var _base_modulate: Color = Color(1, 1, 1, 1)

func _ready() -> void:
	add_to_group("villagers")
	add_to_group("combat_units")
	if FactionManager.is_player_faction(faction_id):
		add_to_group("player_units")
	_stat = get_node_or_null("StatComponent") as StatComponent
	if _stat != null:
		_stat.died.connect(_on_died)
		_stat.health_changed.connect(_on_health_changed)
	if _hp_bar_fg != null:
		_hp_bar_width = _hp_bar_fg.offset_right - _hp_bar_fg.offset_left
	_update_hp_bar()
	_home = _find_home()
	var old_sprite := get_node_or_null("Sprite")
	if old_sprite != null and old_sprite is CanvasItem:
		(old_sprite as CanvasItem).visible = false
	_base_modulate = modulate
	_update_animation()
	await get_tree().physics_frame
	_harvest_component.setup(_nav_agent, _home, faction_id)

func _find_home() -> Node2D:
	var town_centers: Array = get_tree().get_nodes_in_group("town_center")
	for tc in town_centers:
		if is_instance_valid(tc) and tc.get("faction_id") == faction_id:
			return tc as Node2D
	if not town_centers.is_empty():
		return town_centers[0] as Node2D
	return null

func is_dying() -> bool:
	return _state == State.DYING

func is_harvesting() -> bool:
	return _harvest_component.is_active()

func set_selected(value: bool) -> void:
	if selected == value:
		return
	selected = value
	queue_redraw()

func take_damage(amount: int) -> void:
	if _stat != null:
		_stat.take_damage(float(amount))

func _on_health_changed(_current: float, _maximum: float) -> void:
	_update_hp_bar()
	_flash_hit()

func _on_died(_owner_unit: CharacterBody2D = null) -> void:
	_enter_dying()

func _flash_hit() -> void:
	if _state == State.DYING:
		return
	modulate = Color(2.0, 2.0, 2.0, _base_modulate.a)
	var tween := create_tween()
	tween.tween_property(self, "modulate", _base_modulate, 0.1)

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
		State.HARVESTING:
			_anim_sprite.play("harvest")
		State.DYING:
			_anim_sprite.play("death")

func _physics_process(delta: float) -> void:
	if _state == State.DYING:
		_process_dying(delta)
		return
	match _state:
		State.IDLE:
			pass
		State.MOVING:
			_process_moving(delta)
		State.HARVESTING:
			_harvest_component.tick(delta, global_position)
			_process_moving(delta)
			if not _harvest_component.is_active():
				_state = State.IDLE

func _process_moving(delta: float) -> void:
	if _nav_agent.is_navigation_finished():
		if _state == State.MOVING:
			_state = State.IDLE
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

func assign_harvest(node: ResourceNode) -> void:
	_harvest_component.assign_node(node)
	_state = State.HARVESTING

func harvest(node) -> void:
	if node is ResourceNode:
		assign_harvest(node)

func move_to(target: Vector2) -> void:
	if _state == State.DYING:
		return
	_harvest_component.stop()
	_nav_agent.target_position = target
	_state = State.MOVING

func _enter_dying() -> void:
	_state = State.DYING
	_death_timer = 0.0
	_harvest_component.stop()
	if _hitbox != null:
		_hitbox.monitorable = false
		_hitbox.monitoring = false
	set_physics_process(false)
	set_process(false)
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.4)
	tween.tween_callback(die)

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
