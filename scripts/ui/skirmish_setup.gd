extends Control

## Skirmish Setup — clean dark UI built in code over the dimmed menu backdrop,
## matching the Campaign screen's identity (teal-bordered panels, simple rows).
## Three columns — MAP / FACTION / DIFFICULTY — each a selectable list; Start
## writes the choices to GameSettings, runs the match reset sequence (incl.
## ObjectiveManager.reset, P1-001) and loads the World.

const WORLD_SCENE: String = "res://scenes/world/World.tscn"
const MAIN_MENU_SCENE: String = "res://scenes/ui/MainMenu.tscn"
const BG_IMAGE: String = "res://assets/ui/menu_bg.png"

const ACCENT: Color = Color(0.0, 0.90, 0.78, 1.0)
const PANEL_BG: Color = Color(0.04, 0.07, 0.11, 0.82)
const PANEL_BORDER: Color = Color(0.0, 0.90, 0.78, 0.35)
const WHITE: Color = Color(0.95, 0.97, 0.98, 1.0)
const MUTED: Color = Color(0.62, 0.68, 0.74, 1.0)
const ROW_BG: Color = Color(0.10, 0.13, 0.17, 0.9)
const ROW_SEL_BG: Color = Color(0.0, 0.90, 0.78, 0.14)
const ROW_HOVER_BORDER: Color = Color(0.0, 0.90, 0.78, 0.65)

var _maps: Array[String] = ["Jungle Basin", "Sunken Reef", "Azure Coast", "Volcanic Crags"]

# atk/armor/hp mirror the REAL FactionData modifiers in faction_manager.gd.
var _factions: Array[Dictionary] = [
	{"id": 0, "name": "Itzal Resistance", "accent": Color(0.0, 0.90, 0.78, 1.0), "playable": true,
	 "atk": "ATK ×1.0", "armor": "ARM +0", "hp": "HP ×1.0",
	 "desc": "Balanced warriors. Ability: Jaguar's Vigor (mass heal). Tech: Jaguar Fury."},
	{"id": 1, "name": "Enemy Decay", "accent": Color(0.70, 0.55, 0.85, 1.0), "playable": true,
	 "atk": "ATK ×1.1", "armor": "ARM +0", "hp": "HP ×0.9",
	 "desc": "Glass-cannon corruption. Ability: Corruption Burst (AoE). Tech: Blight Surge."},
	{"id": 2, "name": "Ix Architects", "accent": Color(0.95, 0.70, 0.20, 1.0), "playable": true,
	 "atk": "ATK ×1.05", "armor": "ARM +1", "hp": "HP ×1.0",
	 "desc": "Elite obsidian-lattice strikers. Ability: Lattice Overcharge. No archers."},
]

var _difficulties: Array[Dictionary] = [
	{"key": "easy", "label": "EASY", "color": Color(0.35, 0.85, 0.40, 1.0),
	 "desc": "Plentiful resources, passive enemy."},
	{"key": "normal", "label": "NORMAL", "color": Color(0.95, 0.70, 0.15, 1.0),
	 "desc": "Balanced economy and enemy pressure."},
	{"key": "hard", "label": "HARD", "color": Color(0.90, 0.30, 0.25, 1.0),
	 "desc": "Lean economy, aggressive enemy waves."},
]

var selected_map: String = "Jungle Basin"
var selected_faction_id: int = 0
var selected_difficulty: String = "normal"

@onready var _bg: TextureRect = $BGImage

var _map_rows: Array[PanelContainer] = []
var _faction_rows: Array[PanelContainer] = []
var _diff_rows: Array[PanelContainer] = []

func _ready() -> void:
	if _bg != null and ResourceLoader.exists(BG_IMAGE):
		_bg.texture = load(BG_IMAGE)
	_build_title()
	_build_columns()
	_build_buttons()
	_refresh_rows(_map_rows, _maps.find(selected_map))
	_refresh_rows(_faction_rows, selected_faction_id)
	_refresh_rows(_diff_rows, _diff_index(selected_difficulty))
	SoundManager.start_menu_music()

# ── Title ──────────────────────────────────────────────────
func _build_title() -> void:
	var title := Label.new()
	title.text = "SKIRMISH SETUP"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", ACCENT)
	title.add_theme_font_size_override("font_size", 52)
	add_child(title)
	title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 24
	title.offset_bottom = 92

