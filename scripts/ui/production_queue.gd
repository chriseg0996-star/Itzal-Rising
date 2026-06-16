extends CanvasLayer

const EMPTY_COLOR: Color = Color(0.08, 0.1, 0.12, 0.5)
const OCCUPIED_COLOR: Color = Color(0.0, 0.45, 0.45, 0.6)

var _current_building: Node = null

@onready var _timer_label: Label = $Panel/VBox/TimerLabel
@onready var _hbox: HBoxContainer = $Panel/VBox/HBox

const ICON_DIR: String = "res://assets/ui/icons/"

var _slots: Array[PanelContainer] = []
var _slot_labels: Array[Label] = []
var _slot_icons: Array[TextureRect] = []
var _slot_styles: Array[StyleBoxFlat] = []
var _progress_bar: ColorRect = null
var _icon_cache: Dictionary = {}

func _ready() -> void:
	visible = false
	for child in _hbox.get_children():
		var slot := child as PanelContainer
		if slot == null:
			continue
		_slots.append(slot)
		_slot_labels.append(slot.get_node("Label") as Label)
		_slot_styles.append(slot.get_theme_stylebox("panel") as StyleBoxFlat)
		# Icon sits BEHIND the label so the slot-0 progress bar still draws on top.
		var icon := TextureRect.new()
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.visible = false
		slot.add_child(icon)
		slot.move_child(icon, 0)
		_slot_icons.append(icon)
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
		var icon: TextureRect = _slot_icons[i]
		if occupied:
			var entry: Dictionary = queue[i]
			if entry.has("research_id"):
				icon.visible = false
				lbl.text = "UPG"
			else:
				var tex: Texture2D = _icon_for(String(entry.get("label", "")))
				if tex != null:
					icon.texture = tex
					icon.visible = true
					lbl.text = ""
				else:
					icon.visible = false
					lbl.text = _abbrev(String(entry.get("label", "")))
		else:
			icon.visible = false
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

## Map a unit's train label to its HUD icon (same keyword scheme as the build
## panel). Returns null if no icon ships for it, so the slot falls back to text.
func _icon_for(label: String) -> Texture2D:
	if label == "":
		return null
	var key: String = _icon_key(label)
	if _icon_cache.has(key):
		return _icon_cache[key]
	var path: String = ICON_DIR + key + ".png"
	var tex: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_icon_cache[key] = tex
	return tex

func _icon_key(label: String) -> String:
	var l: String = label.to_lower()
	if l.contains("archer"):
		return "unit_archer"
	if l.contains("raider") or l.contains("lancer") or l.contains("rider"):
		return "unit_raider"
	if l.contains("guard"):
		return "unit_guard"
	if l.contains("villager") or l.contains("weaver"):
		return "unit_villager"
	return "unit_soldier"
