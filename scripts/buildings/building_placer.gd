extends Node

const MAP_BOUNDS: Rect2 = Rect2(0, 0, MapConfig.WORLD_SIZE, MapConfig.WORLD_SIZE)

const ACTION_BARRACKS: StringName = &"build_barracks"
const ACTION_TC: StringName = &"build_town_center"
const ACTION_TOWER: StringName = &"build_tower"
const ACTION_MONUMENT: StringName = &"build_monument"
const ACTION_FARM: StringName = &"build_farm"

const BUILDING_DATA: Dictionary = {
	"tc": {
		"size": Vector2(96, 96),
		"cost": {"madera": 100},
		"build_time": 25.0,
	},
	"barracks": {
		"size": Vector2(80, 80),
		"cost": {"madera": 100, "oro": 50},
		"build_time": 18.0,
	},
	"tower": {
		"size": Vector2(48, 48),
		"cost": {"madera": 150, "oro": 50},
		"build_time": 12.0,
	},
	"monument": {
		"size": Vector2(64, 64),
		"cost": {"madera": 400, "oro": 300},
		"build_time": 35.0,
	},
	"farm": {
		"size": Vector2(72, 64),
		"cost": {"madera": 60},
		"build_time": 8.0,
	},
	"storehouse": {
		"size": Vector2(64, 50),
		"cost": {"madera": 80},
		"build_time": 10.0,
	},
	"house": {
		"size": Vector2(56, 56),
		"cost": {"madera": 50},
		"build_time": 8.0,
	},
	"pylon": {
		"size": Vector2(44, 44),
		"cost": {"madera": 75, "oro": 25},
		"build_time": 10.0,
	},
	"beacon": {
		"size": Vector2(80, 64),
		"cost": {"madera": 400, "oro": 300},
		"build_time": 30.0,
	},
}

## Faction-routed building scenes. The one acceptable hardcoded-path location:
## faction_id -> building key -> scene path. Unknown factions fall back to
## faction 0's entry in get_building_scene().
const FACTION_BUILDING_SCENES: Dictionary = {
	0: {
		&"tc": "res://scenes/buildings/TownCenter.tscn",
		&"barracks": "res://scenes/buildings/Barracks.tscn",
		&"tower": "res://scenes/buildings/Tower.tscn",
		&"monument": "res://scenes/buildings/Monument.tscn",
		&"farm": "res://scenes/buildings/Farm.tscn",
		&"storehouse": "res://scenes/buildings/Storehouse.tscn",
		&"house": "res://scenes/buildings/House.tscn",
		&"pylon": "res://scenes/buildings/ObsidianPylon.tscn",
		&"beacon": "res://scenes/buildings/AscensionBeacon.tscn",
	},
	1: {
		&"tc": "res://scenes/buildings/EnemyTownCenter.tscn",
		&"barracks": "res://scenes/buildings/EnemyBarracks.tscn",
		&"tower": "res://scenes/buildings/EnemyTower.tscn",
		&"monument": "res://scenes/buildings/Monument.tscn",
		&"farm": "res://scenes/buildings/Farm.tscn",
		&"storehouse": "res://scenes/buildings/Storehouse.tscn",
		&"house": "res://scenes/buildings/House.tscn",
		&"pylon": "res://scenes/buildings/ObsidianPylon.tscn",
		&"beacon": "res://scenes/buildings/AscensionBeacon.tscn",
	},
	2: {
		&"tc": "res://scenes/buildings/IxTownCenter.tscn",
		&"barracks": "res://scenes/buildings/IxBarracks.tscn",
		&"tower": "res://scenes/buildings/IxTower.tscn",
		&"monument": "res://scenes/buildings/Monument.tscn",
		&"farm": "res://scenes/buildings/Farm.tscn",
		&"storehouse": "res://scenes/buildings/Storehouse.tscn",
		&"house": "res://scenes/buildings/House.tscn",
		&"pylon": "res://scenes/buildings/ObsidianPylon.tscn",
		&"beacon": "res://scenes/buildings/AscensionBeacon.tscn",
	},
}

const COLOR_AFFORDABLE: Color = Color(0.3, 1.0, 0.3, 0.45)
const COLOR_BLOCKED: Color = Color(1.0, 0.3, 0.3, 0.45)

var current_type: String = ""
var preview_root: Node2D
var preview_rect: ColorRect
var preview_cost: Label

func _ready() -> void:
	preview_root = Node2D.new()
	preview_root.name = "Preview"
	preview_root.visible = false
	preview_root.z_index = 100
	preview_rect = ColorRect.new()
	preview_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_root.add_child(preview_rect)
	preview_cost = Label.new()
	preview_cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview_cost.add_theme_font_size_override("font_size", 15)
	preview_cost.add_theme_constant_override("outline_size", 6)
	preview_cost.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	preview_root.add_child(preview_cost)
	add_child(preview_root)

## "100W 50G" style cost string for a building type.
func cost_text(type: String) -> String:
	var cost: Dictionary = BUILDING_DATA.get(type, {}).get("cost", {})
	var parts: PackedStringArray = PackedStringArray()
	for k in cost:
		var letter: String = "W" if k == "madera" else ("G" if k == "oro" else "F")
		parts.append("%d%s" % [int(cost[k]), letter])
	return " ".join(parts)

