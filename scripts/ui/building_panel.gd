extends CanvasLayer

@onready var _side_panel: PanelContainer = $SidePanel
@onready var _name_label: Label = $SidePanel/Margin/VBox/NameLabel
@onready var _hp_label: Label = $SidePanel/Margin/VBox/HPLabel
@onready var _queue_label: Label = $SidePanel/Margin/VBox/QueueLabel
@onready var _timer_label: Label = $SidePanel/Margin/VBox/TimerLabel
@onready var _train_btn: Button = $SidePanel/Margin/VBox/TrainBtn
@onready var _train2_btn: Button = $SidePanel/Margin/VBox/Train2Btn
@onready var _train3_btn: Button = $SidePanel/Margin/VBox/Train3Btn
@onready var _research_label: Label = $SidePanel/Margin/VBox/ResearchLabel
@onready var _research_atk_btn: Button = $SidePanel/Margin/VBox/ResearchAtkBtn
@onready var _research_armor_btn: Button = $SidePanel/Margin/VBox/ResearchArmorBtn
@onready var _barracks_btn: Button = $BottomBar/Margin/HBox/BarracksBtn
@onready var _tc_btn: Button = $BottomBar/Margin/HBox/TCBtn
@onready var _tower_btn: Button = $BottomBar/Margin/HBox/TowerBtn
@onready var _monument_btn: Button = $BottomBar/Margin/HBox/MonumentBtn

var _selected_building: Node = null

func _ready() -> void:
	_barracks_btn.pressed.connect(func(): BuildingPlacer.start_placement("barracks"))
	_tc_btn.pressed.connect(func(): BuildingPlacer.start_placement("tc"))
	_tower_btn.pressed.connect(func(): BuildingPlacer.start_placement("tower"))
	_monument_btn.pressed.connect(func(): BuildingPlacer.start_placement("monument"))
	_train_btn.pressed.connect(func(): _try_train(0))
	_train2_btn.pressed.connect(func(): _try_train(1))
	_train3_btn.pressed.connect(func(): _try_train(2))
	_research_atk_btn.pressed.connect(func(): _try_research("atk"))
	_research_armor_btn.pressed.connect(func(): _try_research("armor"))
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

func _try_research(research_id: String) -> void:
	if _selected_building == null:
		return
	if _selected_building.has_method("try_queue_research"):
		_selected_building.try_queue_research(research_id)

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
	_train3_btn.visible = b.has_method("has_train_slot") and b.has_train_slot(2)
	if _train_btn.visible:
		_train_btn.text = "%s (%s)" % [b.get_train_label(0), b.get_train_cost_label(0)]
	if _train2_btn.visible:
		_train2_btn.text = "%s (%s)" % [b.get_train_label(1), b.get_train_cost_label(1)]
	if _train3_btn.visible:
		_train3_btn.text = "%s (%s)" % [b.get_train_label(2), b.get_train_cost_label(2)]
	_refresh_research(b)

## Research is offered on the player's Town Center only. Buttons are static
## scene nodes (this runs every frame — never build controls here).
func _refresh_research(b: Node) -> void:
	var is_player_tc: bool = String(b.get("building_name")) == "Town Center" \
		and b.get("faction_id") != null \
		and FactionManager.is_player_faction(int(b.get("faction_id")))
	_research_label.visible = is_player_tc
	_research_atk_btn.visible = is_player_tc
	_research_armor_btn.visible = is_player_tc
	if not is_player_tc:
		return
	_research_label.text = "Upgrades: ATK %d / ARM %d" % [GameStats.atk_level, GameStats.armor_level]
	_set_research_button(_research_atk_btn, "atk", "ATK", GameStats.atk_level, b)
	_set_research_button(_research_armor_btn, "armor", "ARM", GameStats.armor_level, b)

func _set_research_button(btn: Button, research_id: String, tag: String, level: int, b: Node) -> void:
	var levels: Array = b.RESEARCH[research_id]["levels"]
	if level >= levels.size():
		btn.text = "%s MAX" % tag
		btn.disabled = true
		return
	btn.disabled = false
	var tier: Dictionary = levels[level]
	var parts: PackedStringArray = PackedStringArray()
	for type in tier["cost"]:
		parts.append("%d%s" % [int(tier["cost"][type]), "W" if type == "madera" else "G"])
	btn.text = "%s %s (%s)" % [tag, "II" if level == 1 else "I", ", ".join(parts)]
