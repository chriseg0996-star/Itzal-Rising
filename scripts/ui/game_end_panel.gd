extends CanvasLayer

@onready var title: Label = $Center/Panel/Margin/VBox/Title
@onready var stats_label: Label = $Center/Panel/Margin/VBox/StatsLabel
@onready var restart_btn: Button = $Center/Panel/Margin/VBox/RestartBtn

const MONUMENT_DURATION: float = 180.0

var game_over: bool = false
var player_had_tc: bool = false
var _recorded: bool = false
var _match_deltas: Dictionary = {}
var monument_countdown_active: bool = false
var monument_time_left: float = 0.0
var _alert_60_sent: bool = false
var _alert_10_sent: bool = false
var _monument_label: Label = null
var _campaign_btn: Button = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	restart_btn.pressed.connect(_on_restart)
	$Center/Panel/Margin/VBox/MenuBtn.pressed.connect(_on_menu)
	_build_monument_label()

func _build_monument_label() -> void:
	_monument_label = Label.new()
	_monument_label.visible = false
	_monument_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_monument_label.add_theme_color_override("font_color", Color(0.0, 0.90, 0.78, 1.0))
	_monument_label.add_theme_font_size_override("font_size", 22)
	add_child(_monument_label)
	_monument_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_monument_label.offset_top = 44.0
	_monument_label.offset_bottom = 72.0
	_monument_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	# process_mode is ALWAYS so the end panel works while paused — the
	# monument clock and win checks must NOT advance then.
	if get_tree().paused:
		return
	if game_over:
		return
	_tick_monument(delta)
	_check_conditions()

func _tick_monument(delta: float) -> void:
	if not monument_countdown_active:
		return
	monument_time_left = maxf(monument_time_left - delta, 0.0)
	var t: int = int(monument_time_left)
	_monument_label.text = "MONUMENT  %02d:%02d" % [int(float(t) / 60.0), t % 60]
	if monument_time_left <= 60.0 and not _alert_60_sent:
		_alert_60_sent = true
		AlertManager.push("Monument: 1:00 remaining", "warning")
	if monument_time_left <= 10.0 and not _alert_10_sent:
		_alert_10_sent = true
		AlertManager.push("Monument: 10 seconds!", "warning")
	if monument_time_left <= 0.0:
		_show("MONUMENT VICTORY")

func _check_conditions() -> void:
	var player_tc: Node = _find_player_tc()
	if player_tc != null:
		player_had_tc = true
	elif player_had_tc:
		_show("DEFEAT")
		return
	var monument: Node = _find_player_monument()
	if monument != null and not monument_countdown_active:
		monument_countdown_active = true
		monument_time_left = MONUMENT_DURATION
		_alert_60_sent = false
		_alert_10_sent = false
		_monument_label.visible = true
		AlertManager.push("Monument raised — hold for 3:00!", "warning")
		# The AI contests immediately — its ticks are 20-45s apart, which would
		# otherwise gift a quarter of the countdown.
		EnemyAI.force_attack((monument as Node2D).global_position)
	elif monument == null and monument_countdown_active:
		monument_countdown_active = false
		_monument_label.visible = false
		AlertManager.push("Monument destroyed!", "error")
	if get_tree().get_nodes_in_group("enemy_buildings").is_empty():
		_show("VICTORY")

func _find_player_monument() -> Node:
	for b in get_tree().get_nodes_in_group("player_buildings"):
		if is_instance_valid(b) and b.building_name == "Monument" and not b.get("dying"):
			return b
	return null

## SaveManager hooks.
func get_monument_state() -> Dictionary:
	return {"countdown_active": monument_countdown_active, "time_left": monument_time_left}

func set_monument_state(active: bool, time_left: float) -> void:
	monument_countdown_active = active
	monument_time_left = time_left
	_monument_label.visible = active
	_alert_60_sent = time_left <= 60.0
	_alert_10_sent = time_left <= 10.0

func _find_player_tc() -> Node:
	for b in get_tree().get_nodes_in_group("player_buildings"):
		if b.building_name == "Town Center":
			return b
	return null

func _show(text: String) -> void:
	get_tree().paused = true
	title.text = text
	var won: bool = text.begins_with("VICTORY") or text.begins_with("MONUMENT")
	if not _recorded:
		_recorded = true
		_match_deltas = ProfileManager.record_match(won, GameSettings.player_faction_id,
			GameSettings.selected_map, GameStats.game_time, {
				"enemies_killed": GameStats.enemies_killed,
				"units_lost": GameStats.units_lost,
				"buildings_destroyed": GameStats.buildings_destroyed,
			})
	var summary: String = "Time: %s\nUnits trained: %d   Resources: %d\nEnemies killed: %d   Units lost: %d   Razed: %d\nRecord: %dW / %dL" % [
		GameStats.format_time(),
		GameStats.units_trained,
		GameStats.resources_gathered,
		GameStats.enemies_killed,
		GameStats.units_lost,
		GameStats.buildings_destroyed,
		ProfileManager.wins,
		ProfileManager.losses,
	]
	if won and bool(_match_deltas.get("new_best", false)):
		summary += "\n★ NEW BEST TIME on %s!" % GameSettings.selected_map
	stats_label.text = summary
	_setup_campaign_button(won)
	visible = true
	game_over = true

## In a campaign mission, unlock the next mission on a win and offer a Next /
## Retry button alongside Restart/Menu. No-op in plain skirmish.
func _setup_campaign_button(won: bool) -> void:
	if _campaign_btn != null:
		_campaign_btn.queue_free()
		_campaign_btn = null
	if not ActiveMission.is_active():
		return
	var mid: String = ActiveMission.current_id
	var label: String = ""
	var target: String = ""
	if won:
		ProfileManager.mark_mission_cleared(mid)
		var nxt: String = MissionConfig.next_id(mid)
		if nxt != "":
			label = "Next Mission"
			target = nxt
		else:
			title.text = "CAMPAIGN COMPLETE"
	else:
		label = "Retry Mission"
		target = mid
	if label == "":
		return
	_campaign_btn = restart_btn.duplicate()
	_campaign_btn.text = label
	restart_btn.get_parent().add_child(_campaign_btn)
	restart_btn.get_parent().move_child(_campaign_btn, restart_btn.get_index())
	_campaign_btn.pressed.connect(func() -> void:
		visible = false
		MissionLoader.start(target))

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
	_recorded = false
	_match_deltas = {}
	monument_countdown_active = false
	monument_time_left = 0.0
	_monument_label.visible = false
	visible = false
	get_tree().reload_current_scene()

func _on_menu() -> void:
	get_tree().paused = false
	ActiveMission.clear()
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
