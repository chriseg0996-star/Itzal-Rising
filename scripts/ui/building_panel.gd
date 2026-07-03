extends CanvasLayer

## AoE4-style contextual COMMAND CARD (bottom-right). The grid's content is
## driven by the current selection:
##   villager selected  -> build tabs [ECONOMIC | MILITARY] of placeable buildings
##   own building       -> train slots + research (TC) + header with name/HP,
##                         plus a clickable production QUEUE strip (click = cancel)
##   military selection -> stance cells (Aggressive / Defensive / Hold)
##   nothing            -> hidden
## Existing global hotkeys (B/T/Y/... , Z/X/C) keep working; cells show them as
## chips. Built fully in code on the shared Basalt & Neon language.

const ACCENT: Color = Color(0.0, 0.90, 0.78, 1.0)
const PANEL_BG: Color = Color(0.07, 0.09, 0.12, 0.94)
const PANEL_BORDER: Color = Color(0.0, 0.85, 0.85, 0.35)
const WHITE: Color = Color(0.92, 0.95, 0.98, 1.0)
const MUTED: Color = Color(0.55, 0.62, 0.68, 1.0)
const CELL: float = 64.0
const COLS: int = 4

## Build-tab data: key = BuildingPlacer type, icon = assets/ui/icons/<icon>.png
## (text fallback when missing), hot = existing global hotkey.
const BUILDS: Dictionary = {
	"eco": [
		{"key": &"tc", "label": "Town Center", "short": "TC", "icon": "bld_tc", "hot": "T"},
		{"key": &"farm", "label": "Farm", "short": "Farm", "icon": "bld_farm", "hot": "F"},
		{"key": &"storehouse", "label": "Storehouse", "short": "Store", "icon": "bld_storehouse", "hot": "H"},
		{"key": &"house", "label": "House", "short": "House", "icon": "bld_house", "hot": "U"},
		{"key": &"pylon", "label": "Obsidian Pylon", "short": "Pylon", "icon": "bld_pylon", "hot": "P"},
	],
	"mil": [
		{"key": &"barracks", "label": "Barracks", "short": "Barrack", "icon": "bld_barracks", "hot": "B"},
		{"key": &"tower", "label": "Tower", "short": "Tower", "icon": "bld_tower", "hot": "Y"},
		{"key": &"monument", "label": "Monument", "short": "Monum.", "icon": "bld_monument", "hot": "M"},
		{"key": &"beacon", "label": "Ascension Beacon", "short": "Beacon", "icon": "bld_beacon", "hot": ""},
	],
}

const STANCES: Array[Dictionary] = [
	{"stance": CombatComponent.Stance.AGGRESSIVE, "label": "Aggressive", "short": "AGG", "hot": "Z"},
	{"stance": CombatComponent.Stance.DEFENSIVE, "label": "Defensive", "short": "DEF", "hot": "X"},
	{"stance": CombatComponent.Stance.HOLD, "label": "Hold Ground", "short": "HOLD", "hot": "C"},
]

var _card: PanelContainer = null
var _header: Label = null
var _queue_row: HBoxContainer = null
var _queue_bar: ProgressBar = null
var _tabs: HBoxContainer = null
var _grid: GridContainer = null

var _mode: String = "none"        # none | villager | military | building
var _tab: String = "eco"
var _building: Node = null
var _last_units: Array = []
var _poll: float = 0.0

func _ready() -> void:
	_build_card()
	SelectionManager.selection_changed.connect(_on_units_changed)
	SelectionManager.building_selected.connect(_on_building_selected)
	SelectionManager.building_deselected.connect(_on_building_deselected)
	_apply_mode("none")

