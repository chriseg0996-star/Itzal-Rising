extends Node

signal building_selected(building: Node)
signal building_deselected

const FORMATION_SPACING: float = 40.0

var selected: Array = []
var selected_building: Node = null

func select_only(unit: Node) -> void:
	clear()
	_add(unit)

func select_multiple(units: Array) -> void:
	clear()
	for u in units:
		_add(u)

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

func _add(unit: Node) -> void:
	if unit == null or not is_instance_valid(unit):
		return
	if unit in selected:
		return
	selected.append(unit)
	unit.set_selected(true)
