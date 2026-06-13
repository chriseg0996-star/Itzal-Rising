extends Node2D

signal building_damaged(building: Node)

const MAX_QUEUE: int = 5
const SPAWN_OFFSET: Vector2 = Vector2(0, 80)

## Research available at the Town Center. Each id has 2 tiers; current levels
## live in GameStats (per-match, reset with it). Research shares the training
## queue via entries shaped {"scene": null, "duration": d, "research_id": id}.
const RESEARCH: Dictionary = {
	"atk": {
		"label": "Attack",
		"levels": [
			{"cost": {"madera": 100, "oro": 100}, "duration": 20.0},
			{"cost": {"madera": 200, "oro": 250}, "duration": 30.0},
		],
	},
	"armor": {
		"label": "Armor",
		"levels": [
			{"cost": {"madera": 100, "oro": 100}, "duration": 20.0},
			{"cost": {"madera": 200, "oro": 250}, "duration": 30.0},
		],
	},
	# Signature tech: a single powerful cavalry-charge upgrade (faction-flavoured
	# name in the UI). One tier.
	"cavalry": {
		"label": "Cavalry Charge",
		"levels": [
			{"cost": {"madera": 150, "oro": 150}, "duration": 25.0},
		],
	},
}

@export var building_name: String = "Building"
@export var max_hp: int = 100
@export var faction_id: int = 0
@export var sprite_asset: String = ""

@export var train_unit_scene: PackedScene
@export var train_unit_label: String = "Unit"
@export var train_costs: Dictionary = {}
@export var train_duration: float = 5.0

@export var train_unit_2_scene: PackedScene
@export var train_unit_2_label: String = ""
@export var train_2_costs: Dictionary = {}
@export var train_2_duration: float = 5.0

@export var train_unit_3_scene: PackedScene
@export var train_unit_3_label: String = ""
@export var train_3_costs: Dictionary = {}
@export var train_3_duration: float = 5.0

@export var attack_damage: int = 0
@export var attack_range: float = 0.0
@export var attack_interval: float = 0.0

const HP_BAR_WIDTH: float = 56.0
const HP_BAR_HEIGHT: float = 5.0
const HP_BAR_Y: float = -110.0
const HP_BAR_BG: Color = Color(0.08, 0.1, 0.12, 0.9)

var hp: int
var queue: Array = []
var production_timer: float = 0.0
var attack_timer: float = 0.0
var dying: bool = false
var rally_point: Vector2 = Vector2.ZERO
var has_rally_point: bool = false
var _rally_marker: Node2D = null
var _base_modulate: Color = Color.WHITE
var _hp_fill_color: Color = Color(0.27, 0.86, 0.50)

func _ready() -> void:
	add_to_group("buildings")
	if FactionManager.is_player_faction(faction_id):
		add_to_group("player_buildings")
	else:
		add_to_group("enemy_buildings")
	hp = max_hp
	if faction_id == FactionManager.IX:
		_apply_lattice_network()
	_apply_sprite(sprite_asset)
	_base_modulate = modulate
	var fac: FactionData = FactionManager.get_faction(faction_id)
	if fac != null:
		_hp_fill_color = fac.primary_color
	if FactionManager.is_player_faction(faction_id):
		AlertManager.register_building(self)

## Ix "Lattice Network": if an allied Ix building sits within 300px, this building
## gains +20% max HP (and is restored to full). Evaluated once, on spawn.
func _apply_lattice_network() -> void:
	var allies: int = 0
	for b in get_tree().get_nodes_in_group("buildings"):
		if b == self or not is_instance_valid(b) or not (b is Node2D):
			continue
		if int(b.get("faction_id")) != faction_id:
			continue
		if global_position.distance_to((b as Node2D).global_position) <= 300.0:
			allies += 1
	if allies >= 1:
		max_hp = int(round(float(max_hp) * 1.2))
		hp = max_hp

