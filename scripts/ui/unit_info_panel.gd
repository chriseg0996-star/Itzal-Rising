class_name UnitInfoPanel
extends PanelContainer

## Bottom-left info card for whatever the player is looking at: a single selected
## unit, a multi-selection count, or an inspected enemy unit/building (read-only).
## Shows a friendly name, the owner faction (in faction colour) and a live HP bar.
## Player buildings are shown by the BuildingPanel side panel instead.

const GOLD: Color = Color(0.784, 0.663, 0.29, 1.0)
const HP_GOOD: Color = Color(0.27, 0.86, 0.50)
const HP_LOW: Color = Color(0.85, 0.2, 0.15)
const MUTED: Color = Color(0.55, 0.65, 0.7)

@onready var _name_label: Label = $VBox/NameLabel
@onready var _owner_label: Label = $VBox/OwnerLabel
@onready var _hp_bar: ProgressBar = $VBox/HPBar
@onready var _hp_label: Label = $VBox/HPLabel
@onready var _multi_label: Label = $VBox/MultiLabel

var _units: Array = []
var _inspect: Node = null
var _building: Node = null
var _focus: Node = null
var _hp_fill: StyleBoxFlat = null
var _refresh_timer: float = 0.0

var _emblem: TextureRect = null
var _icon: TextureRect = null
var _status_label: Label = null
var _queue_row: HBoxContainer = null

func _ready() -> void:
	add_theme_stylebox_override("panel", MenuKit.flat_box(8.0, 0.11, true))
	# Small entity icon (mockup: circular icon, never a big portrait), floating
	# at the name row's left edge.
	_icon = TextureRect.new()
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name_label.add_child(_icon)
	_icon.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	_icon.offset_left = 2.0
	_icon.offset_right = 40.0
	_icon.offset_top = -18.0
	_icon.offset_bottom = 20.0
	_icon.visible = false
	# Live activity line ("Gathering Wood 12 / 20", "Under construction").
	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 11)
	_status_label.add_theme_color_override("font_color", Color(0.0, 0.90, 0.78, 0.9))
	$VBox.add_child(_status_label)
	_status_label.hide()
	# Production queue chips (head slot shows a progress underline).
	_queue_row = HBoxContainer.new()
	_queue_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_queue_row.add_theme_constant_override("separation", 4)
	$VBox.add_child(_queue_row)
	_queue_row.hide()
	SelectionManager.building_selected.connect(_on_building_selected)
	SelectionManager.building_deselected.connect(_on_building_deselected)
	# Faction emblem medallion, docked at the panel's right edge.
	_emblem = TextureRect.new()
	_emblem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_emblem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_emblem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Parent to the name label: PanelContainer force-layouts direct children,
	# but a Label doesn't — so the medallion can float at the row's right edge.
	_name_label.add_child(_emblem)
	_emblem.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	_emblem.offset_left = -46.0
	_emblem.offset_right = -2.0
	_emblem.offset_top = -20.0
	_emblem.offset_bottom = 24.0
	_emblem.visible = false
	SelectionManager.selection_changed.connect(_on_selection_changed)
	if SelectionManager.has_signal("inspect_changed"):
		SelectionManager.inspect_changed.connect(_on_inspect_changed)
	# Own copy of the fill stylebox so we can recolour it by HP without touching
	# the shared resource.
	var fill: StyleBox = _hp_bar.get_theme_stylebox("fill")
	if fill != null:
		_hp_fill = fill.duplicate() as StyleBoxFlat
		_hp_bar.add_theme_stylebox_override("fill", _hp_fill)
	_show_empty()

func _process(delta: float) -> void:
	if _focus == null:
		# Multi-selection: keep the per-unit HP strips live.
		if _units.size() > 1:
			_refresh_timer += delta
			if _refresh_timer >= 0.5:
				_refresh_timer = 0.0
				_units = _units.filter(func(u) -> bool: return is_instance_valid(u))
				if _units.size() > 1:
					_build_type_chips(_units)
				else:
					_relayout()
		return
	if not is_instance_valid(_focus):
		_focus = null
		_inspect = null
		_building = null
		_relayout()
		return
	_refresh_hp(_focus)
	# Status + queue change over time even with a static selection.
	_refresh_timer += delta
	if _refresh_timer >= 0.25:
		_refresh_timer = 0.0
		var d: Dictionary = SelectionHUDData.build(_focus)
		_set_status(String(d["status"]))
		_set_queue(d["queue"] as Array)
		_fit_single()

func _on_selection_changed(units: Array) -> void:
	_units = units
	if units.size() > 0:
		_inspect = null
	_relayout()

