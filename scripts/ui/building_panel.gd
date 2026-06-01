extends CanvasLayer

@onready var barracks_btn: Button = $BottomBar/Margin/HBox/BarracksBtn
@onready var tc_btn: Button = $BottomBar/Margin/HBox/TCBtn
@onready var tower_btn: Button = $BottomBar/Margin/HBox/TowerBtn
@onready var side_panel: PanelContainer = $SidePanel
@onready var name_label: Label = $SidePanel/Margin/VBox/NameLabel
@onready var hp_label: Label = $SidePanel/Margin/VBox/HPLabel
@onready var queue_label: Label = $SidePanel/Margin/VBox/QueueLabel
@onready var timer_label: Label = $SidePanel/Margin/VBox/TimerLabel
@onready var train_btn: Button = $SidePanel/Margin/VBox/TrainBtn
@onready var train_2_btn: Button = $SidePanel/Margin/VBox/Train2Btn

var current_building: Node = null

func _ready() -> void:
	barracks_btn.pressed.connect(_on_barracks)
	tc_btn.pressed.connect(_on_tc)
	tower_btn.pressed.connect(_on_tower)
	train_btn.pressed.connect(_on_train_0)
	train_2_btn.pressed.connect(_on_train_1)
	SelectionManager.building_selected.connect(_on_building_selected)
	SelectionManager.building_deselected.connect(_on_building_deselected)
	side_panel.visible = false
	_setup_tooltips()

func _setup_tooltips() -> void:
	barracks_btn.tooltip_text = _build_tooltip("Barracks", "barracks", "Trains soldiers and archers")
	tc_btn.tooltip_text = _build_tooltip("Town Center", "tc", "Trains villagers (50F, 10s)")
	tower_btn.tooltip_text = _build_tooltip("Tower", "tower", "Auto-attacks enemies in 150px range (18 dmg / 2s)")

func _build_tooltip(display_name: String, type: String, suffix: String) -> String:
	var data: Dictionary = BuildingPlacer.BUILDING_DATA.get(type, {})
	var cost: Dictionary = data.get("cost", {})
	return "Build %s\nCost: %s\n%s" % [display_name, _format_cost(cost), suffix]

func _format_cost(cost: Dictionary) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for type in cost:
		var letter: String = "?"
		match type:
			"madera": letter = "W"
			"comida": letter = "F"
			"oro": letter = "G"
		parts.append("%d%s" % [int(cost[type]), letter])
	return ", ".join(parts)

func _on_barracks() -> void:
	BuildingPlacer.start_placement("barracks")

func _on_tc() -> void:
	BuildingPlacer.start_placement("tc")

func _on_tower() -> void:
	BuildingPlacer.start_placement("tower")

func _on_train_0() -> void:
	if current_building != null and is_instance_valid(current_building):
		current_building.try_queue_training(0)

func _on_train_1() -> void:
	if current_building != null and is_instance_valid(current_building):
		current_building.try_queue_training(1)

func _on_building_selected(b: Node) -> void:
	current_building = b
	side_panel.visible = true

func _on_building_deselected() -> void:
	current_building = null
	side_panel.visible = false

func _process(_delta: float) -> void:
	if not side_panel.visible:
		return
	if current_building == null or not is_instance_valid(current_building):
		_on_building_deselected()
		return
	_refresh()

func _refresh() -> void:
	name_label.text = current_building.building_name
	hp_label.text = "HP: %d/%d" % [current_building.hp, current_building.max_hp]
	var q_size: int = current_building.queue.size()
	queue_label.text = "Queue: %d/5" % q_size
	if q_size > 0:
		var t: float = max(current_building.production_timer, 0.0)
		timer_label.text = "Training: %.1fs" % t
	else:
		timer_label.text = "Idle"

	if current_building.has_train_slot(0):
		train_btn.visible = true
		train_btn.text = "Train %s (%s)" % [current_building.get_train_label(0), current_building.get_train_cost_label(0)]
	else:
		train_btn.visible = false

	if current_building.has_train_slot(1):
		train_2_btn.visible = true
		train_2_btn.text = "Train %s (%s)" % [current_building.get_train_label(1), current_building.get_train_cost_label(1)]
	else:
		train_2_btn.visible = false
