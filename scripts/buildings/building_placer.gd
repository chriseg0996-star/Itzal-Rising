extends Node

const MAP_BOUNDS: Rect2 = Rect2(0, 0, 2048, 2048)

const ACTION_BARRACKS: StringName = &"build_barracks"
const ACTION_TC: StringName = &"build_town_center"
const ACTION_TOWER: StringName = &"build_tower"

const BUILDING_DATA: Dictionary = {
	"tc": {
		"size": Vector2(96, 96),
		"cost": {"madera": 100},
	},
	"barracks": {
		"size": Vector2(80, 80),
		"cost": {"madera": 100, "oro": 50},
	},
	"tower": {
		"size": Vector2(48, 48),
		"cost": {"madera": 150, "oro": 50},
	},
}

## Faction-routed building scenes. The one acceptable hardcoded-path location:
## faction_id -> building key -> scene path. Factions without a buildable set
## (Decay) fall back to faction 0's entry in get_building_scene().
const FACTION_BUILDING_SCENES: Dictionary = {
	0: {
		&"tc": "res://scenes/buildings/TownCenter.tscn",
		&"barracks": "res://scenes/buildings/Barracks.tscn",
		&"tower": "res://scenes/buildings/Tower.tscn",
	},
	2: {
		&"tc": "res://scenes/buildings/IxTownCenter.tscn",
		&"barracks": "res://scenes/buildings/IxBarracks.tscn",
		&"tower": "res://scenes/buildings/IxTower.tscn",
	},
}

const COLOR_AFFORDABLE: Color = Color(0.3, 1.0, 0.3, 0.45)
const COLOR_BLOCKED: Color = Color(1.0, 0.3, 0.3, 0.45)

var current_type: String = ""
var preview_root: Node2D
var preview_rect: ColorRect

func _ready() -> void:
	preview_root = Node2D.new()
	preview_root.name = "Preview"
	preview_root.visible = false
	preview_root.z_index = 100
	preview_rect = ColorRect.new()
	preview_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_root.add_child(preview_rect)
	add_child(preview_root)

func is_placing() -> bool:
	return current_type != ""

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
	current_type = type
	var size: Vector2 = BUILDING_DATA[type].size
	preview_rect.offset_left = -size.x * 0.5
	preview_rect.offset_top = -size.y * 0.5
	preview_rect.offset_right = size.x * 0.5
	preview_rect.offset_bottom = size.y * 0.5
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
	else:
		preview_rect.color = COLOR_BLOCKED

func _unhandled_input(event: InputEvent) -> void:
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
	if not is_placing():
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if not mb.pressed:
			return
		if mb.button_index == MOUSE_BUTTON_LEFT:
			var pos: Vector2 = preview_root.get_global_mouse_position()
			print("colocando edificio en ", pos)
			_try_place()
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			cancel_placement()
			get_viewport().set_input_as_handled()

func _can_afford(cost: Dictionary) -> bool:
	return ResourceManager.can_afford(cost)

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
	ResourceManager.spend(cost)
	var building: Node = packed.instantiate()
	var target_parent: Node = get_tree().current_scene
	if target_parent == null:
		return
	target_parent.add_child(building)
	if building is Node2D:
		(building as Node2D).global_position = world_pos
	SoundManager.play("building_place")
	Particles.spawn(get_tree().current_scene, "building_place", world_pos)
	cancel_placement()
