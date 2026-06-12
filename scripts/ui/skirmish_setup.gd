extends Control

## Skirmish Setup — map / faction / difficulty selection over a dimmed background.
## UI is built in code (project convention); SkirmishSetup.tscn holds the root
## Control + the BGImage TextureRect. The bg texture is loaded at runtime so a
## missing file never breaks the scene. Start writes the choices to GameSettings,
## runs the standard match reset sequence, then loads the World.

const WORLD_SCENE: String = "res://scenes/world/World.tscn"
const MAIN_MENU_SCENE: String = "res://scenes/ui/MainMenu.tscn"
const BG_IMAGE: String = "res://assets/ui/skirmish_bg.png"

const ACCENT: Color = Color(0.0, 0.90, 0.78, 1.0)
const PANEL_BG: Color = Color(0.04, 0.07, 0.11, 0.82)
const PANEL_BORDER: Color = Color(0.0, 0.90, 0.78, 0.35)
const TEXT_MUTED: Color = Color(0.7, 0.75, 0.8, 1.0)
const WHITE: Color = Color(0.95, 0.97, 0.98, 1.0)
const DIM_BORDER: Color = Color(0.3, 0.35, 0.4, 1.0)

var _maps: Array[Dictionary] = [
	{"name": "Jungle Basin", "color": Color(0.08, 0.22, 0.10, 1.0)},
	{"name": "Sunken Reef", "color": Color(0.06, 0.14, 0.26, 1.0)},
	{"name": "Azure Coast", "color": Color(0.08, 0.18, 0.28, 1.0)},
	{"name": "Volcanic Crags", "color": Color(0.22, 0.08, 0.06, 1.0)},
]

var _factions: Array[Dictionary] = [
	{"id": 0, "name": "Itzal Resistance", "accent": Color(0.0, 0.90, 0.78, 1.0), "playable": true,
	 "atk": 30, "def": 55, "bonus": 10,
	 "icon": "res://assets/ui/faction_itzal.png", "units": "res://assets/ui/units_itzal.png",
	 "desc": "Warriors of Itzal: villagers, soldiers and jaguar riders."},
	{"id": 1, "name": "Enemy Decay", "accent": Color(0.65, 0.15, 0.90, 1.0), "playable": false,
	 "atk": 30, "def": 5, "bonus": 10,
	 "icon": "res://assets/ui/faction_decay.png", "units": "res://assets/ui/units_decay.png",
	 "desc": "Corrupted units that spread decay and corruption damage."},
	{"id": 2, "name": "Ix Architects", "accent": Color(0.85, 0.60, 0.10, 1.0), "playable": true,
	 "atk": 60, "def": 35, "bonus": 10,
	 "icon": "res://assets/ui/faction_ix.png", "units": "res://assets/ui/units_ix.png",
	 "desc": "Technologically advanced units forged from obsidian lattice."},
]

var _difficulties: Array[Dictionary] = [
	{"key": "easy", "label": "EASY", "color": Color(0.15, 0.72, 0.28, 1.0),
	 "sub": "Plentiful resources, passive enemy."},
	{"key": "normal", "label": "NORMAL", "color": Color(0.88, 0.62, 0.08, 1.0),
	 "sub": "Balanced economy and enemy pressure."},
	{"key": "hard", "label": "HARD", "color": Color(0.82, 0.15, 0.12, 1.0),
	 "sub": "Lean economy, aggressive enemy waves."},
]

var selected_map: String = "Jungle Basin"
var selected_faction_id: int = 0
var selected_difficulty: String = "normal"

var _map_preview: ColorRect = null
var _map_preview_tex: TextureRect = null
var _map_name_label: Label = null
var _map_button_styles: Dictionary = {}    # name -> StyleBoxFlat
var _faction_card_styles: Dictionary = {}  # id -> StyleBoxFlat
var _difficulty_styles: Dictionary = {}    # key -> StyleBoxFlat

@onready var _bg: TextureRect = $BGImage

func _ready() -> void:
	if _bg != null and ResourceLoader.exists(BG_IMAGE):
		_bg.texture = load(BG_IMAGE)
	_build_title()
	_build_body()
	_build_bottom_bar()
	_refresh_map_styles()
	_refresh_faction_styles()
	_refresh_difficulty_styles()
	_update_map_preview()

# ---------------------------------------------------------------------------
# Title
# ---------------------------------------------------------------------------
func _build_title() -> void:
	var title := Label.new()
	title.text = "SKIRMISH SETUP"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", ACCENT)
	title.add_theme_font_size_override("font_size", 52)
	title.add_theme_font_override("font", _spaced_font(8))
	add_child(title)
	title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 16
	title.offset_bottom = 84

