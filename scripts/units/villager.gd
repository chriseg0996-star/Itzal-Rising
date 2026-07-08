class_name Villager
extends CharacterBody2D

signal unit_died(unit: CharacterBody2D)

enum State { IDLE, MOVING, HARVESTING, BUILDING, WORKING_FARM, DYING }

const BUILD_RANGE: float = 64.0
const FARM_RANGE: float = 56.0

# Painted animation sheet (Meshy/gen → sliced by tools/integrate_villager_anim.py).
# When present, replaces the pixel SpriteFrames at runtime. Delete the PNG to
# revert. Cells are CELL px, feet-aligned at the cell bottom; rows below.
const ANIM_SHEET: String = "res://assets/units/villager_sheet.png"
const ANIM_CELL: int = 96
const ANIM_SCALE: float = 0.58
# [anim name, row, frame count, loop, fps]
const ANIM_ROWS: Array = [
	["idle", 0, 7, true, 6.0],
	["walk", 1, 8, true, 10.0],
	["harvest", 2, 8, true, 9.0],
	["build", 3, 7, true, 9.0],
	["death", 4, 7, false, 8.0],
]

const DEATH_FADE_TIME: float = 0.5
const SELECTION_RADIUS: float = 22.0
const SELECTION_COLOR: Color = Color(0.27, 0.86, 0.50, 1.0)
const SELECTION_WIDTH: float = 3.0
const SELECTION_SEGMENTS: int = 32

var _selection_color: Color = SELECTION_COLOR

@export var speed: float  = 120.0
@export var faction_id:      int      = 0
@export var sprite_asset:    String   = "villager"
@export var sound_select: AudioStream
@export var sound_harvest: AudioStream

@onready var _nav_agent:          NavigationAgent2D = $NavigationAgent2D
@onready var _harvest_component:  HarvestComponent  = $HarvestComponent

## HUD hook: what this worker is gathering right now ("" = idle).
func current_resource_type() -> StringName:
	return _harvest_component.current_type() if _harvest_component != null else &""
@onready var _hitbox:             Area2D            = $Area2D
@onready var _hp_bar_fg:          ColorRect         = $HPBarFG
@onready var _anim_sprite:        AnimatedSprite2D  = $AnimatedSprite2D

var _state:        State  = State.IDLE:
	set(value):
		var changed: bool = _state != value
		_state = value
		if changed:
			_update_animation()
var _home:         Node2D = null
var _build_target: Node   = null  ## construction site this villager is raising
var _farm_target:  Node   = null  ## farm this villager is working
var selected:      bool   = false
var _stat:         StatComponent = null
var _death_timer:  float  = 0.0
var _hp_bar_width: float  = 32.0
var _base_modulate: Color = Color(1, 1, 1, 1)

func _ready() -> void:
	TextureGenerator.attach_shadow(self, 22.0, 9.0, 7.0, 0.32)
	add_to_group("villagers")
	add_to_group("combat_units")
	var fac: FactionData = FactionManager.get_faction(faction_id)
	if fac != null:
		_selection_color = fac.primary_color
	if FactionManager.is_player_faction(faction_id):
		add_to_group("player_units")
	_stat = get_node_or_null("StatComponent") as StatComponent
	if _stat != null:
		_stat.died.connect(_on_died)
		_stat.health_changed.connect(_on_health_changed)
	if _hp_bar_fg != null:
		_hp_bar_width = _hp_bar_fg.offset_right - _hp_bar_fg.offset_left
	UnitHpBar.enhance(self)
	_update_hp_bar()
	_home = _find_home()
	_harvest_component.setup(_nav_agent, _home, faction_id)
	_harvest_component.deposit_made.connect(_on_deposit_made)
	var old_sprite := get_node_or_null("Sprite")
	if old_sprite != null and old_sprite is CanvasItem:
		(old_sprite as CanvasItem).visible = false
	_try_painted_anim()
	_base_modulate = modulate
	var _sfx := AudioStreamPlayer.new()
	_sfx.name = "SFX"
	add_child(_sfx)
	_update_animation()

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

func set_selected(value: bool) -> void:
	if selected == value:
		return
	selected = value
	queue_redraw()
	if value:
		_play_sound(sound_select)

func is_harvesting() -> bool:
	return _harvest_component.is_active()

func take_damage(amount: int) -> void:
	if _stat != null:
		_stat.take_damage(float(amount))

func _on_health_changed(_current: float, _maximum: float) -> void:
	_update_hp_bar()
	_flash_hit()

func _on_died(_owner_unit: CharacterBody2D = null) -> void:
	Particles.spawn(get_parent(), "death_burst", global_position)
	_enter_dying()

func _on_deposit_made(_type: StringName, _amount: int) -> void:
	SoundManager.play("resource_gather", -6.0)
	Particles.spawn(get_parent(), "resource_gather", global_position)

func _flash_hit() -> void:
	if _state == State.DYING:
		return
	modulate = Color(2.0, 2.0, 2.0, _base_modulate.a)
	var tween := create_tween()
	tween.tween_property(self, "modulate", _base_modulate, 0.1)

func _play_sound(stream: AudioStream) -> void:
	if stream == null:
		return
	var sfx := get_node_or_null("SFX") as AudioStreamPlayer
	if sfx == null:
		return
	sfx.stream = stream
	sfx.play()

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
		State.BUILDING:
			_anim_sprite.play(_anim("build"))
		State.HARVESTING, State.WORKING_FARM:
			_anim_sprite.play("harvest")
		State.DYING:
			_anim_sprite.play("death")

