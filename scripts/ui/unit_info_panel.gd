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
	add_theme_stylebox_override("panel", MenuKit.chip_box(10.0))
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
	hide()

func _process(delta: float) -> void:
	if _focus == null:
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
		hide()

## The plate hugs its content: tall for the full single-entity readout, short
## for the multi-select count + chips (a fixed height leaves a huge empty plate).
func _set_height(h: float) -> void:
	offset_top = -(h + 8.0)

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
	_name_label.text = dname if role == "" else "%s — %s" % [dname, role]
	# Small entity icon (never a big portrait).
	var icon_path: String = String(d["icon"])
	_icon.visible = icon_path != ""
	if icon_path != "":
		_icon.texture = load(icon_path)
	_set_owner(node)
	var stats_parts: PackedStringArray = PackedStringArray()
	for s in (d["stats"] as Array):
		stats_parts.append("%s %s" % [String(s["label"]), str(s["value"])])
	if not stats_parts.is_empty():
		_owner_label.text += "   ·   %s" % " · ".join(stats_parts)
	_set_status(String(d["status"]))
	_set_queue(d["queue"] as Array)
	_fit_single()
	_refresh_hp(node)
	show()

func _fit_single() -> void:
	var h: float = 118.0
	if _status_label.visible:
		h += 20.0
	if _queue_row.visible:
		h += 28.0
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
	_set_height(92.0)
	if _emblem != null:
		_emblem.visible = false
	_icon.visible = false
	_status_label.hide()
	_queue_row.hide()
	_name_label.hide()
	_owner_label.hide()
	_hp_bar.hide()
	_hp_label.hide()
	_multi_label.show()
	_multi_label.text = "%d units selected" % units.size()
	_build_type_chips(units)
	show()

var _type_row: HBoxContainer = null

## AoE4-style type breakdown: one chip per unit type ("3× Soldier"); clicking a
## chip narrows the selection to just that type.
func _build_type_chips(units: Array) -> void:
	if _type_row == null:
		_type_row = HBoxContainer.new()
		_type_row.add_theme_constant_override("separation", 4)
		$VBox.add_child(_type_row)
	for c in _type_row.get_children():
		c.queue_free()
	var groups: Dictionary = {}
	for u in units:
		if not is_instance_valid(u):
			continue
		var key: String = _display_name(u)
		if not groups.has(key):
			groups[key] = []
		(groups[key] as Array).append(u)
	for key in groups:
		var members: Array = groups[key]
		var chip := Button.new()
		chip.text = "%d× %s" % [members.size(), key]
		chip.tooltip_text = "Select only %s" % key
		chip.add_theme_font_size_override("font_size", 11)
		chip.add_theme_color_override("font_color", Color(0.92, 0.95, 0.98, 1))
		chip.add_theme_color_override("font_hover_color", Color(0.0, 0.90, 0.78, 1))
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.10, 0.13, 0.17, 1.0)
		sb.set_border_width_all(1)
		sb.border_color = Color(0.0, 0.85, 0.85, 0.3)
		sb.set_corner_radius_all(3)
		sb.content_margin_left = 6.0
		sb.content_margin_right = 6.0
		chip.add_theme_stylebox_override("normal", sb)
		chip.add_theme_stylebox_override("hover", sb)
		chip.pressed.connect(func() -> void: SelectionManager.select_multiple(members))
		_type_row.add_child(chip)
	_type_row.show()

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
