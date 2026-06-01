class_name Villager
extends CharacterBody2D

signal unit_died(unit: CharacterBody2D)

enum State { IDLE, MOVING, HARVESTING }

const SELECTION_RADIUS: float = 22.0
const SELECTION_COLOR: Color = Color(0.27, 0.86, 0.50, 1.0)
const SELECTION_WIDTH: float = 3.0
const SELECTION_SEGMENTS: int = 32

@export var speed: float  = 120.0
@export var faction:         String   = "player"
@export var sprite_asset:    String   = "villager"

@onready var _nav_agent:          NavigationAgent2D = $NavigationAgent2D
@onready var _harvest_component:  HarvestComponent  = $HarvestComponent

var _state:    State  = State.IDLE
var _home:     Node2D = null
var selected:  bool   = false

func _ready() -> void:
	add_to_group("villagers")
	if faction == "player":
		add_to_group("player_units")
	_home = _find_home()
	_harvest_component.setup(_nav_agent, _home, faction)
	_nav_agent.velocity_computed.connect(_on_velocity_computed)
	_apply_sprite(sprite_asset)

func _find_home() -> Node2D:
	var town_centers: Array = get_tree().get_nodes_in_group("town_center")
	for tc in town_centers:
		if is_instance_valid(tc) and tc.get("faction") == faction:
			return tc as Node2D
	if not town_centers.is_empty():
		return town_centers[0] as Node2D
	return null

func set_selected(value: bool) -> void:
	if selected == value:
		return
	selected = value
	queue_redraw()

func is_harvesting() -> bool:
	return _harvest_component.is_active()

func _physics_process(delta: float) -> void:
	match _state:
		State.IDLE:
			pass
		State.MOVING:
			_process_moving()
		State.HARVESTING:
			_harvest_component.tick(delta, global_position)
			_process_moving()
			if not _harvest_component.is_active():
				_state = State.IDLE

func _process_moving() -> void:
	if _nav_agent.is_navigation_finished():
		if _state == State.MOVING:
			_state = State.IDLE
		_nav_agent.set_velocity(Vector2.ZERO)
		return
	var next: Vector2 = _nav_agent.get_next_path_position()
	var dir:  Vector2 = (next - global_position).normalized()
	_nav_agent.set_velocity(dir * speed)

func _on_velocity_computed(safe_velocity: Vector2) -> void:
	velocity = safe_velocity
	move_and_slide()

func assign_harvest(node: ResourceNode) -> void:
	_harvest_component.assign_node(node)
	_state = State.HARVESTING

func harvest(node) -> void:
	if node is ResourceNode:
		assign_harvest(node)

func move_to(target: Vector2) -> void:
	_harvest_component.stop()
	_nav_agent.target_position = target
	_state = State.MOVING

func die() -> void:
	unit_died.emit(self)
	queue_free()

func _draw() -> void:
	if not selected:
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