# ── Card scaffold ──────────────────────────────────────────
func _build_card() -> void:
	_card = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL_BG
	sb.set_border_width_all(1)
	sb.border_color = PANEL_BORDER
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(10)
	_card.add_theme_stylebox_override("panel", sb)
	add_child(_card)
	_card.anchor_left = 1.0
	_card.anchor_top = 1.0
	_card.anchor_right = 1.0
	_card.anchor_bottom = 1.0
	# Bottom-centre, flush left of the minimap (AoE4 command-card position).
	_card.offset_left = -(CELL * COLS + 6.0 * (COLS - 1) + 20.0 + 240.0)
	_card.offset_right = -240.0
	_card.offset_top = -300.0   # fixed height — the card never jumps between contexts
	_card.offset_bottom = -16.0
	_card.grow_horizontal = 0
	_card.grow_vertical = 0

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_card.add_child(v)

	_header = Label.new()
	_header.add_theme_color_override("font_color", WHITE)
	_header.add_theme_font_size_override("font_size", 15)
	v.add_child(_header)

	_queue_row = HBoxContainer.new()
	_queue_row.add_theme_constant_override("separation", 4)
	v.add_child(_queue_row)

	_queue_bar = ProgressBar.new()
	_queue_bar.min_value = 0.0
	_queue_bar.max_value = 1.0
	_queue_bar.show_percentage = false
	_queue_bar.custom_minimum_size = Vector2(0, 6)
	var fill := StyleBoxFlat.new()
	fill.bg_color = ACCENT
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.05, 0.07, 0.10, 1.0)
	_queue_bar.add_theme_stylebox_override("fill", fill)
	_queue_bar.add_theme_stylebox_override("background", track)
	v.add_child(_queue_bar)

	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 6)
	v.add_child(_tabs)

	_grid = GridContainer.new()
	_grid.columns = COLS
	_grid.add_theme_constant_override("h_separation", 6)
	_grid.add_theme_constant_override("v_separation", 6)
	# Reserve two rows so the card doesn't jump height between contexts/tabs.
	_grid.custom_minimum_size = Vector2(0, CELL * 2.0 + 6.0)
	v.add_child(_grid)

# ── Selection routing ──────────────────────────────────────
func _on_units_changed(units: Array) -> void:
	_last_units = units
	if _building != null:
		return  # building context owns the card until deselected
	var has_villager: bool = false
	var has_military: bool = false
	for u in units:
		if not is_instance_valid(u):
			continue
		if u.is_in_group("villagers"):
			has_villager = true
		elif u.is_in_group("combat_units"):
			has_military = true
	if has_villager:
		_apply_mode("villager")
	elif has_military:
		_apply_mode("military")
	else:
		_apply_mode("none")

func _on_building_selected(b: Node) -> void:
	_building = b
	_apply_mode("building")

func _on_building_deselected() -> void:
	_building = null
	_on_units_changed(_last_units)

# ── Mode rendering ─────────────────────────────────────────
func _apply_mode(mode: String) -> void:
	_mode = mode
	_card.visible = mode != "none"
	_clear(_grid)
	_clear(_tabs)
	_clear(_queue_row)
	_queue_bar.visible = false
	_queue_row.visible = false
	_tabs.visible = false
	_header.visible = false
	match mode:
		"villager":
			_tabs.visible = true
			_build_tabs()
			_fill_build_grid()
		"military":
			_header.visible = true
			_header.text = "STANCE"
			_fill_stance_grid()
		"building":
			_header.visible = true
			_queue_row.visible = true
			_queue_bar.visible = true
			_refresh_building()

func _clear(node: Node) -> void:
	for c in node.get_children():
		c.queue_free()

# ── Villager: build tabs ───────────────────────────────────
func _build_tabs() -> void:
	for t in [["eco", "ECONOMIC"], ["mil", "MILITARY"]]:
		var key: String = t[0]
		var btn := Button.new()
		btn.text = t[1]
		btn.custom_minimum_size = Vector2(0, 26)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_size_override("font_size", 12)
		var active: bool = _tab == key
		btn.add_theme_color_override("font_color", ACCENT if active else MUTED)
		btn.add_theme_color_override("font_hover_color", ACCENT)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.10, 0.13, 0.17, 1.0) if active else Color(0.05, 0.07, 0.10, 1.0)
		sb.set_corner_radius_all(3)
		if active:
			sb.border_width_bottom = 2
			sb.border_color = ACCENT
		btn.add_theme_stylebox_override("normal", sb)
		btn.add_theme_stylebox_override("hover", sb)
		btn.add_theme_stylebox_override("pressed", sb)
		btn.pressed.connect(func() -> void:
			_tab = key
			_apply_mode("villager"))
		_tabs.add_child(btn)

