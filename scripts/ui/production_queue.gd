extends CanvasLayer

const EMPTY_COLOR: Color = Color(0.08, 0.1, 0.12, 0.5)
const OCCUPIED_COLOR: Color = Color(0.0, 0.45, 0.45, 0.6)

var _current_building: Node = null

@onready var _timer_label: Label = $Panel/VBox/TimerLabel
@onready var _hbox: HBoxContainer = $Panel/VBox/HBox

var _slots: Array[PanelContainer] = []
var _slot_labels: Array[Label] = []
var _slot_styles: Array[StyleBoxFlat] = []
var _progress_bar: ColorRect = null

func _ready() -> void:
	visible = false
	for child in _hbox.get_children():
		var slot := child as PanelContainer
		if slot == null:
			continue
		_slots.append(slot)
		_slot_labels.append(slot.get_node("Label") as Label)
		_slot_styles.append(slot.get_theme_stylebox("panel") as StyleBoxFlat)
	if not _slots.is_empty():
		_progress_bar = _slots[0].get_node_or_null("Label/Progress") as ColorRect
	SelectionManager.building_selected.connect(_on_building_selected)
	SelectionManager.building_deselected.connect(_on_building_deselected)

func _on_building_selected(b: Node) -> void:
	if b == null or not b.has_method("has_train_slot") or not b.has_train_slot(0):
		visible = false
		_current_building = null
		return
	_current_building = b
	visible = true

func _on_building_deselected() -> void:
	_current_building = null
	visible = false

func _process(_delta: float) -> void:
	if not visible or _current_building == null:
		return
	if not is_instance_valid(_current_building):
		_on_building_deselected()
		return
	_refresh()

func _refresh() -> void:
	var q: Variant = _current_building.get("queue")
	var queue: Array = q if q is Array else []
	var count: int = queue.size()
	for i in range(_slots.size()):
		var occupied: bool = i < count
		if _slot_styles[i] != null:
			_slot_styles[i].bg_color = OCCUPIED_COLOR if occupied else EMPTY_COLOR
		var lbl: Label = _slot_labels[i]
		if occupied:
			lbl.text = _abbrev(_current_building.get_train_label(0)) if i == 0 else "•"
		else:
			lbl.text = ""
	if count > 0:
		var entry: Dictionary = queue[0]
		var duration: float = float(entry.get("duration", 0.0))
		var timer: float = float(_current_building.get("production_timer"))
		var progress: float = 0.0
		if duration > 0.0:
			progress = clampf(1.0 - (timer / duration), 0.0, 1.0)
		if _progress_bar != null:
			var parent_w: float = (_progress_bar.get_parent() as Control).size.x
			_progress_bar.offset_right = progress * parent_w
			_progress_bar.visible = true
		_timer_label.text = "%.1fs" % maxf(timer, 0.0)
	else:
		if _progress_bar != null:
			_progress_bar.offset_right = 0.0
			_progress_bar.visible = false
		_timer_label.text = "IDLE"

func _abbrev(label: String) -> String:
	var up: String = label.to_upper()
	if up.length() <= 3:
		return up
	return up.substr(0, 3)