# ---------------------------------------------------------------------------
# Body (3 columns)
# ---------------------------------------------------------------------------
func _build_body() -> void:
	var margin := MarginContainer.new()
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 96)
	margin.add_theme_constant_override("margin_bottom", 96)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	margin.add_child(hbox)

	hbox.add_child(_build_map_column())
	hbox.add_child(_build_faction_column())
	hbox.add_child(_build_difficulty_column())

func _build_map_column() -> PanelContainer:
	var panel := _make_panel(220.0, false)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)

	v.add_child(_header("MAP"))

	_map_preview = ColorRect.new()
	_map_preview.custom_minimum_size = Vector2(200, 120)
	_map_preview.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(_map_preview)

	_map_preview_tex = TextureRect.new()
	_map_preview_tex.custom_minimum_size = Vector2(200, 150)
	_map_preview_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_map_preview_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_map_preview_tex.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_map_preview_tex.visible = false
	v.add_child(_map_preview_tex)

	_map_name_label = Label.new()
	_map_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_map_name_label.add_theme_color_override("font_color", WHITE)
	_map_name_label.add_theme_font_size_override("font_size", 13)
	v.add_child(_map_name_label)

	for m in _maps:
		var name_str: String = m["name"]
		var sb := _new_style(4)
		_map_button_styles[name_str] = sb
		var btn := Button.new()
		btn.text = name_str
		btn.custom_minimum_size = Vector2(0, 36)
		btn.add_theme_color_override("font_color", WHITE)
		btn.add_theme_color_override("font_hover_color", WHITE)
		btn.add_theme_color_override("font_pressed_color", WHITE)
		btn.add_theme_color_override("font_focus_color", WHITE)
		btn.add_theme_font_size_override("font_size", 13)
		for state in ["normal", "hover", "pressed", "focus"]:
			btn.add_theme_stylebox_override(state, sb)
		btn.pressed.connect(_on_map_selected.bind(name_str))
		v.add_child(btn)

	return panel

func _build_faction_column() -> PanelContainer:
	var panel := _make_panel(520.0, true)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)

	v.add_child(_header("FACTION"))

	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 8)
	cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(cards)

	for data in _factions:
		cards.add_child(_make_faction_card(data))

	return panel

func _make_faction_card(data: Dictionary) -> PanelContainer:
	var fid: int = data["id"]
	var accent: Color = data["accent"]
	var playable: bool = data["playable"]

	var sb := _new_style(4)
	_faction_card_styles[fid] = sb

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", sb)
	card.custom_minimum_size = Vector2(160, 0)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.gui_input.connect(_on_faction_input.bind(fid))

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	card.add_child(v)

	var icon_path: String = String(data.get("icon", ""))
	if icon_path != "" and ResourceLoader.exists(icon_path):
		var icon_tex := TextureRect.new()
		icon_tex.texture = load(icon_path)
		icon_tex.custom_minimum_size = Vector2(0, 110)
		icon_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		v.add_child(icon_tex)
	else:
		var icon := ColorRect.new()
		icon.color = accent
		icon.custom_minimum_size = Vector2(72, 72)
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(icon)

	var name_lbl := Label.new()
	name_lbl.text = data["name"]
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_color_override("font_color", accent)
	name_lbl.add_theme_font_size_override("font_size", 14)
	v.add_child(name_lbl)

	var units_path: String = String(data.get("units", ""))
	if units_path != "" and ResourceLoader.exists(units_path):
		var units_tex := TextureRect.new()
		units_tex.texture = load(units_path)
		units_tex.custom_minimum_size = Vector2(0, 54)
		units_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		units_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		v.add_child(units_tex)

	var chips := HBoxContainer.new()
	chips.alignment = BoxContainer.ALIGNMENT_CENTER
	chips.add_theme_constant_override("separation", 6)
	chips.add_child(_chip("ATK %d" % int(data["atk"]), Color(0.9, 0.35, 0.2, 1.0)))
	chips.add_child(_chip("DEF %d" % int(data["def"]), accent))
	chips.add_child(_chip("+%d" % int(data["bonus"]), Color(0.4, 0.8, 0.4, 1.0)))
	v.add_child(chips)

	var desc := Label.new()
	desc.text = data["desc"]
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.add_theme_color_override("font_color", TEXT_MUTED)
	desc.add_theme_font_size_override("font_size", 11)
	desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(desc)

	if not playable:
		var ov := ColorRect.new()
		ov.color = Color(0.0, 0.0, 0.0, 0.55)
		ov.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(ov)
		var locked := Label.new()
		locked.text = "Not playable yet"
		locked.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		locked.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		locked.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55, 1.0))
		locked.add_theme_font_size_override("font_size", 11)
		ov.add_child(locked)
		locked.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		locked.offset_bottom = -10.0

	return card

