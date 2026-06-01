extends CanvasLayer

@onready var _side_panel: PanelContainer = $SidePanel
@onready var _name_label: Label = $SidePanel/Margin/VBox/NameLabel
@onready var _hp_label: Label = $SidePanel/Margin/VBox/HPLabel
@onready var _queue_label: Label = $SidePanel/Margin/VBox/QueueLabel
@onready var _timer_label: Label = $SidePanel/Margin/VBox/TimerLabel
@onready var _train_btn: Button = $SidePanel/Margin/VBox/TrainBtn
@onready var _train2_btn: Button = $SidePanel/Margin/VBox/Train2Btn
@onready var _barracks_btn: Button = $BottomBar/Margin/HBox/BarracksBtn
@onready var _tc_btn: Button = $BottomBar/Margin/HBox/TCBtn
@onready var _tower_btn: Button = $BottomBar/Margin/HBox/TowerBtn

var _selected_building: Node = null

func _ready() -> void:
	_barracks_btn.pressed.connect(func(): BuildingPlacer.start_placement("barracks"))
	_tc_btn.pressed.connect(func(): BuildingPlacer.start_placement("tc"))
	_tower_btn.pressed.connect(func(): BuildingPlacer.start_placement("tower"))
	_train_btn.pressed.connect(func(): _try_train(0))
	_train2_btn.pressed.connect(func(): _try_train(1))
	SelectionManager.building_selected.connect(show_building)
	SelectionManager.building_deselected.connect(hide_building)
	_side_panel.visible = false

func show_building(building: Node) -> void:
	_selected_building = building
	_side_panel.visible = true
	_refresh()

func hide_building() -> void:
	_selected_building = null
	_side_panel.visible = false

func _try_train(slot: int) -> void:
	if _selected_building == null:
		return
	if _selected_building.has_method("try_queue_training"):
		_selected_building.try_queue_training(slot)

func _process(_delta: float) -> void:
	if _selected_building == null or not is_instance_valid(_selected_building):
		hide_building()
		return
	_refresh()

func _refresh() -> void:
	var b: Node = _selected_building
	_name_label.text = b.get("building_name") if b.get("building_name") else "Building"
	var hp: int = b.get("hp") if b.get("hp") != null else 0
	var max_hp: int = b.get("max_hp") if b.get("max_hp") != null else 0
	_hp_label.text = "HP: %d/%d" % [hp, max_hp]
	var q: Array = b.get("queue") if b.get("queue") != null else []
	_queue_label.text = "Queue: %d/5" % q.size()
	var timer: float = b.get("production_timer") if b.get("production_timer") != null else 0.0
	_timer_label.text = "Idle" if q.is_empty() else "%.1fs" % timer
	_train_btn.visible = b.has_method("has_train_slot") and b.has_train_slot(0)
	_train2_btn.visible = b.has_method("has_train_slot") and b.has_train_slot(1)
	if _train_btn.visible:
		_train_btn.text = "%s (%s)" % [b.get_train_label(0), b.get_train_cost_label(0)]
	if _train2_btn.visible:
		_train2_btn.text = "%s (%s)" % [b.get_train_label(1), b.get_train_cost_label(1)]
