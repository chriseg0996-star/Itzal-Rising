extends Control

## Skirmish setup — minimalist three-column picker on the shared MenuKit
## language: MAP / FACTION / DIFFICULTY as text-only items whose selected state
## is the persistent neon bar. Start writes the choices to GameSettings, runs
## the match reset chain (incl. ObjectiveManager.reset, P1-001) and loads World.

const WORLD_SCENE: String = "res://scenes/world/World.tscn"
const MAIN_MENU_SCENE: String = "res://scenes/ui/MainMenu.tscn"

var _maps: Array[String] = ["Jungle Basin", "Sunken Reef", "Azure Coast", "Volcanic Crags"]

# atk/armor/hp mirror the REAL FactionData modifiers in faction_manager.gd.
var _factions: Array[Dictionary] = [
	{"id": 0, "name": "ITZAL RESISTANCE", "accent": Color(0.0, 0.90, 0.78, 1.0),
	 "stats": "ATK ×1.0 · ARM +0 · HP ×1.0",
	 "desc": "Balanced warriors. Jaguar's Vigor (mass heal)."},
	{"id": 1, "name": "ENEMY DECAY", "accent": Color(0.70, 0.55, 0.85, 1.0),
	 "stats": "ATK ×1.1 · ARM +0 · HP ×0.9",
	 "desc": "Glass-cannon corruption. Corruption Burst (AoE)."},
	{"id": 2, "name": "IX ARCHITECTS", "accent": Color(0.95, 0.70, 0.20, 1.0),
	 "stats": "ATK ×1.05 · ARM +1 · HP ×1.0",
	 "desc": "Obsidian-lattice elite. Lattice Overcharge. No archers."},
]

var _difficulties: Array[Dictionary] = [
	{"key": "easy", "label": "EASY", "desc": "Plentiful resources, passive enemy."},
	{"key": "normal", "label": "NORMAL", "desc": "Balanced economy and pressure."},
	{"key": "hard", "label": "HARD", "desc": "Lean economy, aggressive waves."},
]

var selected_map: String = "Jungle Basin"
var selected_faction_id: int = 0
var selected_difficulty: String = "normal"

var _map_btns: Array[Button] = []
var _fac_btns: Array[Button] = []
var _diff_btns: Array[Button] = []

func _ready() -> void:
	MenuKit.build_background(self)
	MenuKit.build_header(self, "SKIRMISH")
	_build_columns()
	_build_start()
	MenuKit.build_back(self, func() -> void: get_tree().change_scene_to_file(MAIN_MENU_SCENE))
	MenuKit.build_version(self)
	_refresh_selection()
	SoundManager.start_menu_music()

# ── Columns ────────────────────────────────────────────────
func _build_columns() -> void:
	var map_col := _column(MenuKit.MENU_X, 0.30, "M A P")
	for i in _maps.size():
		var idx: int = i
		var btn := MenuKit.item(_maps[i], MenuKit.WHITE, func() -> void: _pick_map(idx), 18)
		_map_btns.append(btn)
		map_col.add_child(btn)

	var fac_col := _column(0.36, 0.62, "F A C T I O N")
	for i in _factions.size():
		var fid: int = int(_factions[i]["id"])
		var btn := MenuKit.item(String(_factions[i]["name"]), MenuKit.WHITE, func() -> void: _pick_faction(fid), 18)
		_fac_btns.append(btn)
		fac_col.add_child(btn)
		fac_col.add_child(_detail(String(_factions[i]["stats"]), String(_factions[i]["desc"]), _factions[i]["accent"] as Color))

	var diff_col := _column(0.68, 0.90, "D I F F I C U L T Y")
	for i in _difficulties.size():
		var key: String = String(_difficulties[i]["key"])
		var btn := MenuKit.item(String(_difficulties[i]["label"]), MenuKit.WHITE, func() -> void: _pick_difficulty(key), 18)
		_diff_btns.append(btn)
		diff_col.add_child(btn)
		diff_col.add_child(_detail("", String(_difficulties[i]["desc"]), MenuKit.MUTED))

func _column(x0: float, x1: float, header: String) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	add_child(v)
	v.anchor_left = x0
	v.anchor_right = x1
	v.anchor_top = 0.24
	v.anchor_bottom = 0.86
	v.add_child(MenuKit.section(header))
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 6)
	v.add_child(sp)
	return v

## Muted detail lines under a picker item (stats tinted, description grey).
func _detail(stats: String, desc: String, tint: Color) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if stats != "":
		var s := Label.new()
		s.text = stats
		s.add_theme_color_override("font_color", Color(tint.r, tint.g, tint.b, 0.75))
		s.add_theme_font_size_override("font_size", 12)
		s.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(s)
	var d := Label.new()
	d.text = desc
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.add_theme_color_override("font_color", MenuKit.MUTED)
	d.add_theme_font_size_override("font_size", 12)
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(d)
	# align under the item's text (normal stylebox indents 18px)
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 18)
	pad.add_theme_constant_override("margin_bottom", 10)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_child(box)
	var wrap := VBoxContainer.new()
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(pad)
	return wrap

# ── Selection ──────────────────────────────────────────────
func _pick_map(i: int) -> void:
	selected_map = _maps[i]
	_refresh_selection()

func _pick_faction(fid: int) -> void:
	selected_faction_id = fid
	_refresh_selection()

func _pick_difficulty(key: String) -> void:
	selected_difficulty = key
	_refresh_selection()

func _refresh_selection() -> void:
	for i in _map_btns.size():
		MenuKit.mark_selected(_map_btns[i], _maps[i] == selected_map)
	for i in _fac_btns.size():
		MenuKit.mark_selected(_fac_btns[i], int(_factions[i]["id"]) == selected_faction_id)
	for i in _diff_btns.size():
		MenuKit.mark_selected(_diff_btns[i], String(_difficulties[i]["key"]) == selected_difficulty)

# ── Start ──────────────────────────────────────────────────
func _build_start() -> void:
	var btn := MenuKit.item("START MATCH  →", MenuKit.ACCENT, _on_start_pressed, 22)
	add_child(btn)
	btn.anchor_left = 0.68
	btn.anchor_right = 0.92
	btn.anchor_top = 0.90
	btn.anchor_bottom = 0.90
	btn.offset_bottom = 46.0

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
