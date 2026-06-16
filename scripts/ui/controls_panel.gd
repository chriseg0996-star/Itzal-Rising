extends CanvasLayer

## Static keybind legend. Toggled with F1 ("toggle_controls") or opened from
## the pause menu's CONTROLS button. Works while the tree is paused.

const ACCENT: Color = Color(0.0, 0.85, 0.85, 1.0)
const WHITE: Color = Color(0.92, 0.95, 0.98, 1.0)
const MUTED: Color = Color(0.55, 0.65, 0.7, 1.0)

const BINDINGS: Array[Array] = [
	["W A S D / screen edge", "Pan camera"],
	["Mouse wheel", "Zoom in / out"],
	["Left click / drag", "Select units"],
	["Right click", "Move / harvest"],
	["G + right click", "Attack-move"],
	["B / T / Y", "Build Barracks / Town Center / Tower"],
	["M", "Build Monument (hold 3:00 to win)"],
	["F", "Build Farm (passive food income)"],
	["E / R / Q", "Faction abilities (3 per civ)"],
	["Barracks", "Trains Soldier / Archer / Cavalry (counters: cavalry > ranged > infantry)"],
	["Right click while placing", "Cancel placement"],
	["Esc", "Pause"],
	["F1", "Toggle this panel"],
	["New here?", "Try the Tutorial from the Campaign menu"],
]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	visible = false
	_build()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_controls"):
		visible = not visible
		get_viewport().set_input_as_handled()

func open() -> void:
	visible = true

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.1, 0.12, 0.6)
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.15, 0.18, 0.98)
	sb.set_border_width_all(2)
	sb.border_color = Color(0.0, 0.85, 0.85, 0.85)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(28)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)

	var title := Label.new()
	title.text = "CONTROLS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", ACCENT)
	title.add_theme_font_size_override("font_size", 28)
	v.add_child(title)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 28)
	grid.add_theme_constant_override("v_separation", 6)
	v.add_child(grid)
	for binding in BINDINGS:
		var key := Label.new()
		key.text = String(binding[0])
		key.add_theme_color_override("font_color", ACCENT)
		key.add_theme_font_size_override("font_size", 14)
		grid.add_child(key)
		var action := Label.new()
		action.text = String(binding[1])
		action.add_theme_color_override("font_color", WHITE)
		action.add_theme_font_size_override("font_size", 14)
		grid.add_child(action)

	var close := Button.new()
	close.text = "CLOSE"
	close.custom_minimum_size = Vector2(160, 38)
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.add_theme_color_override("font_color", MUTED)
	close.add_theme_color_override("font_hover_color", WHITE)
	close.pressed.connect(func() -> void: visible = false)
	v.add_child(close)