func _apply_sprite(asset: String) -> void:
	if asset == "":
		return
	var existing := get_node_or_null("Sprite")
	if existing != null and existing is CanvasItem:
		(existing as CanvasItem).visible = false
	var sprite_2d := Sprite2D.new()
	sprite_2d.texture = TextureGenerator.get_texture(asset)
	sprite_2d.centered = true
	add_child(sprite_2d)
	if existing != null:
		move_child(sprite_2d, existing.get_index() + 1)

func has_train_slot(slot: int) -> bool:
	if slot == 0:
		return train_unit_scene != null
	if slot == 1:
		return train_unit_2_scene != null
	if slot == 2:
		return train_unit_3_scene != null
	return false

func get_train_cost_label(slot: int = 0) -> String:
	var costs: Dictionary = train_costs
	if slot == 1:
		costs = train_2_costs
	elif slot == 2:
		costs = train_3_costs
	var parts: PackedStringArray = PackedStringArray()
	for type in costs:
		var letter: String = "?"
		match type:
			"madera": letter = "W"
			"comida": letter = "F"
			"oro": letter = "G"
		parts.append("%d%s" % [int(costs[type]), letter])
	return ", ".join(parts)

func get_train_label(slot: int = 0) -> String:
	if slot == 1:
		return train_unit_2_label
	if slot == 2:
		return train_unit_3_label
	return train_unit_label

func try_queue_training(slot: int = 0) -> bool:
	if dying:
		return false
	if queue.size() >= MAX_QUEUE:
		return false
	var scene: PackedScene
	var costs: Dictionary
	var duration: float
	if slot == 0:
		scene = train_unit_scene
		costs = train_costs
		duration = train_duration
	elif slot == 1:
		scene = train_unit_2_scene
		costs = train_2_costs
		duration = train_2_duration
	elif slot == 2:
		scene = train_unit_3_scene
		costs = train_3_costs
		duration = train_3_duration
	else:
		return false
	if scene == null:
		return false
	if not ResourceManager.can_afford(costs, faction_id):
		return false
	ResourceManager.spend(costs, faction_id)
	_enqueue({"scene": scene, "duration": duration})
	return true

func _enqueue(entry: Dictionary) -> void:
	queue.append(entry)
	if queue.size() == 1:
		production_timer = float(entry.get("duration", train_duration))

func try_queue_research(research_id: String) -> bool:
	if dying or not RESEARCH.has(research_id):
		return false
	if queue.size() >= MAX_QUEUE:
		return false
	var level: int = GameStats.get_research_level(research_id)
	var levels: Array = RESEARCH[research_id]["levels"]
	if level >= levels.size():
		return false
	# One of each research id in flight at a time.
	for entry in queue:
		if String(entry.get("research_id", "")) == research_id:
			return false
	var tier: Dictionary = levels[level]
	var costs: Dictionary = tier["cost"]
	if not ResourceManager.can_afford(costs, faction_id):
		return false
	ResourceManager.spend(costs, faction_id)
	_enqueue({"scene": null, "duration": float(tier["duration"]), "research_id": research_id})
	return true

## Persistent rally point: units finishing training walk here. The marker is a
## child Node2D so it moves/dies with the building.
func set_rally_point(world_pos: Vector2) -> void:
	rally_point = world_pos
	has_rally_point = true
	if _rally_marker == null:
		var marker := RallyMarker.new()
		marker.z_index = 50
		var fac: FactionData = FactionManager.get_faction(faction_id)
		if fac != null:
			marker.color = fac.primary_color
		add_child(marker)
		_rally_marker = marker
	_rally_marker.position = world_pos - global_position
	_rally_marker.queue_redraw()

func clear_rally_point() -> void:
	has_rally_point = false
	if _rally_marker != null:
		_rally_marker.queue_free()
		_rally_marker = null

func take_damage(amount: int) -> void:
	if dying:
		return
	hp = max(0, hp - amount)
	SoundManager.play("building_hit", -8.0)
	_flash_hit()
	queue_redraw()
	DamageNumbers.spawn(get_tree().current_scene, float(amount), global_position + Vector2(0, HP_BAR_Y), Color(0.95, 0.95, 0.95))
	if FactionManager.is_player_faction(faction_id):
		building_damaged.emit(self)
	if hp <= 0:
		_die()

