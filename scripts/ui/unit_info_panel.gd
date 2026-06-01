class_name UnitInfoPanel
extends PanelContainer

@onready var _name_label: Label = $VBox/NameLabel
@onready var _hp_bar: ProgressBar = $VBox/HPBar
@onready var _hp_label: Label = $VBox/HPLabel
@onready var _multi_label: Label = $VBox/MultiLabel

var _tracked_unit: CharacterBody2D = null

func _ready() -> void:
	SelectionManager.selection_changed.connect(_on_selection_changed)
	hide()

func _process(_delta: float) -> void:
	if _tracked_unit == null or not is_instance_valid(_tracked_unit):
		hide()
		_tracked_unit = null
		return
	_refresh_single(_tracked_unit)

func _on_selection_changed(units: Array) -> void:
	if units.size() == 0:
		hide()
		_tracked_unit = null
	elif units.size() == 1:
		_tracked_unit = units[0]
		_show_single(_tracked_unit)
		show()
	else:
		_tracked_unit = null
		_show_multi(units)
		show()

func _show_single(unit: CharacterBody2D) -> void:
	_multi_label.hide()
	_name_label.show()
	_hp_bar.show()
	_hp_label.show()
	_name_label.text = unit.name
	_refresh_single(unit)

func _refresh_single(unit: CharacterBody2D) -> void:
	var stat := unit.get_node_or_null("StatComponent") as StatComponent
	if stat == null:
		return
	_hp_bar.max_value = stat.max_health
	_hp_bar.value = stat.get_health_ratio() * stat.max_health
	_hp_label.text = "%d / %d" % [roundi(_hp_bar.value), roundi(stat.max_health)]

func _show_multi(units: Array) -> void:
	_name_label.hide()
	_hp_bar.hide()
	_hp_label.hide()
	_multi_label.show()
	_multi_label.text = "%d units selected" % units.size()