func is_placing() -> bool:
	return current_type != ""

func _player_has_barracks() -> bool:
	for b in get_tree().get_nodes_in_group("player_buildings"):
		if is_instance_valid(b) and String(b.get("building_name")) == "Barracks" and not bool(b.get("under_construction")):
			return true
	return false

func get_building_scene(faction_id: int, key: StringName) -> PackedScene:
	var by_faction: Dictionary = FACTION_BUILDING_SCENES.get(faction_id, {})
	var path: String = String(by_faction.get(key, ""))
	if path.is_empty():
		path = String((FACTION_BUILDING_SCENES[0] as Dictionary).get(key, ""))
	if path.is_empty():
		return null
	return load(path) as PackedScene

func start_placement(type: StringName) -> void:
	if not BUILDING_DATA.has(type):
		return
	# The Ascension Beacon is late-game tech: it requires a standing Barracks.
	if type == &"beacon" and not _player_has_barracks():
		AlertManager.push("Ascension Beacon requires a Barracks", "warning")
		return
	current_type = type
	var size: Vector2 = BUILDING_DATA[type].size
	preview_rect.offset_left = -size.x * 0.5
	preview_rect.offset_top = -size.y * 0.5
	preview_rect.offset_right = size.x * 0.5
	preview_rect.offset_bottom = size.y * 0.5
	preview_cost.text = "%s   %s" % [String(type).capitalize(), cost_text(type)]
	preview_cost.size.x = 200.0
	preview_cost.position = Vector2(-100.0, -size.y * 0.5 - 30.0)
	preview_root.visible = true

func cancel_placement() -> void:
	current_type = ""
	preview_root.visible = false

func _process(_delta: float) -> void:
	if not is_placing():
		return
	var mouse_world: Vector2 = preview_root.get_global_mouse_position()
	preview_root.global_position = mouse_world
	var cost: Dictionary = BUILDING_DATA[current_type].cost
	if _can_afford(cost):
		preview_rect.color = COLOR_AFFORDABLE
		preview_cost.modulate = Color(0.6, 1.0, 0.6)
	else:
		preview_rect.color = COLOR_BLOCKED
		preview_cost.modulate = Color(1.0, 0.5, 0.45)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_H:
		start_placement("storehouse")
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_U:
		start_placement("house")
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_P:
		start_placement("pylon")
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(ACTION_BARRACKS):
		start_placement("barracks")
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(ACTION_TC):
		start_placement("tc")
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(ACTION_TOWER):
		start_placement("tower")
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(ACTION_MONUMENT):
		start_placement("monument")
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(ACTION_FARM):
		start_placement("farm")
		get_viewport().set_input_as_handled()
		return
	if not is_placing():
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if not mb.pressed:
			return
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_try_place()
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			cancel_placement()
			get_viewport().set_input_as_handled()

func _can_afford(cost: Dictionary) -> bool:
	return ResourceManager.can_afford(cost, GameSettings.player_faction_id)

## Send a player villager to build the new foundation: nearest idle one, or the
## nearest of any (pulled off its task) if none are idle.
func _assign_builder(site: Node, pos: Vector2) -> void:
	var idle_best: Node = null
	var idle_d: float = INF
	var any_best: Node = null
	var any_d: float = INF
	for v in get_tree().get_nodes_in_group("villagers"):
		if not is_instance_valid(v) or not (v is Node2D):
			continue
		if int(v.get("faction_id")) != GameSettings.player_faction_id:
			continue
		if not v.has_method("build_structure"):
			continue
		var d: float = pos.distance_to((v as Node2D).global_position)
		if d < any_d:
			any_d = d
			any_best = v
		var busy: bool = v.has_method("is_busy") and v.is_busy()
		if not busy and d < idle_d:
			idle_d = d
			idle_best = v
	var builder: Node = idle_best if idle_best != null else any_best
	if builder != null:
		builder.build_structure(site)

func _try_place() -> void:
	var world_pos: Vector2 = preview_root.get_global_mouse_position()
	preview_root.global_position = world_pos
	if not MAP_BOUNDS.has_point(world_pos):
		return
	var cost: Dictionary = BUILDING_DATA[current_type].cost
	if not _can_afford(cost):
		return
	var packed: PackedScene = get_building_scene(GameSettings.player_faction_id, StringName(current_type))
	if packed == null:
		return
	ResourceManager.spend(cost, GameSettings.player_faction_id)
	var building: Node = packed.instantiate()
	# Faction-shared scenes (Monument) need the owner stamped before _ready
	# derives groups; per-faction scenes already carry it baked — no-op there.
	building.set("faction_id", GameSettings.player_faction_id)
	var target_parent: Node = get_tree().current_scene
	if target_parent == null:
		return
	target_parent.add_child(building)
	if building is Node2D:
		(building as Node2D).global_position = world_pos
	# Foundation: a nearby villager auto-walks over and raises it over time.
	if building.has_method("begin_construction"):
		var bt: float = float(BUILDING_DATA[current_type].get("build_time", 12.0))
		building.begin_construction(bt)
		_assign_builder(building, world_pos)
	SoundManager.play("building_place")
	Particles.spawn(get_tree().current_scene, "building_place", world_pos)
	cancel_placement()
