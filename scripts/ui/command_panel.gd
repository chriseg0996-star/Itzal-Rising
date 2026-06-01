extends CanvasLayer

const HIGHLIGHT: Color = Color(0.27, 0.86, 0.50, 1.0)

@onready var _move_btn: Button = $Panel/Margin/HBox/MoveBtn
@onready var _attack_btn: Button = $Panel/Margin/HBox/AttackBtn
@onready var _hold_btn: Button = $Panel/Margin/HBox/HoldBtn
@onready var _stop_btn: Button = $Panel/Margin/HBox/StopBtn
@onready var _patrol_btn: Button = $Panel/Margin/HBox/PatrolBtn
@onready var _rally_btn: Button = $Panel/Margin/HBox/RallyBtn

var pending_mode: String = ""
var _mode_buttons: Dictionary = {}

func _ready() -> void:
	_mode_buttons = {
		"move": _move_btn,
		"attack": _attack_btn,
		"patrol": _patrol_btn,
		"rally": _rally_btn,
	}
	_move_btn.pressed.connect(func() -> void: _set_pending("move"))
	_attack_btn.pressed.connect(func() -> void: _set_pending("attack"))
	_hold_btn.pressed.connect(_on_hold)
	_stop_btn.pressed.connect(_on_stop)
	_patrol_btn.pressed.connect(func() -> void: _set_pending("patrol"))
	_rally_btn.pressed.connect(func() -> void: _set_pending("rally"))
	SelectionManager.selection_changed.connect(_on_selection_changed)
	SelectionManager.building_selected.connect(_on_building_selected)
	SelectionManager.building_deselected.connect(_on_building_deselected)
	_update_visibility()

func _on_selection_changed(_units: Array) -> void:
	_update_visibility()

func _on_building_selected(_building: Node) -> void:
	_update_visibility()

func _on_building_deselected() -> void:
	_update_visibility()

func _update_visibility() -> void:
	var has_units: bool = not SelectionManager.selected.is_empty()
	var has_building: bool = SelectionManager.selected_building != null
	visible = has_units and not has_building
	if not visible:
		_clear_pending()

func _set_pending(mode: String) -> void:
	pending_mode = mode
	_update_highlight()

func _clear_pending() -> void:
	pending_mode = ""
	_update_highlight()

func _update_highlight() -> void:
	for key in _mode_buttons:
		var btn: Button = _mode_buttons[key]
		btn.modulate = HIGHLIGHT if key == pending_mode else Color.WHITE

func _on_hold() -> void:
	_clear_pending()
	for u in SelectionManager.selected:
		if is_instance_valid(u) and u.has_method("hold"):
			u.hold()

func _on_stop() -> void:
	_clear_pending()
	for u in SelectionManager.selected:
		if is_instance_valid(u) and u.has_method("stop"):
			u.stop()

func _unhandled_input(event: InputEvent) -> void:
	if BuildingPlacer.is_placing():
		return
	if pending_mode == "":
		return
	if event.is_action_pressed("pause"):
		_clear_pending()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			var world_pos: Vector2 = _screen_to_world(mb.position)
			_execute_pending(world_pos)
			_clear_pending()
			get_viewport().set_input_as_handled()

func _execute_pending(world_pos: Vector2) -> void:
	match pending_mode:
		"move", "rally":
			SelectionManager.move_selected_to(world_pos, false)
		"attack":
			SelectionManager.move_selected_to(world_pos, true)
		"patrol":
			for u in SelectionManager.selected:
				if is_instance_valid(u) and u.has_method("patrol"):
					u.patrol(world_pos)

func _screen_to_world(screen_pos: Vector2) -> Vector2:
	var vp: Viewport = get_viewport()
	if vp == null:
		return screen_pos
	var canvas_xform: Transform2D = vp.get_canvas_transform()
	return canvas_xform.affine_inverse() * screen_pos
