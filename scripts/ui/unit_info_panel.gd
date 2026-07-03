class_name UnitInfoPanel
extends PanelContainer

## Bottom-left info card for whatever the player is looking at: a single selected
## unit, a multi-selection count, or an inspected enemy unit/building (read-only).
## Shows a friendly name, the owner faction (in faction colour) and a live HP bar.
## Player buildings are shown by the BuildingPanel side panel instead.

const UNIT_NAMES: Dictionary = {
	"soldier": "Soldier", "archer": "Archer", "raider": "Raider",
	"villager": "Villager", "ix_lattice_guard": "Lattice Guard", "ix_weaver": "Weaver",
}
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
var _focus: Node = null
var _hp_fill: StyleBoxFlat = null

func _ready() -> void:
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

func _process(_delta: float) -> void:
	if _focus == null:
		return
	if not is_instance_valid(_focus):
		_focus = null
		_inspect = null
		_relayout()
		return
	_refresh_hp(_focus)

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

func _relayout() -> void:
	if _inspect != null and is_instance_valid(_inspect):
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

func _show_single(node: Node) -> void:
	_multi_label.hide()
	if _type_row != null:
		_type_row.hide()
	_name_label.show()
	_owner_label.show()
	_hp_bar.show()
	_hp_label.show()
	_name_label.text = _display_name(node)
	_set_owner(node)
	_refresh_hp(node)
	show()

func _show_multi(units: Array) -> void:
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
	var bn: Variant = node.get("building_name")
	if bn != null and String(bn) != "":
		return String(bn)
	var sa: Variant = node.get("sprite_asset")
	if sa != null and UNIT_NAMES.has(String(sa)):
		return UNIT_NAMES[String(sa)]
	return node.name

func _set_owner(node: Node) -> void:
	var fid_v: Variant = node.get("faction_id")
	if fid_v == null:
		_owner_label.hide()
		return
	var fid: int = int(fid_v)
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