func _on_inspect_changed(node: Node) -> void:
	_inspect = node
	if node != null:
		_units = []
	_relayout()

func _on_building_selected(b: Node) -> void:
	_building = b
	_relayout()

func _on_building_deselected() -> void:
	_building = null
	_relayout()

func _relayout() -> void:
	if _building != null and is_instance_valid(_building):
		_focus = _building
		_show_single(_building)
	elif _inspect != null and is_instance_valid(_inspect):
		_focus = _inspect
		_show_single(_inspect)
	elif _units.size() == 1:
		_focus = _units[0]
		_show_single(_focus)
	elif _units.size() > 1:
		_focus = null
		_show_multi(_units)
	else:
		_focus = null
		_show_empty()

## Layout is owned by the BottomConsole's HBox — sections have fixed geometry.
func _set_height(_h: float) -> void:
	pass

## Nothing selected: blank the section but keep it in the console frame.
func _show_empty() -> void:
	_name_label.hide()
	_owner_label.hide()
	_hp_bar.hide()
	_hp_label.hide()
	_multi_label.hide()
	_status_label.hide()
	_queue_row.hide()
	if _type_row != null:
		_type_row.hide()
	if _emblem != null:
		_emblem.visible = false
	_icon.visible = false

func _show_single(node: Node) -> void:
	_multi_label.hide()
	if _type_row != null:
		_type_row.hide()
	_name_label.show()
	_owner_label.show()
	_hp_bar.show()
	_hp_label.show()
	var d: Dictionary = SelectionHUDData.build(node)
	var dname: String = String(d["name"])
	var role: String = String(d["subtitle"])
	# Compact 224px panel: name alone on the title row; role + stats share the
	# small line under it.
	_name_label.text = dname
	# Small entity icon (never a big portrait).
	var icon_path: String = String(d["icon"])
	_icon.visible = icon_path != ""
	if icon_path != "":
		_icon.texture = load(icon_path)
	_set_owner(node)
	var parts: PackedStringArray = PackedStringArray()
	if role != "":
		parts.append(role)
	for s in (d["stats"] as Array):
		parts.append("%s %s" % [String(s["label"]), str(s["value"])])
	if not parts.is_empty():
		_owner_label.text += " · %s" % " · ".join(parts)
	_set_status(String(d["status"]))
	_set_queue(d["queue"] as Array)
	_fit_single()
	_refresh_hp(node)
	show()

func _fit_single() -> void:
	var h: float = 96.0
	if _status_label.visible:
		h += 16.0
	if _queue_row.visible:
		h += 24.0
	_set_height(h)

func _set_status(text: String) -> void:
	_status_label.visible = text != ""
	_status_label.text = text

## Queue chips: head slot gets a gold border + inline percent; rest are muted.
func _set_queue(queue: Array) -> void:
	for c in _queue_row.get_children():
		c.queue_free()
	_queue_row.visible = not queue.is_empty()
	for i in queue.size():
		var item: Dictionary = queue[i]
		var lbl := Label.new()
		var progress: float = float(item.get("progress", -1.0))
		lbl.text = String(item["label"]) if progress < 0.0 \
			else "%s %d%%" % [String(item["label"]), int(progress * 100.0)]
		lbl.add_theme_font_size_override("font_size", 10)
		lbl.add_theme_color_override("font_color",
			Color(0.92, 0.95, 0.98, 1) if i == 0 else MUTED)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.05, 0.07, 0.10, 1.0)
		sb.set_border_width_all(1)
		sb.border_color = GOLD if i == 0 else Color(0.0, 0.85, 0.85, 0.2)
		sb.set_corner_radius_all(3)
		sb.content_margin_left = 6.0
		sb.content_margin_right = 6.0
		sb.content_margin_top = 2.0
		sb.content_margin_bottom = 2.0
		lbl.add_theme_stylebox_override("normal", sb)
		_queue_row.add_child(lbl)

func _show_multi(units: Array) -> void:
	# Compact: just the per-type unit cards (each carries its own count).
	_set_height(80.0)
	if _emblem != null:
		_emblem.visible = false
	_icon.visible = false
	_status_label.hide()
	_queue_row.hide()
	_name_label.hide()
	_owner_label.hide()
	_hp_bar.hide()
	_hp_label.hide()
	_multi_label.hide()
	_build_type_chips(units)
	show()

var _type_row: Container = null

const MAX_UNIT_CARDS: int = 17

