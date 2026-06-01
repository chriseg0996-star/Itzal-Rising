extends Control

const MAP_SIZE: float = 2048.0
const MINIMAP_SIZE: float = 150.0
const SCALE: float = MINIMAP_SIZE / MAP_SIZE

const PLAYER_COLOR: Color = Color(0.27, 0.86, 0.50, 1.0)
const ENEMY_COLOR: Color = Color(0.85, 0.22, 0.22, 1.0)
const UNIT_DOT_RADIUS: float = 2.5
const BUILDING_DOT_RADIUS: float = 4.0

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(0, 0, MINIMAP_SIZE, MINIMAP_SIZE), Color(0, 0, 0, 0.7), true)
	draw_rect(Rect2(0, 0, MINIMAP_SIZE, MINIMAP_SIZE), Color(0.5, 0.5, 0.55, 1.0), false, 2.0)

	for u in get_tree().get_nodes_in_group("player_units"):
		if not is_instance_valid(u):
			continue
		_dot((u as Node2D).global_position, PLAYER_COLOR, UNIT_DOT_RADIUS)

	for b in get_tree().get_nodes_in_group("player_buildings"):
		if not is_instance_valid(b):
			continue
		_dot((b as Node2D).global_position, PLAYER_COLOR, BUILDING_DOT_RADIUS)

	for b in get_tree().get_nodes_in_group("enemy_buildings"):
		if not is_instance_valid(b):
			continue
		_dot((b as Node2D).global_position, ENEMY_COLOR, BUILDING_DOT_RADIUS)

	for u in get_tree().get_nodes_in_group("combat_units"):
		if not is_instance_valid(u):
			continue
		if u.get("faction") == "enemy":
			_dot((u as Node2D).global_position, ENEMY_COLOR, UNIT_DOT_RADIUS)

	for v in get_tree().get_nodes_in_group("villagers"):
		if not is_instance_valid(v):
			continue
		if v.get("faction") == "enemy":
			_dot((v as Node2D).global_position, ENEMY_COLOR, UNIT_DOT_RADIUS)

func _dot(world_pos: Vector2, color: Color, radius: float) -> void:
	var p: Vector2 = world_pos * SCALE
	if p.x < 0.0 or p.x > MINIMAP_SIZE or p.y < 0.0 or p.y > MINIMAP_SIZE:
		return
	draw_circle(p, radius, color)
