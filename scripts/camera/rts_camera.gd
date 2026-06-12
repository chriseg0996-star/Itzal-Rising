extends Camera2D

const WORLD_SIZE: Vector2 = Vector2(2048, 2048)

@export var pan_speed: float = 400.0
@export var edge_margin: int = 20
@export var min_zoom: float = 0.5
@export var max_zoom: float = 2.0
@export var zoom_step: float = 0.1

func _ready() -> void:
	position = Vector2(1024, 512)
	add_to_group("rts_camera")

func _process(delta: float) -> void:
	var direction := Vector2.ZERO

	if Input.is_action_pressed("move_right"):
		direction.x += 1.0
	if Input.is_action_pressed("move_left"):
		direction.x -= 1.0
	if Input.is_action_pressed("move_down"):
		direction.y += 1.0
	if Input.is_action_pressed("move_up"):
		direction.y -= 1.0

	var viewport: Viewport = get_viewport()
	var mouse_pos: Vector2 = viewport.get_mouse_position()
	var viewport_size: Vector2 = viewport.get_visible_rect().size

	if mouse_pos.x >= 0.0 and mouse_pos.x <= float(edge_margin):
		direction.x -= 1.0
	elif mouse_pos.x >= viewport_size.x - float(edge_margin) and mouse_pos.x <= viewport_size.x:
		direction.x += 1.0
	if mouse_pos.y >= 0.0 and mouse_pos.y <= float(edge_margin):
		direction.y -= 1.0
	elif mouse_pos.y >= viewport_size.y - float(edge_margin) and mouse_pos.y <= viewport_size.y:
		direction.y += 1.0

	if direction != Vector2.ZERO:
		direction = direction.normalized()
		position += direction * pan_speed * delta / zoom.x
	_clamp_to_world()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if not mb.pressed:
			return
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_apply_zoom(zoom_step)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_apply_zoom(-zoom_step)

func _apply_zoom(amount: float) -> void:
	var new_zoom: float = clampf(zoom.x + amount, min_zoom, max_zoom)
	zoom = Vector2(new_zoom, new_zoom)
	_clamp_to_world()

## Keep the view inside the world; if the view is wider than the world on an
## axis (possible at min zoom), center that axis instead — clampf would get
## min > max there.
func _clamp_to_world() -> void:
	var half_view: Vector2 = get_viewport().get_visible_rect().size * 0.5 / zoom
	for axis in 2:
		if half_view[axis] * 2.0 >= WORLD_SIZE[axis]:
			position[axis] = WORLD_SIZE[axis] * 0.5
		else:
			position[axis] = clampf(position[axis], half_view[axis], WORLD_SIZE[axis] - half_view[axis])
