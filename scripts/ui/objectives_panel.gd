extends CanvasLayer

## Collapsible top-left panel showing up to 3 active objectives with live
## progress. Rows are built in code; ObjectiveManager owns the data.

const ROW_COUNT: int = 3
const POLL_INTERVAL: float = 2.0

const DOT_DONE: Color = Color(0, 0.85, 0.85, 1)
const DOT_TODO: Color = Color(0.55, 0.65, 0.7, 1)
const BAR_DONE: Color = Color(0, 0.85, 0.85, 1)
const BAR_TODO: Color = Color(0.55, 0.65, 0.7, 0.8)
const LABEL_DONE: Color = Color(0.92, 0.95, 0.98, 1)
const LABEL_TODO: Color = Color(0.92, 0.95, 0.98, 1)

var _rows: Array[VBoxContainer] = []
var _dots: Array[ColorRect] = []
var _name_labels: Array[Label] = []
var _status_labels: Array[Label] = []
var _bars: Array[ProgressBar] = []

@onready var _content: VBoxContainer = $Root/Panel/VBox/Content
@onready var _collapse_btn: Button = $Root/Panel/VBox/Header/Collapse

func _ready() -> void:
	_build_rows()
	_collapse_btn.pressed.connect(_on_collapse_pressed)
	ObjectiveManager.objective_completed.connect(_on_objective_completed)
	var timer := Timer.new()
	timer.wait_time = POLL_INTERVAL
	timer.autostart = true
	timer.timeout.connect(_refresh)
	add_child(timer)
	_refresh()

func _build_rows() -> void:
	for i in range(ROW_COUNT):
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 2)

		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 6)

		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(6, 6)
		dot.color = DOT_TODO
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER

		var name_label := Label.new()
		name_label.text = ""
		name_label.add_theme_font_size_override("font_size", 11)
		name_label.add_theme_color_override("font_color", LABEL_TODO)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.clip_text = true

		var status_label := Label.new()
		status_label.text = ""
		status_label.add_theme_font_size_override("font_size", 11)
		status_label.add_theme_color_override("font_color", LABEL_TODO)
		status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

		line.add_child(dot)
		line.add_child(name_label)
		line.add_child(status_label)

		var bar := ProgressBar.new()
		bar.min_value = 0.0
		bar.max_value = 100.0
		bar.value = 0.0
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 3)
		bar.modulate = BAR_TODO

		row.add_child(line)
		row.add_child(bar)
		_content.add_child(row)

		_rows.append(row)
		_dots.append(dot)
		_name_labels.append(name_label)
		_status_labels.append(status_label)
		_bars.append(bar)

func _refresh() -> void:
	var active: Array[Dictionary] = ObjectiveManager.get_active_objectives()
	for i in range(ROW_COUNT):
		if i >= active.size():
			_rows[i].visible = false
			continue
		var obj: Dictionary = active[i]
		var done: bool = ObjectiveManager.is_complete(obj)
		var progress: float = ObjectiveManager.get_progress(obj)
		var target: int = int(obj.get("target", 1))
		var current: int = int(round(progress * float(target)))

		_rows[i].visible = true
		_name_labels[i].text = String(obj.get("label", ""))
		_status_labels[i].text = "✓" if done else "%d/%d" % [current, target]
		_dots[i].color = DOT_DONE if done else DOT_TODO
		_name_labels[i].add_theme_color_override("font_color", LABEL_DONE if done else LABEL_TODO)
		_status_labels[i].add_theme_color_override("font_color", LABEL_DONE if done else LABEL_TODO)
		_bars[i].value = 100.0 if done else progress * 100.0
		_bars[i].modulate = BAR_DONE if done else BAR_TODO

func _on_objective_completed(_id: String, _label: String) -> void:
	_refresh()

func _on_collapse_pressed() -> void:
	_content.visible = not _content.visible
	_collapse_btn.text = "▾" if _content.visible else "▸"