func _fill_build_grid() -> void:
	var owned: Dictionary = _count_owned()
	for def in BUILDS[_tab]:
		var key: StringName = def["key"]
		var cost: String = BuildingPlacer.cost_text(key)
		var cell := _cell(String(def["short"]), String(def["icon"]), String(def["hot"]),
			"%s\n%s" % [def["label"], cost],
			func() -> void: BuildingPlacer.start_placement(key))
		var n: int = int(owned.get(String(def["label"]), 0))
		if n > 0:
			cell.add_child(_count_badge(n))
		_grid.add_child(cell)

## AoE4-style owned-count badge (bottom-left corner of the cell).
func _count_badge(n: int) -> Label:
	var lbl := Label.new()
	lbl.text = str(n)
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", WHITE)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	lbl.offset_left = 5.0
	lbl.offset_top = -16.0
	lbl.offset_right = 20.0
	lbl.offset_bottom = -3.0
	return lbl

func _count_owned() -> Dictionary:
	var out: Dictionary = {}
	for b in get_tree().get_nodes_in_group("player_buildings"):
		if not is_instance_valid(b) or bool(b.get("dying")):
			continue
		var name_str: String = String(b.get("building_name"))
		out[name_str] = int(out.get(name_str, 0)) + 1
	return out

# ── Military: stances ──────────────────────────────────────
func _fill_stance_grid() -> void:
	for s in STANCES:
		var stance: int = int(s["stance"])
		var lab: String = String(s["label"])
		var cell := _cell(String(s["short"]), "", String(s["hot"]), lab,
			func() -> void: SelectionManager.apply_stance(stance, lab))
		_grid.add_child(cell)

# ── Building: header + queue + train/research ──────────────
func _refresh_building() -> void:
	if _building == null or not is_instance_valid(_building):
		_building = null
		_apply_mode("none")
		return
	var b: Node = _building
	_header.text = "%s   %d/%d HP" % [String(b.get("building_name")), int(b.get("hp")), int(b.get("max_hp"))]
	_refresh_queue(b)
	_clear(_grid)
	# Train slots.
	for slot in 4:
		if b.has_method("has_train_slot") and b.has_train_slot(slot):
			var label: String = b.get_train_label(slot)
			var cost: String = b.get_train_cost_label(slot)
			var s: int = slot
			_grid.add_child(_cell(label, _unit_icon(label), "",
				"Train %s\n%s" % [label, cost],
				func() -> void: b.try_queue_training(s)))
	# Research (player TC only).
	if _is_player_tc(b):
		_grid.add_child(_research_cell(b, "atk", "ATK"))
		_grid.add_child(_research_cell(b, "armor", "ARM"))
		_grid.add_child(_research_cell(b, "cavalry", "CAV"))
		_grid.add_child(_era_cell(b))

func _refresh_queue(b: Node) -> void:
	_clear(_queue_row)
	var q: Array = b.get("queue") if b.get("queue") is Array else []
	for i in q.size():
		var entry: Dictionary = q[i]
		var name_str: String = String(entry.get("label", entry.get("research_id", "?")))
		var slot := Button.new()
		slot.custom_minimum_size = Vector2(42, 30)
		slot.text = name_str.left(3).to_upper()
		slot.tooltip_text = "%s — click to cancel" % name_str
		slot.add_theme_font_size_override("font_size", 10)
		slot.add_theme_color_override("font_color", ACCENT if i == 0 else MUTED)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.05, 0.07, 0.10, 1.0)
		sb.set_border_width_all(1)
		sb.border_color = Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.5 if i == 0 else 0.2)
		sb.set_corner_radius_all(3)
		slot.add_theme_stylebox_override("normal", sb)
		slot.add_theme_stylebox_override("hover", sb)
		var idx: int = i
		slot.pressed.connect(func() -> void:
			if _building != null and is_instance_valid(_building):
				_building.cancel_at(idx))
		_queue_row.add_child(slot)
	# Front-item progress.
	if q.is_empty():
		_queue_bar.value = 0.0
	else:
		var dur: float = float((q[0] as Dictionary).get("duration", 1.0))
		var left: float = float(b.get("production_timer"))
		_queue_bar.value = clampf(1.0 - left / maxf(dur, 0.01), 0.0, 1.0)

func _is_player_tc(b: Node) -> bool:
	return String(b.get("building_name")) == "Town Center" \
		and b.get("faction_id") != null \
		and FactionManager.is_player_faction(int(b.get("faction_id")))

