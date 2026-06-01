extends Node2D

const CLICK_DISTANCE_THRESHOLD: float = 4.0
const UNIT_LAYER_MASK: int = 1
const RESOURCE_LAYER_MASK: int = 2
const BUILDING_LAYER_MASK: int = 4

var drag_start_world: Vector2 = Vector2.ZERO
var dragging_box: bool = false

func _unhandled_input(event: InputEvent) -> void:
	if BuildingPlacer.is_placing():
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_handle_left(mb)
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			_handle_right()
	elif event is InputEventMouseMotion and dragging_box:
		queue_redraw()

func _handle_left(mb: InputEventMouseButton) -> void:
	var world_pos: Vector2 = get_global_mouse_position()
	if mb.pressed:
		var unit := _unit_at(world_pos)
		if unit != null:
			if Input.is_key_pressed(KEY_SHIFT):
				SelectionManager.toggle_unit(unit)
			else:
				SelectionManager.select_only(unit)
				SelectionManager.deselect_building()
			dragging_box = false
			get_viewport().set_input_as_handled()
			return
		var building := _building_at(world_pos)
		if building != null:
			SelectionManager.clear()
			SelectionManager.select_building(building)
			dragging_box = false
			get_viewport().set_input_as_handled()
			return
		drag_start_world = world_pos
		dragging_box = true
		queue_redraw()
		get_viewport().set_input_as_handled()
	else:
		if dragging_box:
			var drag_distance: float = world_pos.distance_to(drag_start_world)
			if drag_distance < CLICK_DISTANCE_THRESHOLD:
				SelectionManager.clear()
				SelectionManager.deselect_building()
			else:
				var rect := _rect_from(drag_start_world, world_pos)
				var found := _units_in_rect(rect)
				if found.size() > 0:
					SelectionManager.select_multiple(found)
					SelectionManager.deselect_building()
				else:
					SelectionManager.clear()
					SelectionManager.deselect_building()
			dragging_box = false
			queue_redraw()
			get_viewport().set_input_as_handled()

func _handle_right() -> void:
	var world_pos: Vector2 = get_global_mouse_position()
	var resource := _resource_at(world_pos)
	if resource != null:
		SelectionManager.harvest_with_selected(resource)
	else:
		var attack_move: bool = Input.is_action_pressed("attack_move")
		SelectionManager.move_selected_to(world_pos, attack_move)
	get_viewport().set_input_as_handled()

func _unit_at(world_pos: Vector2) -> Node:
	return _node_at(world_pos, UNIT_LAYER_MASK, "player_units")

func _resource_at(world_pos: Vector2) -> Node:
	return _node_at(world_pos, RESOURCE_LAYER_MASK, "resources")

func _building_at(world_pos: Vector2) -> Node:
	return _node_at(world_pos, BUILDING_LAYER_MASK, "buildings")

func _node_at(world_pos: Vector2, mask: int, group: String) -> Node:
	var space := get_world_2d().direct_space_state
	var params := PhysicsPointQueryParameters2D.new()
	params.position = world_pos
	params.collide_with_areas = true
	params.collide_with_bodies = false
	params.collision_mask = mask
	var hits := space.intersect_point(params, 8)
	for hit in hits:
		var collider = hit.get("collider")
		if collider == null:
			continue
		var p = collider.get_parent()
		if p != null and p.is_in_group(group):
			return p
	return null

func _units_in_rect(rect: Rect2) -> Array:
	var result: Array = []
	for u in get_tree().get_nodes_in_group("player_units"):
		var node2d := u as Node2D
		if node2d != null and rect.has_point(node2d.global_position):
			result.append(u)
	return result

func _rect_from(a: Vector2, b: Vector2) -> Rect2:
	var top_left := Vector2(min(a.x, b.x), min(a.y, b.y))
	var size: Vector2 = (b - a).abs()
	return Rect2(top_left, size)

func _draw() -> void:
	if not dragging_box:
		return
	var current: Vector2 = get_global_mouse_position()
	var rect := _rect_from(to_local(drag_start_world), to_local(current))
	draw_rect(rect, Color(0.5, 0.8, 1.0, 0.15), true)
	draw_rect(rect, Color(0.8, 0.95, 1.0, 0.9), false, 2.0)
