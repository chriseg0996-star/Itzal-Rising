extends Node

signal building_selected(building: Node)
signal building_deselected
signal move_commanded(target: Vector2, units: Array)
signal selection_changed(units: Array)
## Read-only focus on a non-commandable node (enemy unit/building) for the info
## panel. Emits null when inspection is cleared.
signal inspect_changed(node: Node)

const FORMATION_SPACING: float = 40.0
const LINE_SPACING: float = 48.0
const NAV_THROTTLE: float = 0.2

# Mirrors harvest_component._safe_target: the world inset by 4px.
const MAP_CLAMP_MIN: Vector2 = Vector2(4.0, 4.0)
const MAP_CLAMP_MAX: Vector2 = Vector2(MapConfig.WORLD_SIZE - 4.0, MapConfig.WORLD_SIZE - 4.0)

var selected: Array = []
var selected_building: Node = null
var inspected: Node = null
var _inspect_marker: Node2D = null
var _throttle: Dictionary = {}
## Control groups: 1..9 -> Array of units. Ctrl+N binds, N recalls, N twice
## quickly also centres the camera. _idle_idx cycles the idle-villager hotkey.
var _groups: Dictionary = {}
var _last_recall: Dictionary = {}
var _idle_idx: int = 0
const DOUBLE_TAP_MS: int = 350