# ── Columns ────────────────────────────────────────────────
func _build_columns() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 28)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(row)
	row.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	row.grow_horizontal = Control.GROW_DIRECTION_BOTH
	row.grow_vertical = Control.GROW_DIRECTION_BOTH

	var map_inner: VBoxContainer = _column(row, "MAP", 300)
	for i in _maps.size():
		_add_map_row(map_inner, i)

	var fac_inner: VBoxContainer = _column(row, "FACTION", 560)
	for i in _factions.size():
		_add_faction_row(fac_inner, i)

	var diff_inner: VBoxContainer = _column(row, "DIFFICULTY", 320)
	for i in _difficulties.size():
		_add_diff_row(diff_inner, i)

## A titled column: header label + bordered panel; returns the inner VBox to
## which rows are added.
func _column(parent: HBoxContainer, header: String, min_w: float) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	col.custom_minimum_size = Vector2(min_w, 0)
	col.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	parent.add_child(col)

	var hdr := Label.new()
	hdr.text = header
	hdr.add_theme_color_override("font_color", ACCENT)
	hdr.add_theme_font_size_override("font_size", 18)
	col.add_child(hdr)

	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL_BG
	sb.set_corner_radius_all(4)
	sb.set_border_width_all(1)
	sb.border_color = PANEL_BORDER
	sb.set_content_margin_all(14)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", sb)
	col.add_child(panel)

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 8)
	panel.add_child(inner)
	return inner

# ── Row construction ───────────────────────────────────────
func _row_stylebox(selected: bool, hovered: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = ROW_SEL_BG if selected else ROW_BG
	sb.set_corner_radius_all(3)
	sb.set_border_width_all(2 if selected else 1)
	sb.border_color = ACCENT if selected else (ROW_HOVER_BORDER if hovered else PANEL_BORDER)
	sb.set_content_margin_all(10)
	return sb

## Wires a PanelContainer as a clickable, hoverable row in `store`.
func _wire_row(pc: PanelContainer, store: Array, on_pick: Callable) -> void:
	pc.mouse_filter = Control.MOUSE_FILTER_STOP
	pc.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	pc.add_theme_stylebox_override("panel", _row_stylebox(false, false))
	var idx: int = store.size()
	store.append(pc)
	pc.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			on_pick.call())
	pc.mouse_entered.connect(func() -> void: _hover_row(store, idx, true))
	pc.mouse_exited.connect(func() -> void: _hover_row(store, idx, false))

func _add_map_row(inner: VBoxContainer, i: int) -> void:
	var pc := PanelContainer.new()
	var mc := _row_margin()
	pc.add_child(mc)
	var lbl := Label.new()
	lbl.text = _maps[i]
	lbl.add_theme_color_override("font_color", WHITE)
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mc.add_child(lbl)
	inner.add_child(pc)
	_wire_row(pc, _map_rows, _on_map_picked.bind(i))

