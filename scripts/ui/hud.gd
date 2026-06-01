extends CanvasLayer

const POLL_INTERVAL: float = 1.0
const ALERT_SLOTS: int = 5

@export var max_population: int = 80

@onready var wood_label: Label = $TopBar/Margin/HBox/Wood/Label
@onready var food_label: Label = $TopBar/Margin/HBox/Food/Label
@onready var gold_label: Label = $TopBar/Margin/HBox/Gold/Label
@onready var pop_label: Label = $TopBar/Margin/HBox/Pop/Label
@onready var _alert_box: VBoxContainer = $AlertPanel/VBox

var _poll_timer: float = 0.0
var _alert_labels: Array[Label] = []

func _ready() -> void:
	ResourceManager.resource_changed.connect(_on_resource_changed)
	SelectionManager.selection_changed.connect(_on_selection_changed)
	AlertManager.alert_pushed.connect(_on_alert_pushed)
	AlertManager.alert_cleared.connect(_on_alert_cleared)
	for i in range(ALERT_SLOTS):
		var lbl: Label = _alert_box.get_node_or_null("Alert%d" % i) as Label
		if lbl != null:
			_alert_labels.append(lbl)
	_refresh()
	_update_population()
	_refresh_alerts()

func _process(delta: float) -> void:
	_poll_timer += delta
	if _poll_timer >= POLL_INTERVAL:
		_poll_timer = 0.0
		_update_population()

func _on_resource_changed(_type: StringName, _new_amount: int) -> void:
	_refresh()

func _on_selection_changed(_units: Array) -> void:
	_update_population()

func _refresh() -> void:
	wood_label.text = str(ResourceManager.get_resource(ResourceManager.WOOD))
	food_label.text = str(ResourceManager.get_resource(ResourceManager.FOOD))
	gold_label.text = str(ResourceManager.get_resource(ResourceManager.GOLD))

func _update_population() -> void:
	var count: int = get_tree().get_nodes_in_group("player_units").size()
	pop_label.text = "%d/%d" % [count, max_population]
	var col: Color = Color(1, 1, 1, 1)
	if count >= max_population:
		col = Color(1.0, 0.33, 0.22, 1)
	pop_label.add_theme_color_override("font_color", col)

func _on_alert_pushed(_text: String, _level: String) -> void:
	_refresh_alerts()

func _on_alert_cleared(_index: int) -> void:
	_refresh_alerts()

func _refresh_alerts() -> void:
	var alerts: Array = AlertManager.get_alerts()
	for i in range(_alert_labels.size()):
		var lbl: Label = _alert_labels[i]
		if i < alerts.size():
			var a: Dictionary = alerts[i]
			lbl.text = String(a.get("text", ""))
			lbl.add_theme_color_override("font_color", _alert_color(String(a.get("level", "info"))))
			lbl.show()
		else:
			lbl.hide()

func _alert_color(level: String) -> Color:
	match level:
		"error":
			return Color(1.0, 0.33, 0.22, 1)
		"warning":
			return Color(0.94, 0.75, 0.1, 1)
		_:
			return Color(0.7, 0.9, 0.7, 1)
