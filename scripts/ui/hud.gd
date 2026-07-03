extends CanvasLayer

const POLL_INTERVAL: float = 1.0
const ALERT_SLOTS: int = 5
const PULSE_COOLDOWN: float = 2.0
const PULSE_COLOR: Color = Color(0.85, 0.2, 0.15, 1.0)

@onready var wood_label: Label = $TopBar/Margin/HBox/Wood/Label
@onready var food_label: Label = $TopBar/Margin/HBox/Food/Label
@onready var gold_label: Label = $TopBar/Margin/HBox/Gold/Label
@onready var pop_label: Label = $TopBar/Margin/HBox/Pop/Label
@onready var era_label: Label = $TopBar/Margin/HBox/Era/Label
@onready var _alert_box: VBoxContainer = $AlertPanel/VBox

const ERA_ROMAN: Array[String] = ["I", "II", "III"]

var _poll_timer: float = 0.0
var _alert_labels: Array[Label] = []
var _pulse_overlay: ColorRect = null
var _pulse_cooldown: float = 0.0

func _ready() -> void:
	ResourceManager.resource_changed.connect(_on_resource_changed)
	SelectionManager.selection_changed.connect(_on_selection_changed)
	AlertManager.alert_pushed.connect(_on_alert_pushed)
	AlertManager.alert_cleared.connect(_on_alert_cleared)
	ResourceManager.supply_changed.connect(func(_fid: int, _u: int, _c: int) -> void: _update_population())
	_build_pulse_overlay()
	for i in range(ALERT_SLOTS):
		var lbl: Label = _alert_box.get_node_or_null("Alert%d" % i) as Label
		if lbl != null:
			_alert_labels.append(lbl)
	_refresh()
	_update_population()
	_update_era()
	_refresh_alerts()

func _process(delta: float) -> void:
	_poll_timer += delta
	if _poll_timer >= POLL_INTERVAL:
		_poll_timer = 0.0
		_update_population()
		_update_era()
	if _pulse_cooldown > 0.0:
		_pulse_cooldown -= delta

## Full-screen red tint that blinks when the base is threatened. Sits behind
## the rest of the HUD and ignores mouse input.
func _build_pulse_overlay() -> void:
	_pulse_overlay = ColorRect.new()
	_pulse_overlay.color = Color(PULSE_COLOR.r, PULSE_COLOR.g, PULSE_COLOR.b, 0.0)
	_pulse_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_pulse_overlay)
	move_child(_pulse_overlay, 0)
	_pulse_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _pulse_screen() -> void:
	if _pulse_overlay == null or _pulse_cooldown > 0.0:
		return
	_pulse_cooldown = PULSE_COOLDOWN
	var tween := create_tween()
	tween.tween_property(_pulse_overlay, "color:a", 0.16, 0.2)
	tween.tween_property(_pulse_overlay, "color:a", 0.0, 0.4)

func _on_resource_changed(_type: StringName, _new_amount: int) -> void:
	_refresh()

func _on_selection_changed(_units: Array) -> void:
	_update_population()

func _refresh() -> void:
	var pf: int = GameSettings.player_faction_id
	wood_label.text = str(ResourceManager.get_resource(ResourceManager.WOOD, pf))
	food_label.text = str(ResourceManager.get_resource(ResourceManager.FOOD, pf))
	gold_label.text = str(ResourceManager.get_resource(ResourceManager.GOLD, pf))

func _update_era() -> void:
	if era_label == null:
		return
	var e: int = clampi(GameStats.era, 1, ERA_ROMAN.size())
	era_label.text = "Era %s" % ERA_ROMAN[e - 1]

func _update_population() -> void:
	var fid: int = GameSettings.player_faction_id
	var used: int = ResourceManager.get_supply_used(fid)
	var cap: int = ResourceManager.get_supply_cap(fid)
	pop_label.text = "⚡ %d/%d" % [used, cap]
	var col: Color = Color(1, 1, 1, 1)
	if used >= cap:
		col = Color(1.0, 0.33, 0.22, 1)  # capped — build an Obsidian Pylon
	pop_label.add_theme_color_override("font_color", col)

func _on_alert_pushed(_text: String, level: String) -> void:
	_refresh_alerts()
	if level == "warning" or level == "error":
		_pulse_screen()

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