## Read-only inspect of a hostile unit/building: clears any commandable selection
## and points the info panel at `node`, with a neutral targeting ring on the map.
func inspect(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	for u in selected:
		if is_instance_valid(u):
			u.set_selected(false)
	selected.clear()
	selection_changed.emit([])
	if selected_building != null:
		selected_building = null
		building_deselected.emit()
	_free_inspect_marker()
	inspected = node
	if node is Node2D:
		var marker := InspectMarker.new()
		marker.z_index = 60
		var bn: Variant = node.get("building_name")
		if bn != null and String(bn) != "":
			marker.radius = 70.0
		# Deferred: the target may be mid-tree-callback when clicked, which makes
		# a direct add_child fail ("parent busy setting up children").
		(node as Node2D).add_child.call_deferred(marker)
		_inspect_marker = marker
	inspect_changed.emit(node)
	SoundManager.play("unit_select")

func _clear_inspect() -> void:
	_free_inspect_marker()
	if inspected == null:
		return
	inspected = null
	inspect_changed.emit(null)

func _free_inspect_marker() -> void:
	if _inspect_marker != null and is_instance_valid(_inspect_marker):
		_inspect_marker.queue_free()
	_inspect_marker = null

func select_only(unit: Node) -> void:
	clear()
	_add(unit)
	selection_changed.emit(selected.duplicate())
	SoundManager.play("unit_select")
	if selected.size() <= 6:
		for u in selected:
			if is_instance_valid(u) and u is Node2D:
				Particles.spawn((u as Node2D).get_parent(), "selection_pulse", (u as Node2D).global_position)

func select_multiple(units: Array) -> void:
	clear()
	for u in units:
		_add(u)
	selection_changed.emit(selected.duplicate())
	SoundManager.play("unit_select")

func toggle_unit(unit: Node) -> void:
	if unit == null or not is_instance_valid(unit):
		return
	if unit in selected:
		selected.erase(unit)
		unit.set_selected(false)
	else:
		_add(unit)
	selection_changed.emit(selected.duplicate())

func clear() -> void:
	for u in selected:
		if is_instance_valid(u):
			u.set_selected(false)
	selected.clear()
	selection_changed.emit([])
	_clear_inspect()

func select_building(b: Node) -> void:
	if b == null or not is_instance_valid(b):
		return
	if b == selected_building:
		return
	selected_building = b
	_clear_inspect()
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
		var dest: Vector2 = (target + Vector2(x_offset, y_offset)).clamp(MAP_CLAMP_MIN, MAP_CLAMP_MAX)
		if attack_move and u.has_method("attack_move"):
			u.attack_move(dest)
		elif u.has_method("move_to"):
			u.move_to(dest)
	SoundManager.play("unit_move", -6.0)

## Send selected villagers to build a construction site. Returns how many were
## dispatched (0 = none in selection, so the caller can fall back to a move).
func build_with_selected(site: Node) -> int:
	var n: int = 0
	for u in selected:
		if is_instance_valid(u) and u.has_method("build_structure"):
			u.build_structure(site)
			n += 1
	return n

## Send selected villagers to work a farm. Returns how many were dispatched.
func work_farm_with_selected(farm: Node) -> int:
	var n: int = 0
	for u in selected:
		if is_instance_valid(u) and u.has_method("work_farm"):
			u.work_farm(farm)
			n += 1
	return n

func harvest_with_selected(resource: Node) -> void:
	if selected.is_empty():
		return
	if resource == null or not is_instance_valid(resource):
		return
	for u in selected:
		if is_instance_valid(u) and u.has_method("harvest"):
			u.harvest(resource)

func _unhandled_input(event: InputEvent) -> void:
	if BuildingPlacer.is_placing():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if _handle_hotkey(event as InputEventKey):
			get_viewport().set_input_as_handled()
		return
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_RIGHT or not mb.pressed:
		return
	var world_pos: Vector2 = _screen_to_world(mb.position)
	# No units selected but a production building is: right-click sets its rally.
	if selected.is_empty() and selected_building != null and is_instance_valid(selected_building) \
			and selected_building.has_method("set_rally_point") and selected_building.has_train_slot(0) \
			and FactionManager.is_player_faction(int(selected_building.get("faction_id"))):
		selected_building.set_rally_point(world_pos.clamp(MAP_CLAMP_MIN, MAP_CLAMP_MAX))
		get_viewport().set_input_as_handled()
		return
	var resource := _resource_at(world_pos)
	if resource != null:
		harvest_with_selected(resource)
	else:
		_command_move(world_pos)
	get_viewport().set_input_as_handled()

## Control-group + idle-villager hotkeys. Returns true if it consumed the key.
func _handle_hotkey(event: InputEventKey) -> bool:
	var kc: int = event.keycode
	if kc >= KEY_1 and kc <= KEY_9:
		var n: int = kc - KEY_0
		if event.ctrl_pressed:
			_bind_group(n)
		else:
			_recall_group(n)
		return true
	if kc == KEY_PERIOD:
		_cycle_idle_villager()
		return true
	return false

func _bind_group(n: int) -> void:
	_groups[n] = selected.duplicate()
	if not selected.is_empty():
		AlertManager.push("Control group %d set (%d)" % [n, selected.size()], "info")

func _recall_group(n: int) -> void:
	var alive: Array = []
	for u in _groups.get(n, []):
		if is_instance_valid(u):
			alive.append(u)
	_groups[n] = alive
	if alive.is_empty():
		return
	select_multiple(alive)
	var now: int = Time.get_ticks_msec()
	if now - int(_last_recall.get(n, -9999)) < DOUBLE_TAP_MS:
		_center_camera_on(alive)
	_last_recall[n] = now

## Selects the next idle (not gathering/building/farming) player worker and
## snaps the camera to it; repeated presses cycle through them.
func _cycle_idle_villager() -> void:
	var idle: Array = []
	for u in get_tree().get_nodes_in_group("villagers"):
		if not is_instance_valid(u) or not (u is Node2D):
			continue
		if int(u.get("faction_id")) != GameSettings.player_faction_id:
			continue
		if u.has_method("is_busy") and u.is_busy():
			continue
		idle.append(u)
	if idle.is_empty():
		AlertManager.push("No idle workers", "info")
		return
	_idle_idx = _idle_idx % idle.size()
	var v: Node = idle[_idle_idx]
	_idle_idx += 1
	select_only(v)
	_center_camera_on([v])

## Double-click select: all player units sharing this one's sprite_asset that are
## currently on screen.
func select_same_type_on_screen(proto: Node, screen_rect: Rect2) -> void:
	if proto == null or not is_instance_valid(proto):
		return
	var key: String = String(proto.get("sprite_asset"))
	var found: Array = []
	for u in get_tree().get_nodes_in_group("player_units"):
		if not is_instance_valid(u) or not (u is Node2D):
			continue
		if String(u.get("sprite_asset")) != key:
			continue
		if screen_rect.has_point((u as Node2D).global_position):
			found.append(u)
	if not found.is_empty():
		select_multiple(found)

func _center_camera_on(units: Array) -> void:
	var c: Vector2 = Vector2.ZERO
	var k: int = 0
	for u in units:
		if is_instance_valid(u) and u is Node2D:
			c += (u as Node2D).global_position
			k += 1
	if k == 0:
		return
	var cam: Node = get_tree().get_first_node_in_group("rts_camera")
	if cam != null and cam is Node2D:
		(cam as Node2D).global_position = c / float(k)

func _resource_at(world_pos: Vector2) -> Node:
	var world := get_viewport().find_world_2d()
	if world == null:
		return null
	var space := world.direct_space_state
	var params := PhysicsPointQueryParameters2D.new()
	params.position = world_pos
	params.collide_with_areas = true
	params.collide_with_bodies = false
	params.collision_mask = 2
	var hits := space.intersect_point(params, 8)
	for hit in hits:
		var collider = hit.get("collider")
		if collider == null:
			continue
		var p = collider.get_parent()
		if p != null and p.is_in_group("resources"):
			return p
	return null

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
		var target: Vector2 = (world_pos + Vector2(offset_x, 0.0)).clamp(MAP_CLAMP_MIN, MAP_CLAMP_MAX)
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
