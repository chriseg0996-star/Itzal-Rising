extends Node

var game_time: float = 0.0
var units_trained: int = 0
var resources_gathered: int = 0

func reset() -> void:
	game_time = 0.0
	units_trained = 0
	resources_gathered = 0

func _process(delta: float) -> void:
	game_time += delta

func format_time() -> String:
	var total: int = int(game_time)
	@warning_ignore("integer_division")
	var minutes: int = total / 60
	var seconds: int = total % 60
	return "%02d:%02d" % [minutes, seconds]