func _research_cell(b: Node, id: String, tag: String) -> Button:
	var levels: Array = b.RESEARCH[id]["levels"]
	var lvl: int = GameStats.get_research_level(id)
	var maxed: bool = lvl >= levels.size()
	var tip: String = "%s research" % tag
	if not maxed:
		var tier: Dictionary = levels[lvl]
		tip = "%s %s\n%s" % [tag, "II" if lvl == 1 else "I", _cost_str(tier["cost"])]
	var cell := _cell("%s%s" % [tag, " MAX" if maxed else " %s" % ("II" if lvl == 1 else "I")], "", "", tip,
		func() -> void: b.try_queue_research(id))
	if maxed:
		cell.disabled = true
	return cell

func _era_cell(b: Node) -> Button:
	var levels: Array = b.RESEARCH["era"]["levels"]
	var lvl: int = GameStats.get_research_level("era")
	var maxed: bool = lvl >= levels.size()
	var tip: String = "Era maxed"
	if not maxed:
		tip = "Advance to Era %d\n%s" % [GameStats.era + 1, _cost_str(levels[lvl]["cost"])]
	var cell := _cell("ERA %s" % ("MAX" if maxed else str(GameStats.era + 1)), "", "", tip,
		func() -> void: b.try_queue_research("era"))
	if maxed:
		cell.disabled = true
	return cell

func _cost_str(cost: Dictionary) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for type in cost:
		parts.append("%d%s" % [int(cost[type]), "W" if String(type) == "madera" else "G"])
	return ", ".join(parts)

# ── Cell factory ───────────────────────────────────────────
func _cell(label: String, icon_key: String, hotkey: String, tooltip: String, on_press: Callable) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(CELL, CELL)
	btn.tooltip_text = tooltip
	btn.clip_text = true
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.13, 0.17, 1.0)
	sb.set_border_width_all(1)
	sb.border_color = Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.30)
	sb.set_corner_radius_all(4)
	var hb: StyleBoxFlat = sb.duplicate()
	hb.bg_color = Color(0.0, 0.55, 0.50, 0.35)
	hb.border_color = ACCENT
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", hb)
	btn.add_theme_stylebox_override("pressed", hb)
	btn.add_theme_stylebox_override("focus", sb)
	# AoE4-style: icon-only cells (name + cost live in the tooltip); text is the
	# fallback when no icon exists. Keeps every cell exactly CELL-sized.
	var icon_path: String = "res://assets/ui/icons/%s.png" % icon_key
	if icon_key != "" and ResourceLoader.exists(icon_path):
		btn.icon = load(icon_path)
		btn.expand_icon = true
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
		btn.add_theme_constant_override("icon_max_width", 44)
	else:
		btn.text = _short(label)
		btn.add_theme_font_size_override("font_size", 10)
	btn.add_theme_color_override("font_color", WHITE)
	btn.add_theme_color_override("font_hover_color", WHITE)
	btn.pressed.connect(on_press)
	if hotkey != "":
		btn.add_child(_chip(hotkey))
	return btn

func _short(label: String) -> String:
	return label if label.length() <= 10 else label.split(" ")[0]

func _chip(key: String) -> Label:
	var lbl := Label.new()
	lbl.text = key
	lbl.add_theme_font_size_override("font_size", 9)
	lbl.add_theme_color_override("font_color", Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.9))
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	lbl.offset_left = -14.0
	lbl.offset_top = 2.0
	lbl.offset_right = -4.0
	lbl.offset_bottom = 14.0
	return lbl

func _unit_icon(label: String) -> String:
	var l: String = label.to_lower()
	if l.contains("archer"):
		return "unit_archer"
	if l.contains("raider") or l.contains("lancer") or l.contains("rider"):
		return "unit_raider"
	if l.contains("guard"):
		return "unit_guard"
	if l.contains("villager") or l.contains("weaver"):
		return "unit_villager"
	if l.contains("catapult") or l.contains("cannon") or l.contains("engine") or l.contains("siege"):
		return "unit_soldier"
	return "unit_soldier"

# ── Poll: keep the live views fresh ────────────────────────
func _process(delta: float) -> void:
	_poll += delta
	if _mode == "building":
		if _poll >= 0.25:
			_poll = 0.0
			_refresh_building()
	elif _mode == "villager":
		# Refresh owned-count badges once a second.
		if _poll >= 1.0:
			_poll = 0.0
			_clear(_grid)
			_fill_build_grid()
