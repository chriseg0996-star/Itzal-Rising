extends Control

## Skirmish setup screen (3-column layout: MAP | FACTION | DIFFICULTY).
## All UI is built in code. Start writes the player's choices to GameSettings,
## runs the standard match reset sequence (so EnemyAI.reset() applies the chosen
## difficulty), then loads the World. Back returns to the main menu.

const WORLD_SCENE: String = "res://scenes/world/World.tscn"
const MAIN_MENU_SCENE: String = "res://scenes/ui/MainMenu.tscn"
const BG_IMAGE: String = "res://assets/sprites/mainmenu_reference.png"

const ACCENT: Color = Color(0.0, 0.85, 0.85)
const TEXT: Color = Color(0.92, 0.95, 0.98)
const TEXT_DIM: Color = Color(0.5, 0.58, 0.62)
const PANEL_BG: Color = Color(0.09, 0.12, 0.15, 0.9)
const CARD_BG: Color = Color(0.11, 0.14, 0.18, 0.95)

# Index -> data string. Order must match the difficulty cards built below.
const DIFFICULTY_KEYS: Array[String] = ["easy", "normal", "hard"]
const DIFFICULTY_DEFAULT: int = 1  # "normal"
const MAP_KEY: String = "jungle_basin"

# Selection state.
var _selected_faction: int = 0
var _selected_difficulty: int = DIFFICULTY_DEFAULT

# Live stylebox refs so selection can re-tint borders in place.
var _faction_styles: Array[StyleBoxFlat] = []
var _difficulty_styles: Array[StyleBoxFlat] = []

# Faction cards. player_faction_id: 0 = Itzal, 1 = Decay (locked), 2 = Ix.
var _factions: Array[Dictionary] = [
	{
		"name": "Itzal Resistance", "key": "itzal", "pid": 0,
		"color": Color(0.0, 0.85, 0.85), "playable": true,
		"desc": "Warriors of Itzal: villagers, soldiers and jaguar riders.",
	},
	{
		"name": "Enemy Decay", "key": "decay", "pid": 1,
		"color": Color(0.62, 0.35, 0.85), "playable": false,
		"desc": "Corrupted units that spread decay and corruption damage.",
	},
	{
		"name": "Ix Architects", "key": "ix", "pid": 2,
		"color": Color(0.9, 0.62, 0.2), "playable": true,
		"desc": "Technologically advanced units forged from obsidian lattice.",
	},
]

var _difficulties: Array[Dictionary] = [
	{"label": "EASY", "color": Color(0.2, 0.8, 0.2), "desc": "Plentiful resources, passive enemy."},
	{"label": "NORMAL", "color": Color(0.9, 0.75, 0.1), "desc": "Balanced economy and enemy pressure."},
	{"label": "HARD", "color": Color(0.85, 0.15, 0.15), "desc": "Lean economy, aggressive enemy waves."},
]

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	# --- Background art + dark overlay ---
	var bg := TextureRect.new()
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	if ResourceLoader.exists(BG_IMAGE):
		bg.texture = load(BG_IMAGE)
	add_child(bg)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)

	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.6)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)

	# --- Root layout ---
	var margin := MarginContainer.new()
	add_child(margin)
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 36)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 20)
	margin.add_child(root)

	var title := Label.new()
	title.text = "SKIRMISH SETUP"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(0.8, 0.9, 0.95))
	title.add_theme_color_override("font_outline_color", ACCENT)
	title.add_theme_constant_override("outline_size", 6)
	title.add_theme_font_size_override("font_size", 48)
	root.add_child(title)

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 20)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(cols)

	_build_map_column(cols)
	_build_faction_column(cols)
	_build_difficulty_column(cols)

	root.add_child(_build_action_bar())

# ---------------------------------------------------------------------------
# MAP column
# ---------------------------------------------------------------------------
func _build_map_column(parent: HBoxContainer) -> void:
	var panel := _column_panel(1.0)
	parent.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)

	v.add_child(_caption("MAP"))

	var thumb := ColorRect.new()
	thumb.color = Color(0.12, 0.28, 0.16, 1.0)
	thumb.custom_minimum_size = Vector2(200, 150)
	thumb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(thumb)

	v.add_child(_map_entry("Jungle Basin", true))
	for name_str in ["Sunken Reef", "Azure Coast", "Volcanic Crags"]:
		v.add_child(_map_entry(name_str, false))

	var filler := Control.new()
	filler.size_flags_vertical = Control.SIZE_EXPAND_FILL
	filler.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(filler)

