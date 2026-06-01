extends Node

signal building_selected(building: Node)
signal building_deselected
signal move_commanded(target: Vector2, units: Array)

const FORMATION_SPACING: float = 40.0
const LINE_SPACING: float = 48.0
const NAV_THROTTLE: float = 0.2

var selected: Array = []
var selected_building: Node = null
var _throttle: Dictionary = {}

func select_only(unit: Node) -> void:
	clear()
	_add(unit)

func select_multiple(units: Array) -> void:
	clear()
	for u in units:
		_add(u)

func toggle_unit(unit: Node) -> void:
	if unit == null or not is_instance_valid(unit):
		return
	if unit in selected:
		selected.erase(unit)
		unit.set_selected(false)
	else:
		_add(unit)

func clear() -> void:
	for u in selected:
		if is_instance_valid(u):
			u.set_selected(false)
	selected.clear()

func select_building(b: Node) -> void:
	if b == null or not is_instance_valid(b):
		return
	if b == selected_building:
		return
	selected_building = b
	building_selected.emit(b)

func deselect_building() -> void:
	if selected_building == null:
		return
	selected_building = null
	building_deselected.emit()

func move_selected_to(target: Vector2, attack_move: bool = false) -> void:
	if selected.is_empty():
		return
	var n: int = selected.size()
	var cols: int = int(ceil(sqrt(float(n))))
	var rows: int = int(ceil(float(n) / float(cols)))
	for i in range(n):
		var u = selected[i]
		if not is_instance_valid(u):
			continue
		@warning_ignore("integer_division")
		var row: int = i / cols
		var units_in_row: int
		if row < rows - 1:
			units_in_row = cols
		else:
			units_in_row = n - row * cols
		var col_in_row: int = i % cols
		var x_offset: float = (float(col_in_row) - float(units_in_row - 1) * 0.5) * FORMATION_SPACING
		var y_offset: float = (float(row) - float(rows - 1) * 0.5) * FORMATION_SPACING
		var dest: Vector2 = target + Vector2(x_offset, y_offset)
		if attack_move and u.has_method("attack_move"):
			u.attack_move(dest)
		elif u.has_method("move_to"):
			u.move_to(dest)

func harvest_with_selected(resource: Node) -> void:
	if selected.is_empty():
		return
	if resource == null or not is_instance_valid(resource):
		return
	for u in selected:
		if is_instance_valid(u) and u.has_method("harvest"):
			u.harvest(resource)

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_RIGHT or not mb.pressed:
		return
	var world_pos: Vector2 = _screen_to_world(mb.position)
	_command_move(world_pos)
	get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if _throttle.is_empty():
		return
	var expired: Array = []
	for id in _throttle:
		_throttle[id] = float(_throttle[id]) - delta
		if float(_throttle[id]) <= 0.0:
			expired.append(id)
	for id in expired:
		_throttle.erase(id)

func _command_move(world_pos: Vector2) -> void:
	if selected.is_empty():
		return
	var n: int = selected.size()
	var dispatched: Array = []
	for i in range(n):
		var u = selected[i]
		if not is_instance_valid(u):
			continue
		if not u.has_method("move_to"):
			continue
		if _is_throttled(u):
			continue
		var offset_x: float = (float(i) - float(n - 1) * 0.5) * LINE_SPACING
		var target: Vector2 = world_pos + Vector2(offset_x, 0.0)
		u.move_to(target)
		_stamp_throttle(u)
		dispatched.append(u)
	if not dispatched.is_empty():
		move_commanded.emit(world_pos, dispatched)

func _screen_to_world(screen_pos: Vector2) -> Vector2:
	var vp: Viewport = get_viewport()
	if vp == null:
		return screen_pos
	var camera: Camera2D = vp.get_camera_2d()
	if camera == null:
		return screen_pos
	var canvas_xform: Transform2D = vp.get_canvas_transform()
	return canvas_xform.affine_inverse() * screen_pos

func _is_throttled(unit: Node) -> bool:
	return _throttle.has(unit.get_instance_id())

func _stamp_throttle(unit: Node) -> void:
	_throttle[unit.get_instance_id()] = NAV_THROTTLE

func _add(unit: Node) -> void:
	if unit == null or not is_instance_valid(unit):
		return
	if unit in selected:
		return
	selected.append(unit)
	unit.set_selected(true)
