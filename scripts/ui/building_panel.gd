extends CanvasLayer

@onready var _side_panel: PanelContainer = $SidePanel
@onready var _name_label: Label = $SidePanel/Margin/VBox/NameLabel
@onready var _hp_label: Label = $SidePanel/Margin/VBox/HPLabel
@onready var _queue_label: Label = $SidePanel/Margin/VBox/QueueLabel
@onready var _timer_label: Label = $SidePanel/Margin/VBox/TimerLabel
@onready var _cancel_btn: Button = $SidePanel/Margin/VBox/CancelBtn
@onready var _train_btn: Button = $SidePanel/Margin/VBox/TrainBtn
@onready var _train2_btn: Button = $SidePanel/Margin/VBox/Train2Btn
@onready var _train3_btn: Button = $SidePanel/Margin/VBox/Train3Btn
@onready var _train4_btn: Button = $SidePanel/Margin/VBox/Train4Btn
@onready var _research_label: Label = $SidePanel/Margin/VBox/ResearchLabel
@onready var _research_atk_btn: Button = $SidePanel/Margin/VBox/ResearchAtkBtn
@onready var _research_armor_btn: Button = $SidePanel/Margin/VBox/ResearchArmorBtn
@onready var _research_cav_btn: Button = $SidePanel/Margin/VBox/ResearchCavalryBtn
@onready var _research_era_btn: Button = $SidePanel/Margin/VBox/ResearchEraBtn

## Faction-flavoured name for the signature cavalry-charge tech.
const SIGNATURE_NAME: Dictionary = {0: "Jaguar Fury", 1: "Blight Surge", 2: "Lattice Charge"}
@onready var _barracks_btn: Button = $BottomBar/Margin/HBox/BarracksBtn
@onready var _tc_btn: Button = $BottomBar/Margin/HBox/TCBtn
@onready var _tower_btn: Button = $BottomBar/Margin/HBox/TowerBtn
@onready var _monument_btn: Button = $BottomBar/Margin/HBox/MonumentBtn
@onready var _farm_btn: Button = $BottomBar/Margin/HBox/FarmBtn
@onready var _storehouse_btn: Button = $BottomBar/Margin/HBox/StorehouseBtn
@onready var _house_btn: Button = $BottomBar/Margin/HBox/HouseBtn

var _selected_building: Node = null

func _ready() -> void:
	_barracks_btn.pressed.connect(func(): BuildingPlacer.start_placement("barracks"))
	_tc_btn.pressed.connect(func(): BuildingPlacer.start_placement("tc"))
	_tower_btn.pressed.connect(func(): BuildingPlacer.start_placement("tower"))
	_monument_btn.pressed.connect(func(): BuildingPlacer.start_placement("monument"))
	_farm_btn.pressed.connect(func(): BuildingPlacer.start_placement("farm"))
	_storehouse_btn.pressed.connect(func(): BuildingPlacer.start_placement("storehouse"))
	_house_btn.pressed.connect(func(): BuildingPlacer.start_placement("house"))
	_cancel_btn.pressed.connect(_on_cancel)
	_train_btn.pressed.connect(func(): _try_train(0))
	_train2_btn.pressed.connect(func(): _try_train(1))
	_train3_btn.pressed.connect(func(): _try_train(2))
	_train4_btn.pressed.connect(func(): _try_train(3))
	_research_atk_btn.pressed.connect(func(): _try_research("atk"))
	_research_cav_btn.pressed.connect(func(): _try_research("cavalry"))
	_research_armor_btn.pressed.connect(func(): _try_research("armor"))
	_research_era_btn.pressed.connect(func(): _try_research("era"))
	# Build-button icons (graceful: skip any that aren't present yet).
	_set_btn_icon(_barracks_btn, "bld_barracks")
	_set_btn_icon(_tc_btn, "bld_tc")
	_set_btn_icon(_tower_btn, "bld_tower")
	_set_btn_icon(_monument_btn, "bld_monument")
	_set_btn_icon(_farm_btn, "bld_farm")
	# Cost on hover (the placement ghost also shows it while placing).
	for pair in [[_barracks_btn, "barracks"], [_tc_btn, "tc"], [_tower_btn, "tower"], [_monument_btn, "monument"], [_farm_btn, "farm"], [_storehouse_btn, "storehouse"], [_house_btn, "house"]]:
		(pair[0] as Button).tooltip_text = "%s  (%s)" % [(pair[0] as Button).text, BuildingPlacer.cost_text(pair[1])]
	for b in [_train_btn, _train2_btn, _train3_btn, _train4_btn]:
		b.add_theme_constant_override("icon_max_width", 18)
	SelectionManager.building_selected.connect(show_building)
	SelectionManager.building_deselected.connect(hide_building)
	_side_panel.visible = false