func _map_entry(text: String, selected: bool) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 16)
	l.add_theme_color_override("font_color", TEXT if selected else TEXT_DIM)
	return l

# ---------------------------------------------------------------------------
# FACTION column
# ---------------------------------------------------------------------------
func _build_faction_column(parent: HBoxContainer) -> void:
	var panel := _column_panel(2.8)
	parent.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)

	v.add_child(_caption("FACTION"))

	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 14)
	cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(cards)

	for i in _factions.size():
		cards.add_child(_make_faction_card(i))

func _make_faction_card(idx: int) -> Control:
	var data: Dictionary = _factions[idx]
	var col: Color = data["color"]
	var playable: bool = data["playable"]
	var selected: bool = (idx == _selected_faction)

	var style := _card_style(col, selected)
	_faction_styles.append(style)

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", style)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if not playable:
		card.modulate = Color(1, 1, 1, 0.5)
	card.gui_input.connect(_on_faction_input.bind(idx))

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	card.add_child(v)

	var icon := ColorRect.new()
	icon.color = col
	icon.custom_minimum_size = Vector2(80, 80)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(icon)

	var name_lbl := Label.new()
	name_lbl.text = data["name"]
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_color_override("font_color", TEXT)
	name_lbl.add_theme_font_size_override("font_size", 19)
	v.add_child(name_lbl)

	# Placeholder "unit sprites" row.
	var units := HBoxContainer.new()
	units.alignment = BoxContainer.ALIGNMENT_CENTER
	units.add_theme_constant_override("separation", 6)
	for u in 3:
		var dot := ColorRect.new()
		dot.color = col.lightened(0.25)
		dot.custom_minimum_size = Vector2(22, 30)
		units.add_child(dot)
	v.add_child(units)

	var desc := Label.new()
	desc.text = data["desc"]
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.add_theme_color_override("font_color", TEXT_DIM)
	desc.add_theme_font_size_override("font_size", 13)
	desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(desc)

	if not playable:
		var locked := Label.new()
		locked.text = "Not playable yet"
		locked.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		locked.add_theme_color_override("font_color", col.lightened(0.2))
		locked.add_theme_font_size_override("font_size", 12)
		v.add_child(locked)

	return card

func _on_faction_input(event: InputEvent, idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_select_faction(idx)

func _select_faction(idx: int) -> void:
	if not bool(_factions[idx]["playable"]):
		return
	_selected_faction = idx
	for i in _faction_styles.size():
		var col: Color = _factions[i]["color"]
		_apply_card_style(_faction_styles[i], col, i == _selected_faction)

# ---------------------------------------------------------------------------
# DIFFICULTY column
# ---------------------------------------------------------------------------
func _build_difficulty_column(parent: HBoxContainer) -> void:
	var panel := _column_panel(1.3)
	parent.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)

	v.add_child(_caption("DIFFICULTY"))

	for i in _difficulties.size():
		v.add_child(_make_difficulty_card(i))

	var filler := Control.new()
	filler.size_flags_vertical = Control.SIZE_EXPAND_FILL
	filler.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(filler)

func _make_difficulty_card(idx: int) -> Control:
	var data: Dictionary = _difficulties[idx]
	var col: Color = data["color"]
	var selected: bool = (idx == _selected_difficulty)

	var style := _card_style(col, selected)
	_difficulty_styles.append(style)

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", style)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.gui_input.connect(_on_difficulty_input.bind(idx))

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	card.add_child(v)

	var label := Label.new()
	label.text = data["label"]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", col)
	label.add_theme_font_size_override("font_size", 24)
	v.add_child(label)

	var desc := Label.new()
	desc.text = data["desc"]
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.add_theme_color_override("font_color", TEXT_DIM)
	desc.add_theme_font_size_override("font_size", 12)
	v.add_child(desc)

	return card

