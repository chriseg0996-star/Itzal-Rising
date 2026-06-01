extends Node2D

const MOVE_SPEED: float = 150.0
const SELECTION_RADIUS: float = 22.0
const SELECTION_COLOR: Color = Color(0.27, 0.86, 0.50, 1.0)
const SELECTION_WIDTH: float = 3.0
const SELECTION_SEGMENTS: int = 32

const HARVEST_INTERVAL: float = 1.5
const HARVEST_RANGE: float = 40.0

@export var faction: String = "player"
@export var sprite_asset: String = "villager"

@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D

var selected: bool = false
var current_resource: Node = null
var harvest_timer: float = 0.0

func _ready() -> void:
	add_to_group("villagers")
	if faction == "player":
		add_to_group("player_units")
	_apply_sprite(sprite_asset)

func set_selected(value: bool) -> void:
	if selected == value:
		return
	selected = value
	queue_redraw()

func move_to(target: Vector2) -> void:
	current_resource = null
	harvest_timer = 0.0
	nav_agent.target_position = target

func harvest(resource: Node) -> void:
	current_resource = resource
	harvest_timer = 0.0
	nav_agent.target_position = resource.global_position

func _draw() -> void:
	if not selected:
		return
	draw_arc(Vector2.ZERO, SELECTION_RADIUS, 0.0, TAU, SELECTION_SEGMENTS, SELECTION_COLOR, SELECTION_WIDTH, true)

func _physics_process(delta: float) -> void:
	if current_resource != null and not is_instance_valid(current_resource):
		current_resource = null
		harvest_timer = 0.0

	if current_resource != null:
		var to_res: float = global_position.distance_to(current_resource.global_position)
		if to_res <= HARVEST_RANGE:
			harvest_timer += delta
			if harvest_timer >= HARVEST_INTERVAL:
				harvest_timer -= HARVEST_INTERVAL
				_do_harvest()
			return

	if nav_agent.is_navigation_finished():
		return
	var next_pos: Vector2 = nav_agent.get_next_path_position()
	var to_next: Vector2 = next_pos - global_position
	var dist: float = to_next.length()
	if dist < 0.5:
		return
	var step: Vector2 = to_next / dist * MOVE_SPEED * delta
	if step.length() > dist:
		step = to_next
	global_position += step

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

func _do_harvest() -> void:
	if current_resource == null or not is_instance_valid(current_resource):
		current_resource = null
		harvest_timer = 0.0
		return
	current_resource.harvest(faction)
	if not is_instance_valid(current_resource):
		current_resource = null
		harvest_timer = 0.0