func _build_difficulty_column() -> PanelContainer:
	var panel := _make_panel(220.0, false)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)

	v.add_child(_header("DIFFICULTY"))

	for data in _difficulties:
		var key: String = data["key"]
		var color: Color = data["color"]
		var sb := _new_style(4)
		_difficulty_styles[key] = sb

		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", sb)
		card.custom_minimum_size = Vector2(0, 90)
		card.size_flags_horizontal = Control.SIZE_FILL
		card.gui_input.connect(_on_difficulty_input.bind(key))

		var dv := VBoxContainer.new()
		dv.add_theme_constant_override("separation", 4)
		dv.alignment = BoxContainer.ALIGNMENT_CENTER
		card.add_child(dv)

		var label := Label.new()
		label.text = data["label"]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_color_override("font_color", color)
		label.add_theme_font_size_override("font_size", 18)
		dv.add_child(label)

		var sub := Label.new()
		sub.text = data["sub"]
		sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub.add_theme_color_override("font_color", TEXT_MUTED)
		sub.add_theme_font_size_override("font_size", 11)
		dv.add_child(sub)

		v.add_child(card)

	var filler := Control.new()
	filler.size_flags_vertical = Control.SIZE_EXPAND_FILL
	filler.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(filler)

	return panel

# ---------------------------------------------------------------------------
# Bottom bar
# ---------------------------------------------------------------------------
func _build_bottom_bar() -> void:
	var bar := HBoxContainer.new()
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", 16)
	add_child(bar)
	bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_top = -72
	bar.offset_bottom = -16

	var start_btn := Button.new()
	start_btn.text = "START"
	start_btn.custom_minimum_size = Vector2(300, 52)
	start_btn.add_theme_font_size_override("font_size", 22)
	start_btn.add_theme_font_override("font", _spaced_font(4))
	start_btn.add_theme_color_override("font_color", ACCENT)
	start_btn.add_theme_color_override("font_hover_color", Color(0.6, 1.0, 0.95, 1.0))
	start_btn.add_theme_color_override("font_pressed_color", WHITE)
	start_btn.add_theme_color_override("font_focus_color", ACCENT)
	start_btn.add_theme_stylebox_override("normal", _button_style(Color(0.0, 0.90, 0.78, 0.15), ACCENT, 2))
	start_btn.add_theme_stylebox_override("hover", _button_style(Color(0.0, 0.90, 0.78, 0.28), ACCENT, 2))
	start_btn.add_theme_stylebox_override("pressed", _button_style(Color(0.0, 0.90, 0.78, 0.28), ACCENT, 2))
	start_btn.add_theme_stylebox_override("focus", _button_style(Color(0.0, 0.90, 0.78, 0.15), ACCENT, 2))
	start_btn.pressed.connect(_on_start_pressed)
	bar.add_child(start_btn)

	var back_btn := Button.new()
	back_btn.text = "BACK"
	back_btn.custom_minimum_size = Vector2(180, 52)
	back_btn.add_theme_font_size_override("font_size", 16)
	back_btn.add_theme_font_override("font", _spaced_font(2))
	back_btn.add_theme_color_override("font_color", Color(0.6, 0.68, 0.72, 1.0))
	back_btn.add_theme_color_override("font_hover_color", WHITE)
	back_btn.add_theme_color_override("font_focus_color", Color(0.6, 0.68, 0.72, 1.0))
	back_btn.add_theme_stylebox_override("normal", _button_style(Color(0, 0, 0, 0), Color(0.4, 0.5, 0.55, 0.6), 1))
	back_btn.add_theme_stylebox_override("hover", _button_style(Color(0, 0, 0, 0), Color(0.7, 0.75, 0.8, 0.8), 1))
	back_btn.add_theme_stylebox_override("pressed", _button_style(Color(0, 0, 0, 0), Color(0.7, 0.75, 0.8, 0.8), 1))
	back_btn.add_theme_stylebox_override("focus", _button_style(Color(0, 0, 0, 0), Color(0.4, 0.5, 0.55, 0.6), 1))
	back_btn.pressed.connect(_on_back_pressed)
	bar.add_child(back_btn)

	var ver := Label.new()
	ver.text = "v1.0.1"
	ver.add_theme_font_size_override("font_size", 11)
	ver.add_theme_color_override("font_color", Color(0.3, 0.35, 0.4, 0.8))
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(ver)
	ver.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	ver.offset_left = -90.0
	ver.offset_top = -26.0
	ver.offset_right = -12.0
	ver.offset_bottom = -8.0

# ---------------------------------------------------------------------------
# Selection handlers
# ---------------------------------------------------------------------------
func _on_map_selected(map_name: String) -> void:
	selected_map = map_name
	_refresh_map_styles()
	_update_map_preview()

