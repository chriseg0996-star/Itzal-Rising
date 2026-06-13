extends CanvasLayer

## Guided first-match tutorial. Dormant unless the active mission is "tutorial"
## (so normal matches pay nothing). Walks the player through a fixed sequence of
## steps, advancing as it detects each action against live game state. Skippable.

const POLL: float = 0.5

const STEPS: Array[Dictionary] = [
	{"id": "select", "text": "Left-click one of your villagers to select it."},
	{"id": "gather", "text": "Right-click a tree or gold mine to send your villager to gather."},
	{"id": "barracks", "text": "Press B, then left-click open ground to build a Barracks."},
	{"id": "train", "text": "Select the Barracks and train a Soldier."},
	{"id": "ability", "text": "Press E to use your faction ability."},
	{"id": "done", "text": "You're ready. Defeat the enemy base to win. Good luck!"},
]

var _step: int = 0
var _accum: float = 0.0
var _label: Label = null
var _panel: PanelContainer = null

func _ready() -> void:
	layer = 8
	if ActiveMission.current_id != "tutorial":
		queue_free()  # dormant for normal matches
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_panel()
	_refresh_text()
	# Snappier advance on the selection step.
	SelectionManager.selection_changed.connect(_on_selection_changed)

func _build_panel() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.07, 0.11, 0.92)
	sb.set_border_width_all(1)
	sb.border_color = Color(0.0, 0.90, 0.78, 0.6)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(12)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_panel.offset_top = 96.0
	_panel.offset_left = -300.0
	_panel.offset_right = 300.0
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_panel.add_child(v)

	var heading := Label.new()
	heading.text = "TUTORIAL"
	heading.add_theme_color_override("font_color", Color(0.0, 0.90, 0.78, 1.0))
	heading.add_theme_font_size_override("font_size", 13)
	v.add_child(heading)

	_label = Label.new()
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.custom_minimum_size = Vector2(560, 0)
	_label.add_theme_color_override("font_color", Color(0.95, 0.97, 0.98, 1.0))
	_label.add_theme_font_size_override("font_size", 18)
	v.add_child(_label)

	var skip := Button.new()
	skip.text = "Skip Tutorial"
	skip.size_flags_horizontal = Control.SIZE_SHRINK_END
	skip.add_theme_color_override("font_color", Color(0.55, 0.62, 0.68, 1.0))
	skip.add_theme_color_override("font_hover_color", Color(0.0, 0.90, 0.78, 1.0))
	skip.pressed.connect(_finish)
	v.add_child(skip)

func _process(delta: float) -> void:
	if _label == null:
		return
	_accum += delta
	if _accum < POLL:
		return
	_accum = 0.0
	if _is_step_done(STEPS[_step]["id"]):
		_advance()

func _on_selection_changed(_units: Array) -> void:
	if _label != null and _is_step_done(STEPS[_step]["id"]):
		_advance()

func _advance() -> void:
	_flash_done()
	if _step >= STEPS.size() - 1:
		_finish()
		return
	_step += 1
	_refresh_text()

func _refresh_text() -> void:
	if _label != null:
		_label.text = String(STEPS[_step]["text"])

func _flash_done() -> void:
	if _label == null:
		return
	_label.add_theme_color_override("font_color", Color(0.3, 0.95, 0.5, 1.0))
	var tw := create_tween()
	tw.tween_callback(func() -> void:
		if _label != null:
			_label.add_theme_color_override("font_color", Color(0.95, 0.97, 0.98, 1.0))
	).set_delay(0.25)

func _finish() -> void:
	ProfileManager.clear_first_run()
	queue_free()

## Per-step completion checks against live game state.
func _is_step_done(step_id: String) -> bool:
	match step_id:
		"select":
			for u in SelectionManager.selected:
				if is_instance_valid(u) and u.is_in_group("villagers"):
					return true
			return false
		"gather":
			for v in get_tree().get_nodes_in_group("villagers"):
				if is_instance_valid(v) and FactionManager.is_player_faction(int(v.get("faction_id"))) \
						and v.has_method("is_harvesting") and v.is_harvesting():
					return true
			return false
		"barracks":
			return _player_has_building("Barracks")
		"train":
			return GameStats.units_trained >= 1
		"ability":
			var ap: Node = get_tree().get_first_node_in_group("ability_panel")
			return ap != null and ap.has_method("get_cooldown") and ap.get_cooldown() > 0.0
		"done":
			return true
	return false

func _player_has_building(building_name: String) -> bool:
	for b in get_tree().get_nodes_in_group("buildings"):
		if not is_instance_valid(b):
			continue
		if String(b.get("building_name")) == building_name \
				and FactionManager.is_player_faction(int(b.get("faction_id"))):
			return true
	return false