## Sets a button's left icon from assets/ui/icons/<key>.png if it exists.
func _set_btn_icon(btn: Button, key: String) -> void:
	var path: String = "res://assets/ui/icons/%s.png" % key
	if ResourceLoader.exists(path):
		btn.icon = load(path)
		btn.add_theme_constant_override("icon_max_width", 20)

## Maps a unit's train label to its archetype icon key.
func _unit_icon_key(label: String) -> String:
	var l: String = label.to_lower()
	if l.contains("archer"):
		return "unit_archer"
	if l.contains("raider") or l.contains("lancer") or l.contains("rider"):
		return "unit_raider"
	if l.contains("guard"):
		return "unit_guard"
	if l.contains("villager") or l.contains("weaver"):
		return "unit_villager"
	if l.contains("catapult") or l.contains("cannon") or l.contains("engine") or l.contains("siege"):
		return "unit_siege"  # no icon ships yet → button shows text only
	return "unit_soldier"

func _apply_train_icon(btn: Button, label: String) -> void:
	var path: String = "res://assets/ui/icons/%s.png" % _unit_icon_key(label)
	if not ResourceLoader.exists(path):
		return
	var tex: Texture2D = load(path)
	if btn.icon != tex:
		btn.icon = tex

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

func _on_cancel() -> void:
	if _selected_building != null and _selected_building.has_method("cancel_last"):
		_selected_building.cancel_last()

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
	_cancel_btn.visible = not q.is_empty()
	_train_btn.visible = b.has_method("has_train_slot") and b.has_train_slot(0)
	_train2_btn.visible = b.has_method("has_train_slot") and b.has_train_slot(1)
	_train3_btn.visible = b.has_method("has_train_slot") and b.has_train_slot(2)
	_train4_btn.visible = b.has_method("has_train_slot") and b.has_train_slot(3)
	if _train_btn.visible:
		_train_btn.text = "%s (%s)" % [b.get_train_label(0), b.get_train_cost_label(0)]
		_apply_train_icon(_train_btn, b.get_train_label(0))
	if _train2_btn.visible:
		_train2_btn.text = "%s (%s)" % [b.get_train_label(1), b.get_train_cost_label(1)]
		_apply_train_icon(_train2_btn, b.get_train_label(1))
	if _train3_btn.visible:
		_train3_btn.text = "%s (%s)" % [b.get_train_label(2), b.get_train_cost_label(2)]
		_apply_train_icon(_train3_btn, b.get_train_label(2))
	if _train4_btn.visible:
		_train4_btn.text = "%s (%s)" % [b.get_train_label(3), b.get_train_cost_label(3)]
		_apply_train_icon(_train4_btn, b.get_train_label(3))
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
	_research_cav_btn.visible = is_player_tc
	_research_era_btn.visible = is_player_tc
	if not is_player_tc:
		return
	_research_label.text = "Era %d  ·  ATK %d / ARM %d" % [GameStats.era, GameStats.atk_level, GameStats.armor_level]
	_set_era_button(_research_era_btn, b)
	_set_research_button(_research_atk_btn, "atk", "ATK", GameStats.atk_level, b)
	_set_research_button(_research_armor_btn, "armor", "ARM", GameStats.armor_level, b)
	var sig_name: String = SIGNATURE_NAME.get(GameSettings.player_faction_id, "Cavalry Charge")
	_set_research_button(_research_cav_btn, "cavalry", sig_name, GameStats.cavalry_level, b)

## The era button shows the era you'd advance TO (its cost), or maxed.
func _set_era_button(btn: Button, b: Node) -> void:
	var levels: Array = b.RESEARCH["era"]["levels"]
	var lvl: int = GameStats.get_research_level("era")
	if lvl >= levels.size():
		btn.text = "Era %d (max)" % GameStats.era
		btn.disabled = true
		return
	btn.disabled = false
	var tier: Dictionary = levels[lvl]
	var parts: PackedStringArray = PackedStringArray()
	for type in tier["cost"]:
		parts.append("%d%s" % [int(tier["cost"][type]), "W" if type == "madera" else "G"])
	btn.text = "Advance to Era %d (%s)" % [GameStats.era + 1, ", ".join(parts)]

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