## Use a dedicated animation when the painted sheet provides it, else fall back.
func _anim(name: String) -> String:
	var sf: SpriteFrames = _anim_sprite.sprite_frames
	return name if sf != null and sf.has_animation(name) else "harvest"

## A/B: build a SpriteFrames from the painted sheet and swap it onto the pixel
## AnimatedSprite2D. Kept behind the PNG's existence so deleting it reverts.
func _try_painted_anim() -> void:
	if not ResourceLoader.exists(ANIM_SHEET):
		return
	var tex: Texture2D = load(ANIM_SHEET)
	if tex == null:
		return
	var sf := SpriteFrames.new()
	if sf.has_animation("default"):
		sf.remove_animation("default")
	for spec in ANIM_ROWS:
		var aname: String = spec[0]
		sf.add_animation(aname)
		sf.set_animation_loop(aname, bool(spec[3]))
		sf.set_animation_speed(aname, float(spec[4]))
		for f in int(spec[2]):
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2(f * ANIM_CELL, int(spec[1]) * ANIM_CELL, ANIM_CELL, ANIM_CELL)
			sf.add_frame(aname, at)
	_anim_sprite.sprite_frames = sf
	_anim_sprite.centered = true
	_anim_sprite.offset = Vector2(0, -ANIM_CELL * 0.5)   # feet (cell bottom) at origin
	_anim_sprite.scale = Vector2(ANIM_SCALE, ANIM_SCALE)
	# Lift the HP bar clear of the taller painted body (deferred: HPBarFrame is
	# added deferred by UnitHpBar.enhance).
	call_deferred("_raise_hp_bar", ANIM_CELL * ANIM_SCALE - 24.0)

func _raise_hp_bar(amount: float) -> void:
	for n in ["HPBarBG", "HPBarFG", "HPBarFrame"]:
		var bar := get_node_or_null(n) as Control
		if bar != null:
			bar.offset_top -= amount
			bar.offset_bottom -= amount

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
		State.BUILDING:
			_tick_building(delta)
		State.WORKING_FARM:
			_tick_farm(delta)
	# Builders/farmers stay parked on their site; separation would jostle them
	# out of range and stall the work.
	if _state != State.BUILDING and _state != State.WORKING_FARM:
		_apply_separation(delta)

## Keeps villagers from stacking, in every non-dying state (shared steering).
func _apply_separation(delta: float) -> void:
	var push: Vector2 = UnitSeparation.push(self)
	if push.length() <= 2.0:
		return
	global_position += push * delta
	global_position = global_position.clamp(Vector2(4.0, 4.0), Vector2(MapConfig.WORLD_SIZE - 4.0, MapConfig.WORLD_SIZE - 4.0))

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
	var b: Rect2 = Rect2(4.0, 4.0, MapConfig.WORLD_SIZE - 8.0, MapConfig.WORLD_SIZE - 8.0)
	global_position = global_position.clamp(b.position, b.end)

func assign_harvest(node: ResourceNode) -> void:
	_harvest_component.assign_node(node)
	_state = State.HARVESTING
	_play_sound(sound_harvest)

func harvest(node) -> void:
	if node is ResourceNode:
		assign_harvest(node)

## Walk to a construction site and raise it; if it's a farm, stay to work it.
func build_structure(site: Node) -> void:
	if _state == State.DYING or site == null or not is_instance_valid(site):
		return
	_harvest_component.stop()
	_farm_target = null
	_build_target = site
	if site is Node2D:
		_nav_agent.target_position = (site as Node2D).global_position
	_state = State.BUILDING
	_play_sound(sound_harvest)

## Walk to a completed farm and work it (keeps its food income flowing).
func work_farm(farm: Node) -> void:
	if _state == State.DYING or farm == null or not is_instance_valid(farm):
		return
	_harvest_component.stop()
	_build_target = null
	_farm_target = farm
	if farm is Node2D:
		_nav_agent.target_position = (farm as Node2D).global_position
	_state = State.WORKING_FARM
	_play_sound(sound_harvest)

func is_busy() -> bool:
	return _harvest_component.is_active() or _build_target != null or _farm_target != null

func _tick_building(delta: float) -> void:
	if _build_target == null or not is_instance_valid(_build_target):
		_build_target = null
		_state = State.IDLE
		return
	if _build_target.has_method("is_complete") and _build_target.is_complete():
		var done: Node = _build_target
		_build_target = null
		var fps: Variant = done.get("food_per_sec")
		if fps != null and float(fps) > 0.0:
			work_farm(done)  # finished a farm — stay and work it
		else:
			_state = State.IDLE
		return
	if global_position.distance_to((_build_target as Node2D).global_position) <= BUILD_RANGE:
		_build_target.contribute_build(delta)
	else:
		_process_moving(delta)

func _tick_farm(delta: float) -> void:
	if _farm_target == null or not is_instance_valid(_farm_target):
		_farm_target = null
		_state = State.IDLE
		return
	if global_position.distance_to((_farm_target as Node2D).global_position) <= FARM_RANGE:
		_farm_target.report_worker()
	else:
		_process_moving(delta)

func move_to(target: Vector2) -> void:
	if _state == State.DYING:
		return
	_harvest_component.stop()
	_build_target = null
	_farm_target = null
	_nav_agent.target_position = target
	_state = State.MOVING

func stop() -> void:
	_harvest_component.stop()
	_build_target = null
	_farm_target = null
	_nav_agent.target_position = global_position
	_state = State.IDLE

func hold() -> void:
	stop()

func patrol(target: Vector2) -> void:
	move_to(target)

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
	draw_arc(Vector2.ZERO, SELECTION_RADIUS, 0.0, TAU, SELECTION_SEGMENTS, _selection_color, SELECTION_WIDTH, true)