func _on_faction_input(event: InputEvent, faction_id: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_faction_selected(faction_id)

func _on_faction_selected(faction_id: int) -> void:
	for data in _factions:
		if int(data["id"]) == faction_id:
			if not bool(data["playable"]):
				return
			break
	selected_faction_id = faction_id
	_refresh_faction_styles()

func _on_difficulty_input(event: InputEvent, key: String) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_difficulty_selected(key)

func _on_difficulty_selected(difficulty: String) -> void:
	selected_difficulty = difficulty
	_refresh_difficulty_styles()

# ---------------------------------------------------------------------------
# Style refresh
# ---------------------------------------------------------------------------
func _refresh_map_styles() -> void:
	for name_str in _map_button_styles:
		var sb: StyleBoxFlat = _map_button_styles[name_str]
		var selected: bool = (name_str == selected_map)
		if selected:
			sb.bg_color = Color(0.0, 0.90, 0.78, 0.12)
			sb.set_border_width_all(2)
			sb.border_color = ACCENT
		else:
			sb.bg_color = Color(0, 0, 0, 0)
			sb.set_border_width_all(1)
			sb.border_color = Color(0.0, 0.90, 0.78, 0.18)

func _refresh_faction_styles() -> void:
	for data in _factions:
		var fid: int = data["id"]
		var sb: StyleBoxFlat = _faction_card_styles[fid]
		var accent: Color = data["accent"]
		if fid == selected_faction_id:
			sb.bg_color = Color(accent.r, accent.g, accent.b, 0.10)
			sb.set_border_width_all(2)
			sb.border_color = accent
		else:
			sb.bg_color = Color(0.04, 0.07, 0.11, 0.7)
			sb.set_border_width_all(1)
			sb.border_color = DIM_BORDER

func _refresh_difficulty_styles() -> void:
	for data in _difficulties:
		var key: String = data["key"]
		var sb: StyleBoxFlat = _difficulty_styles[key]
		var color: Color = data["color"]
		if key == selected_difficulty:
			sb.bg_color = Color(color.r, color.g, color.b, 0.18)
			sb.set_border_width_all(2)
			sb.border_color = color
		else:
			sb.bg_color = Color(0, 0, 0, 0)
			sb.set_border_width_all(1)
			sb.border_color = DIM_BORDER

func _update_map_preview() -> void:
	var tex_path: String = "res://assets/ui/map_%s.png" % selected_map.to_lower().replace(" ", "_")
	var has_tex: bool = ResourceLoader.exists(tex_path)
	if _map_preview_tex != null:
		_map_preview_tex.visible = has_tex
		if has_tex:
			_map_preview_tex.texture = load(tex_path)
	if _map_preview != null:
		_map_preview.visible = not has_tex
	for m in _maps:
		if m["name"] == selected_map:
			if _map_preview != null:
				_map_preview.color = m["color"]
			if _map_name_label != null:
				_map_name_label.text = selected_map
			return

# ---------------------------------------------------------------------------
# Navigation
# ---------------------------------------------------------------------------
func _on_start_pressed() -> void:
	GameSettings.selected_map = selected_map
	GameSettings.faction_id = selected_faction_id
	GameSettings.difficulty = selected_difficulty
	# The match systems read player_faction_id (ix_spawner) — keep it in sync so
	# the chosen faction actually fields.
	GameSettings.player_faction_id = selected_faction_id
	ResourceManager.reset()
	SelectionManager.clear()
	SelectionManager.deselect_building()
	BuildingPlacer.cancel_placement()
	EnemyAI.reset()
	GameStats.reset()
	get_tree().change_scene_to_file(WORLD_SCENE)

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
func _make_panel(min_width: float, expand: bool) -> PanelContainer:
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL_BG
	sb.set_corner_radius_all(4)
	sb.set_border_width_all(1)
	sb.border_color = PANEL_BORDER
	sb.set_content_margin_all(12)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", sb)
	panel.custom_minimum_size = Vector2(min_width, 0)
	panel.size_flags_vertical = Control.SIZE_FILL
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL if expand else Control.SIZE_FILL
	return panel

func _new_style(radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(8)
	return sb

func _button_style(bg: Color, border: Color, width: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(4)
	sb.set_border_width_all(width)
	sb.border_color = border
	sb.set_content_margin_all(8)
	return sb

func _header(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", ACCENT)
	l.add_theme_font_size_override("font_size", 11)
	l.add_theme_font_override("font", _spaced_font(3))
	return l

func _chip(text: String, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_size_override("font_size", 11)
	return l

func _spaced_font(spacing: int) -> FontVariation:
	var fv := FontVariation.new()
	fv.spacing_glyph = spacing
	return fv