func _on_difficulty_input(event: InputEvent, idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_select_difficulty(idx)

func _select_difficulty(idx: int) -> void:
	_selected_difficulty = idx
	for i in _difficulty_styles.size():
		var col: Color = _difficulties[i]["color"]
		_apply_card_style(_difficulty_styles[i], col, i == _selected_difficulty)

# ---------------------------------------------------------------------------
# Action bar (START / BACK)
# ---------------------------------------------------------------------------
func _build_action_bar() -> Control:
	var bar := HBoxContainer.new()
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", 24)

	var start_btn := _action_button("START", true)
	start_btn.pressed.connect(_on_start)
	bar.add_child(start_btn)

	var back_btn := _action_button("BACK", false)
	back_btn.pressed.connect(_on_back)
	bar.add_child(back_btn)
	return bar

func _action_button(text: String, primary: bool) -> Button:
	var btn := Button.new()
	btn.text = text
	if primary:
		btn.custom_minimum_size = Vector2(280, 56)
		btn.add_theme_font_size_override("font_size", 26)
		btn.add_theme_color_override("font_color", ACCENT)
		btn.add_theme_color_override("font_hover_color", Color(0.6, 1, 1))
		btn.add_theme_color_override("font_pressed_color", TEXT)
		btn.add_theme_stylebox_override("normal", _button_style(ACCENT, 0.12, 2))
		btn.add_theme_stylebox_override("hover", _button_style(ACCENT, 0.22, 2))
		btn.add_theme_stylebox_override("pressed", _button_style(ACCENT, 0.3, 2))
		btn.add_theme_stylebox_override("focus", _button_style(ACCENT, 0.12, 2))
	else:
		btn.custom_minimum_size = Vector2(150, 56)
		btn.add_theme_font_size_override("font_size", 20)
		btn.add_theme_color_override("font_color", TEXT_DIM)
		btn.add_theme_color_override("font_hover_color", TEXT)
		btn.add_theme_color_override("font_pressed_color", TEXT)
		var neutral := Color(0.5, 0.58, 0.62)
		btn.add_theme_stylebox_override("normal", _button_style(neutral, 0.0, 1))
		btn.add_theme_stylebox_override("hover", _button_style(neutral, 0.1, 1))
		btn.add_theme_stylebox_override("pressed", _button_style(neutral, 0.16, 1))
		btn.add_theme_stylebox_override("focus", _button_style(neutral, 0.0, 1))
	return btn

# ---------------------------------------------------------------------------
# Style helpers
# ---------------------------------------------------------------------------
func _column_panel(stretch: float) -> PanelContainer:
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL_BG
	sb.set_corner_radius_all(10)
	sb.set_border_width_all(1)
	sb.border_color = Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.25)
	sb.set_content_margin_all(16)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", sb)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_FILL
	panel.size_flags_stretch_ratio = stretch
	return panel

func _card_style(col: Color, selected: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = CARD_BG
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(12)
	_apply_card_style(sb, col, selected)
	return sb

func _apply_card_style(sb: StyleBoxFlat, col: Color, selected: bool) -> void:
	if selected:
		sb.border_color = col
		sb.set_border_width_all(3)
	else:
		sb.border_color = Color(col.r, col.g, col.b, 0.3)
		sb.set_border_width_all(2)

func _button_style(col: Color, fill_alpha: float, border: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(col.r, col.g, col.b, fill_alpha)
	sb.set_corner_radius_all(6)
	sb.set_border_width_all(border)
	sb.border_color = col
	sb.set_content_margin_all(8)
	return sb

func _caption(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_color", Color(0.7, 0.8, 0.85))
	l.add_theme_font_size_override("font_size", 22)
	return l

# ---------------------------------------------------------------------------
# Navigation (preserved)
# ---------------------------------------------------------------------------
func _on_start() -> void:
	GameSettings.difficulty = DIFFICULTY_KEYS[_selected_difficulty]
	GameSettings.faction = String(_factions[_selected_faction]["key"])
	GameSettings.player_faction_id = int(_factions[_selected_faction]["pid"])
	GameSettings.map = MAP_KEY
	ResourceManager.reset()
	SelectionManager.clear()
	SelectionManager.deselect_building()
	BuildingPlacer.cancel_placement()
	EnemyAI.reset()
	GameStats.reset()
	get_tree().change_scene_to_file(WORLD_SCENE)

func _on_back() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
