extends Node

# Manages timed alert notifications. Max 5 visible at once.
# Consumers call AlertManager.push(text, level) where level is "error"|"warning"|"info".
# Alerts auto-expire after 6 seconds.

signal alert_pushed(text: String, level: String)
signal alert_cleared(index: int)

const MAX_ALERTS: int = 5
const ALERT_LIFETIME: float = 6.0

var _alerts: Array = []

func push(text: String, level: String = "info") -> void:
	if _alerts.size() >= MAX_ALERTS:
		_alerts.pop_front()
		alert_cleared.emit(0)
	_alerts.append({"text": text, "level": level, "time_remaining": ALERT_LIFETIME})
	alert_pushed.emit(text, level)

func get_alerts() -> Array:
	return _alerts

func register_building(b: Node) -> void:
	if b == null or not is_instance_valid(b):
		return
	if b.has_signal("building_damaged") and not b.is_connected("building_damaged", _on_building_damaged):
		b.connect("building_damaged", _on_building_damaged)

func _on_building_damaged(_building: Node) -> void:
	push("Base under attack!", "error")

func _process(delta: float) -> void:
	if _alerts.is_empty():
		return
	var i: int = _alerts.size() - 1
	while i >= 0:
		_alerts[i]["time_remaining"] = float(_alerts[i]["time_remaining"]) - delta
		if float(_alerts[i]["time_remaining"]) <= 0.0:
			_alerts.remove_at(i)
			alert_cleared.emit(i)
		i -= 1
