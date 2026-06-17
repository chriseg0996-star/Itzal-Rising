extends Control

const WORLD_SIZE: Vector2 = Vector2(MapConfig.WORLD_SIZE, MapConfig.WORLD_SIZE)
const POLL_INTERVAL: float = 0.1

const BG_COLOR: Color = Color(0.04, 0.07, 0.10, 0.92)
const BORDER_COLOR: Color = Color(1.0, 1.0, 1.0, 0.12)
const PLAYER_UNIT_COLOR: Color = Color(0.0, 0.90, 0.78, 1.0)
const ENEMY_UNIT_COLOR: Color = Color(0.93, 0.20, 0.20, 1.0)
const PLAYER_BUILDING_COLOR: Color = Color(0.0, 0.67, 1.0, 0.9)
const ENEMY_BUILDING_COLOR: Color = Color(0.8, 0.15, 0.8, 0.9)
const RESOURCE_COLOR: Color = Color(0.95, 0.78, 0.1, 0.7)
const CAMERA_RECT_COLOR: Color = Color(1.0, 1.0, 1.0, 0.4)

const UNIT_SIZE: float = 3.0
const BUILDING_SIZE: float = 5.0
const RESOURCE_SIZE: float = 2.0

# Dot data rebuilt each poll — stored for _draw(). {pos: Vector2, color: Color, size: float}
var _dots: Array[Dictionary] = []
var _camera_rect: Rect2 = Rect2()
var _poll_timer: float = 0.0

func _ready() -> void:
	gui_input.connect(_on_gui_input)
	_rebuild_dots()
	queue_redraw()

func _process(delta: float) -> void:
	_poll_timer += delta
	if _poll_timer >= POLL_INTERVAL:
		_poll_timer = 0.0
		_rebuild_dots()
		queue_redraw()

func _draw() -> void:
	var ms: Vector2 = size
	draw_rect(Rect2(Vector2.ZERO, ms), BG_COLOR, true)
	for d in _dots:
		var s: float = float(d["size"])
		var p: Vector2 = d["pos"]
		draw_rect(Rect2(p - Vector2(s, s) * 0.5, Vector2(s, s)), d["color"], true)
	if _camera_rect.size != Vector2.ZERO:
		draw_rect(_camera_rect, CAMERA_RECT_COLOR, false, 1.0)
	draw_rect(Rect2(Vector2.ZERO, ms), BORDER_COLOR, false, 1.0)

func _rebuild_dots() -> void:
	_dots.clear()
	var ms: Vector2 = size
	# Fog filter (absent in menus/tests → behave as before): enemy units need
	# live vision (state 2); enemy buildings/resources need exploration (>0).
	var fog: Node = get_tree().get_first_node_in_group("fog_of_war")
	for u in get_tree().get_nodes_in_group("player_units"):
		if is_instance_valid(u) and u is Node2D:
			_add_dot((u as Node2D).global_position, PLAYER_UNIT_COLOR, UNIT_SIZE, ms)
	for e in get_tree().get_nodes_in_group("combat_units"):
		if is_instance_valid(e) and e is Node2D and not (e as Node).is_in_group("player_units"):
			if fog != null and fog.get_cell_state((e as Node2D).global_position) < 2:
				continue
			_add_dot((e as Node2D).global_position, ENEMY_UNIT_COLOR, UNIT_SIZE, ms)
	for b in get_tree().get_nodes_in_group("buildings"):
		if not (is_instance_valid(b) and b is Node2D):
			continue
		var f: Variant = b.get("faction_id")
		if f == null:
			continue
		if FactionManager.is_player_faction(int(f)):
			_add_dot((b as Node2D).global_position, PLAYER_BUILDING_COLOR, BUILDING_SIZE, ms)
		elif fog == null or fog.get_cell_state((b as Node2D).global_position) > 0:
			_add_dot((b as Node2D).global_position, ENEMY_BUILDING_COLOR, BUILDING_SIZE, ms)
	for r in get_tree().get_nodes_in_group("resources"):
		if is_instance_valid(r) and r is Node2D:
			if fog != null and fog.get_cell_state((r as Node2D).global_position) == 0:
				continue
			_add_dot((r as Node2D).global_position, RESOURCE_COLOR, RESOURCE_SIZE, ms)
	_update_camera_rect(ms)

func _add_dot(world_pos: Vector2, color: Color, dot_size: float, ms: Vector2) -> void:
	var p: Vector2 = world_pos / WORLD_SIZE * ms
	if p.x < 0.0 or p.y < 0.0 or p.x > ms.x or p.y > ms.y:
		return
	_dots.append({"pos": p, "color": color, "size": dot_size})

func _update_camera_rect(ms: Vector2) -> void:
	var cam: Node = get_tree().get_first_node_in_group("rts_camera")
	if cam == null or not (cam is Camera2D):
		_camera_rect = Rect2()
		return
	var camera := cam as Camera2D
	var zoom: Vector2 = camera.zoom
	if zoom.x == 0.0 or zoom.y == 0.0:
		_camera_rect = Rect2()
		return
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	var half_world: Vector2 = vp_size * 0.5 / zoom
	var top_left_world: Vector2 = camera.global_position - half_world
	var mm_pos: Vector2 = top_left_world / WORLD_SIZE * ms
	var mm_size: Vector2 = (half_world * 2.0) / WORLD_SIZE * ms
	_camera_rect = Rect2(mm_pos, mm_size)

func _on_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
		return
	var ms: Vector2 = size
	if ms.x <= 0.0 or ms.y <= 0.0:
		return
	var world_pos: Vector2 = mb.position / ms * WORLD_SIZE
	world_pos.x = clampf(world_pos.x, 0.0, WORLD_SIZE.x)
	world_pos.y = clampf(world_pos.y, 0.0, WORLD_SIZE.y)
	var cam: Node = get_tree().get_first_node_in_group("rts_camera")
	if cam != null and cam is Camera2D:
		# Glide instead of snap; the camera's per-frame _clamp_to_world keeps
		# every tweened frame inside the map bounds.
		var tween := (cam as Camera2D).create_tween()
		tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(cam, "global_position", world_pos, 0.25)
	accept_event()