## AoE4-style: one small card per selected unit (icon + live HP strip);
## clicking a card selects just that unit. Overflow shows a "+N" tile.
func _build_type_chips(units: Array) -> void:
	if _type_row == null:
		var grid := GridContainer.new()
		grid.columns = 6
		grid.add_theme_constant_override("h_separation", 2)
		grid.add_theme_constant_override("v_separation", 2)
		$VBox.add_child(grid)
		_type_row = grid
	for c in _type_row.get_children():
		c.queue_free()
	var live: Array = units.filter(func(u) -> bool: return is_instance_valid(u))
	for i in mini(live.size(), MAX_UNIT_CARDS):
		_type_row.add_child(_unit_card(live[i]))
	if live.size() > MAX_UNIT_CARDS:
		var more := Label.new()
		more.text = "+%d" % (live.size() - MAX_UNIT_CARDS)
		more.custom_minimum_size = Vector2(25, 28)
		more.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		more.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		more.add_theme_font_size_override("font_size", 10)
		more.add_theme_color_override("font_color", MUTED)
		_type_row.add_child(more)
	_type_row.show()

func _unit_card(u: Node) -> Button:
	var card := Button.new()
	card.custom_minimum_size = Vector2(25, 28)
	card.tooltip_text = "%s — click to select only this unit" % _display_name(u)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.09, 0.12, 1.0)
	sb.set_border_width_all(1)
	sb.border_color = Color(0.0, 0.85, 0.85, 0.15)
	var hb: StyleBoxFlat = sb.duplicate()
	hb.border_color = Color(0.0, 0.90, 0.78, 0.8)
	card.add_theme_stylebox_override("normal", sb)
	card.add_theme_stylebox_override("hover", hb)
	card.add_theme_stylebox_override("pressed", hb)
	card.add_theme_stylebox_override("focus", sb)
	var icon_path: String = String(SelectionHUDData.build(u)["icon"])
	if icon_path != "":
		card.icon = load(icon_path)
		card.expand_icon = true
		card.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
		card.add_theme_constant_override("icon_max_width", 18)
	# Live HP strip along the bottom edge.
	var ratio: float = 1.0
	var stat := u.get_node_or_null("StatComponent") as StatComponent
	if stat != null:
		ratio = stat.get_health_ratio()
	var track := ColorRect.new()
	track.color = Color(0.05, 0.07, 0.10, 1.0)
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(track)
	track.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	track.offset_left = 2.0
	track.offset_right = -2.0
	track.offset_top = -4.0
	track.offset_bottom = -2.0
	var fill := ColorRect.new()
	fill.color = HP_LOW.lerp(HP_GOOD, ratio)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.add_child(fill)
	fill.anchor_right = clampf(ratio, 0.0, 1.0)
	fill.anchor_bottom = 1.0
	card.pressed.connect(func() -> void:
		if is_instance_valid(u):
			SelectionManager.select_only(u))
	return card

func _display_name(node: Node) -> String:
	return SelectionHUDData.display_name(node)

func _set_owner(node: Node) -> void:
	var fid_v: Variant = node.get("faction_id")
	if fid_v == null:
		_owner_label.hide()
		return
	var fid: int = int(fid_v)
	var em_path: String = "res://assets/ui/emblem_%d.png" % fid
	if _emblem != null and ResourceLoader.exists(em_path):
		_emblem.texture = load(em_path)
		_emblem.visible = true
	_owner_label.show()
	_owner_label.text = FactionManager.display_name_of(fid)
	var col: Color = MUTED
	var fac: FactionData = FactionManager.get_faction(fid)
	if fac != null:
		col = fac.primary_color
	_owner_label.add_theme_color_override("font_color", col)

func _refresh_hp(node: Node) -> void:
	var cur: float = 0.0
	var mx: float = 0.0
	var stat := node.get_node_or_null("StatComponent") as StatComponent
	if stat != null:
		mx = stat.max_health
		cur = stat.get_health_ratio() * stat.max_health
	else:
		var hp_v: Variant = node.get("hp")
		var max_v: Variant = node.get("max_hp")
		if hp_v == null or max_v == null:
			_hp_bar.hide()
			_hp_label.hide()
			return
		cur = float(hp_v)
		mx = float(max_v)
	_hp_bar.show()
	_hp_label.show()
	_hp_bar.max_value = mx
	_hp_bar.value = cur
	_hp_label.text = "%d / %d" % [roundi(cur), roundi(mx)]
	if _hp_fill != null and mx > 0.0:
		_hp_fill.bg_color = HP_LOW.lerp(HP_GOOD, clampf(cur / mx, 0.0, 1.0))