## Brief white flash on hit (mirrors villager.gd _flash_hit). modulate is an
## independent channel from the fog's visibility writes, so they don't fight.
func _flash_hit() -> void:
	if dying:
		return
	modulate = Color(2.0, 2.0, 2.0, _base_modulate.a)
	var tween := create_tween()
	tween.tween_property(self, "modulate", _base_modulate, 0.1)

## HP bar floats above the building art while it is damaged.
func _draw() -> void:
	if dying or hp >= max_hp or max_hp <= 0:
		return
	var ratio: float = clampf(float(hp) / float(max_hp), 0.0, 1.0)
	var origin := Vector2(-HP_BAR_WIDTH * 0.5, HP_BAR_Y)
	draw_rect(Rect2(origin, Vector2(HP_BAR_WIDTH, HP_BAR_HEIGHT)), HP_BAR_BG)
	var fill: Color = _hp_fill_color.lerp(Color(0.85, 0.2, 0.15), 1.0 - ratio)
	draw_rect(Rect2(origin, Vector2(HP_BAR_WIDTH * ratio, HP_BAR_HEIGHT)), fill)

func _die() -> void:
	dying = true
	var cam: Node = get_tree().get_first_node_in_group("rts_camera")
	if cam != null and cam.has_method("shake"):
		cam.shake(6.0, 0.25)
	queue_free()

func _process(delta: float) -> void:
	if dying:
		return
	if attack_damage > 0 and attack_interval > 0.0:
		_attack_step(delta)
	if queue.is_empty():
		return
	production_timer -= delta
	if production_timer <= 0.0:
		var entry: Dictionary = queue[0]
		if entry.has("research_id"):
			GameStats.complete_research(String(entry["research_id"]))
		else:
			_spawn_unit(entry.get("scene"))
		queue.pop_front()
		if not queue.is_empty():
			production_timer = float(queue[0].get("duration", train_duration))

func _attack_step(delta: float) -> void:
	attack_timer += delta
	if attack_timer < attack_interval:
		return
	var target: Node = _find_enemy_in_range()
	if target == null:
		attack_timer = attack_interval
		return
	# Towers fire a projectile (damage applied on impact) in the faction colour.
	if target is Node2D:
		Projectile.fire(get_tree().current_scene, global_position, target as Node2D, float(attack_damage), _hp_fill_color)
	attack_timer = 0.0

func _find_enemy_in_range() -> Node:
	var nearest: Node = null
	var nearest_dist: float = INF
	for u in get_tree().get_nodes_in_group("combat_units"):
		if not is_instance_valid(u):
			continue
		var tfid: Variant = u.get("faction_id")
		if tfid == null or not FactionManager.is_hostile(faction_id, int(tfid)):
			continue
		if u.has_method("is_dying") and u.is_dying():
			continue
		var d: float = global_position.distance_to((u as Node2D).global_position)
		if d <= attack_range and d < nearest_dist:
			nearest_dist = d
			nearest = u
	return nearest

func _spawn_unit(scene: PackedScene) -> void:
	if scene == null:
		return
	var unit: Node = scene.instantiate()
	var parent: Node = get_parent()
	if parent == null:
		return
	parent.add_child(unit)
	if unit is Node2D:
		(unit as Node2D).global_position = global_position + SPAWN_OFFSET
	if has_rally_point and unit.has_method("move_to"):
		# Deferred so the unit's _ready/nav setup runs before the move order.
		unit.call_deferred("move_to", rally_point)
	if FactionManager.is_player_faction(faction_id):
		GameStats.units_trained += 1

class RallyMarker extends Node2D:
	var color: Color = Color(0.0, 0.85, 0.85, 1.0)

	func _draw() -> void:
		draw_line(Vector2.ZERO, Vector2(0, -18), color, 2.0, true)
		draw_colored_polygon(PackedVector2Array([
			Vector2(0, -18), Vector2(12, -14), Vector2(0, -10),
		]), color)
		draw_circle(Vector2.ZERO, 3.0, color)
