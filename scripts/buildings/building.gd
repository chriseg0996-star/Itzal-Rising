extends Node2D

signal building_damaged(building: Node)

const MAX_QUEUE: int = 5
const SPAWN_OFFSET: Vector2 = Vector2(0, 80)

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

@export var attack_damage: int = 0
@export var attack_range: float = 0.0
@export var attack_interval: float = 0.0

var hp: int
var queue: Array = []
var production_timer: float = 0.0
var attack_timer: float = 0.0
var dying: bool = false

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
	if faction_id == FactionManager.PLAYER:
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
	return false

func get_train_cost_label(slot: int = 0) -> String:
	var costs: Dictionary = train_costs if slot == 0 else train_2_costs
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
	else:
		return false
	if scene == null:
		return false
	if not ResourceManager.can_afford(costs, faction_id):
		return false
	ResourceManager.spend(costs, faction_id)
	queue.append({"scene": scene, "duration": duration})
	if queue.size() == 1:
		production_timer = duration
	return true

func take_damage(amount: int) -> void:
	if dying:
		return
	hp = max(0, hp - amount)
	SoundManager.play("building_hit", -8.0)
	if faction_id == FactionManager.PLAYER:
		building_damaged.emit(self)
	if hp <= 0:
		_die()

func _die() -> void:
	dying = true
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
	if target.has_method("take_damage"):
		target.take_damage(attack_damage)
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
	if faction_id == FactionManager.PLAYER:
		GameStats.units_trained += 1