func _add_faction_row(inner: VBoxContainer, i: int) -> void:
	var data: Dictionary = _factions[i]
	var pc := PanelContainer.new()
	var mc := _row_margin()
	pc.add_child(mc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mc.add_child(v)

	var name_lbl := Label.new()
	name_lbl.text = data["name"]
	name_lbl.add_theme_color_override("font_color", data["accent"])
	name_lbl.add_theme_font_size_override("font_size", 17)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(name_lbl)

	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", 10)
	stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for pair in [[String(data["atk"]), Color(0.95, 0.55, 0.35)], [String(data["armor"]), ACCENT], [String(data["hp"]), Color(0.50, 0.85, 0.50)]]:
		var s := Label.new()
		s.text = pair[0]
		s.add_theme_font_size_override("font_size", 12)
		s.add_theme_color_override("font_color", pair[1])
		s.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stats.add_child(s)
	v.add_child(stats)

	var desc := Label.new()
	desc.text = data["desc"]
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_color_override("font_color", MUTED)
	desc.add_theme_font_size_override("font_size", 12)
	desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(desc)

	inner.add_child(pc)
	_wire_row(pc, _faction_rows, _on_faction_picked.bind(int(data["id"])))

func _add_diff_row(inner: VBoxContainer, i: int) -> void:
	var data: Dictionary = _difficulties[i]
	var pc := PanelContainer.new()
	var mc := _row_margin()
	pc.add_child(mc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mc.add_child(v)

	var name_lbl := Label.new()
	name_lbl.text = data["label"]
	name_lbl.add_theme_color_override("font_color", data["color"])
	name_lbl.add_theme_font_size_override("font_size", 17)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(name_lbl)

	var desc := Label.new()
	desc.text = data["desc"]
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_color_override("font_color", MUTED)
	desc.add_theme_font_size_override("font_size", 12)
	desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(desc)

	inner.add_child(pc)
	_wire_row(pc, _diff_rows, _on_difficulty_picked.bind(String(data["key"])))

func _row_margin() -> MarginContainer:
	var mc := MarginContainer.new()
	mc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mc.add_theme_constant_override("margin_left", 4)
	mc.add_theme_constant_override("margin_right", 4)
	mc.add_theme_constant_override("margin_top", 2)
	mc.add_theme_constant_override("margin_bottom", 2)
	return mc

# ── Selection ──────────────────────────────────────────────
func _diff_index(key: String) -> int:
	for i in _difficulties.size():
		if String(_difficulties[i]["key"]) == key:
			return i
	return 0

func _refresh_rows(rows: Array, sel_idx: int) -> void:
	for i in rows.size():
		(rows[i] as PanelContainer).add_theme_stylebox_override("panel", _row_stylebox(i == sel_idx, false))

func _hover_row(rows: Array, idx: int, hovered: bool) -> void:
	# Don't override the selected row's emphasis on hover.
	var sel: int = _selected_index_for(rows)
	if idx == sel:
		return
	(rows[idx] as PanelContainer).add_theme_stylebox_override("panel", _row_stylebox(false, hovered))

func _selected_index_for(rows: Array) -> int:
	if rows == _map_rows:
		return _maps.find(selected_map)
	if rows == _faction_rows:
		return selected_faction_id
	return _diff_index(selected_difficulty)

func _on_map_picked(i: int) -> void:
	selected_map = _maps[i]
	_refresh_rows(_map_rows, i)

func _on_faction_picked(faction_id: int) -> void:
	for data in _factions:
		if int(data["id"]) == faction_id and not bool(data["playable"]):
			return
	selected_faction_id = faction_id
	_refresh_rows(_faction_rows, faction_id)

func _on_difficulty_picked(key: String) -> void:
	selected_difficulty = key
	_refresh_rows(_diff_rows, _diff_index(key))

# ── Bottom buttons ─────────────────────────────────────────
func _build_buttons() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(row)
	row.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	row.grow_horizontal = Control.GROW_DIRECTION_BOTH
	row.offset_top = -86.0
	row.offset_bottom = -34.0
	row.offset_left = -220.0
	row.offset_right = 220.0
	row.add_child(_action_button("START", ACCENT, _on_start_pressed))
	row.add_child(_action_button("BACK", MUTED, _on_back_pressed))

func _action_button(text: String, color: Color, on_press: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(180, 48)
	btn.add_theme_color_override("font_color", color)
	btn.add_theme_color_override("font_hover_color", WHITE)
	btn.add_theme_font_size_override("font_size", 20)
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL_BG
	sb.set_corner_radius_all(4)
	sb.set_border_width_all(1)
	sb.border_color = Color(color.r, color.g, color.b, 0.55)
	var hb := sb.duplicate() as StyleBoxFlat
	hb.bg_color = Color(color.r, color.g, color.b, 0.14)
	hb.border_color = color
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", hb)
	btn.add_theme_stylebox_override("pressed", hb)
	btn.pressed.connect(on_press)
	return btn

# ── Navigation ─────────────────────────────────────────────
func _on_start_pressed() -> void:
	GameSettings.selected_map = selected_map
	GameSettings.difficulty = selected_difficulty
	GameSettings.player_faction_id = selected_faction_id
	ResourceManager.reset()
	SelectionManager.clear()
	SelectionManager.deselect_building()
	BuildingPlacer.cancel_placement()
	EnemyAI.reset()
	GameStats.reset()
	ObjectiveManager.reset()  # P1-001: skirmish must reset objectives too
	get_tree().change_scene_to_file(WORLD_SCENE)

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
