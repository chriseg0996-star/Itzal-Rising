extends Camera2D

const WORLD_SIZE: Vector2 = Vector2(2048, 2048)

@export var pan_speed: float = 520.0
@export var edge_margin: int = 20
@export var min_zoom: float = 0.5
@export var max_zoom: float = 2.0
@export var zoom_step: float = 0.12
## Higher = snappier; lower = floatier. Frame-rate independent (scaled by delta).
@export var pan_smoothing: float = 12.0
@export var zoom_smoothing: float = 14.0

var _shake_amount: float = 0.0
var _shake_timer: float = 0.0
var _shake_duration: float = 0.0
var _pan_velocity: Vector2 = Vector2.ZERO
var _target_zoom: float = 1.0

func _ready() -> void:
	position = Vector2(1024, 512)
	_target_zoom = zoom.x
	add_to_group("rts_camera")

## Kick a decaying screen shake. Applied to `offset` (not `position`) so it never
## fights _clamp_to_world. The strongest active shake wins.
func shake(amount: float, duration: float) -> void:
	_shake_amount = maxf(_shake_amount, amount)
	_shake_duration = maxf(_shake_duration, duration)
	_shake_timer = maxf(_shake_timer, duration)

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

	# Edge pan: trigger when the cursor is near OR past an edge. No hard far-side
	# bound, so it still fires when the stretch mode letterboxes an axis (the
	# cursor then sits just outside [0, size] in the black bar) — that was why
	# vertical edge-scroll silently failed while horizontal worked. Gated on
	# window focus so an off-window cursor doesn't scroll while we're alt-tabbed.
	var win: Window = get_window()
	if win == null or win.has_focus():
		if mouse_pos.x <= float(edge_margin):
			direction.x -= 1.0
		elif mouse_pos.x >= viewport_size.x - float(edge_margin):
			direction.x += 1.0
		if mouse_pos.y <= float(edge_margin):
			direction.y -= 1.0
		elif mouse_pos.y >= viewport_size.y - float(edge_margin):
			direction.y += 1.0

	# Ease the pan velocity toward the target so starts/stops glide instead of
	# snapping. pan_speed is divided by zoom so the on-screen speed stays steady.
	var target_velocity: Vector2 = Vector2.ZERO
	if direction != Vector2.ZERO:
		target_velocity = direction.normalized() * pan_speed / zoom.x
	_pan_velocity = _pan_velocity.lerp(target_velocity, clampf(pan_smoothing * delta, 0.0, 1.0))
	position += _pan_velocity * delta

	# Smoothly approach the target zoom set by the wheel.
	if not is_equal_approx(zoom.x, _target_zoom):
		var z: float = lerpf(zoom.x, _target_zoom, clampf(zoom_smoothing * delta, 0.0, 1.0))
		zoom = Vector2(z, z)

	_clamp_to_world()
	_apply_shake(delta)

func _apply_shake(delta: float) -> void:
	if _shake_timer <= 0.0:
		if offset != Vector2.ZERO:
			offset = Vector2.ZERO
		return
	_shake_timer -= delta
	var mag: float = _shake_amount * (_shake_timer / _shake_duration)
	offset = Vector2(randf_range(-mag, mag), randf_range(-mag, mag))
	if _shake_timer <= 0.0:
		offset = Vector2.ZERO
		_shake_amount = 0.0

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
	# Set a target; _process eases the actual zoom toward it.
	_target_zoom = clampf(_target_zoom + amount, min_zoom, max_zoom)

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
