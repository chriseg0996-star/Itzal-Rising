extends CanvasLayer

@onready var title: Label = $Center/Panel/Margin/VBox/Title
@onready var stats_label: Label = $Center/Panel/Margin/VBox/StatsLabel
@onready var restart_btn: Button = $Center/Panel/Margin/VBox/RestartBtn

var game_over: bool = false
var player_had_tc: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	restart_btn.pressed.connect(_on_restart)
	$Center/Panel/Margin/VBox/MenuBtn.pressed.connect(_on_menu)

func _process(_delta: float) -> void:
	if game_over:
		return
	_check_conditions()

func _check_conditions() -> void:
	var player_tc: Node = _find_player_tc()
	if player_tc != null:
		player_had_tc = true
	elif player_had_tc:
		_show("DEFEAT")
		return
	if get_tree().get_nodes_in_group("enemy_buildings").is_empty():
		_show("VICTORY")

func _find_player_tc() -> Node:
	for b in get_tree().get_nodes_in_group("player_buildings"):
		if b.building_name == "Town Center":
			return b
	return null

func _show(text: String) -> void:
	get_tree().paused = true
	title.text = text
	stats_label.text = "Time: %s\nUnits trained: %d\nResources gathered: %d" % [
		GameStats.format_time(),
		GameStats.units_trained,
		GameStats.resources_gathered
	]
	visible = true
	game_over = true

func _on_restart() -> void:
	get_tree().paused = false
	ResourceManager.reset()
	SelectionManager.clear()
	SelectionManager.deselect_building()
	BuildingPlacer.cancel_placement()
	EnemyAI.reset()
	GameStats.reset()
	game_over = false
	player_had_tc = false
	visible = false
	get_tree().reload_current_scene()

func _on_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
