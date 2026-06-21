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
	# Eras: advance the whole army's attack + armour. Two steps (Era II, III).
	"era": {
		"label": "Advance Era",
		"levels": [
			{"cost": {"madera": 250, "oro": 150}, "duration": 45.0},
			{"cost": {"madera": 500, "oro": 350}, "duration": 70.0},
		],
	},
}

@export var building_name: String = "Building"
@export var max_hp: int = 100
@export var faction_id: int = 0
@export var sprite_asset: String = ""
## Passive food income per second (Farms). 0 = no income.
@export var food_per_sec: float = 0.0
## Resource drop-off point (Storehouses); Town Centers also qualify by name.
@export var is_dropoff: bool = false
## Population headroom this building grants the player (Houses, Town Centers).
## The player's unit cap is the sum of this over their completed buildings.
@export var population_supply: int = 0

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

@export var train_unit_4_scene: PackedScene
@export var train_unit_4_label: String = ""
@export var train_4_costs: Dictionary = {}
@export var train_4_duration: float = 5.0

@export var attack_damage: int = 0
@export var attack_range: float = 0.0
@export var attack_interval: float = 0.0

const HP_BAR_WIDTH: float = 64.0
const HP_BAR_HEIGHT: float = 8.0
const HP_BAR_Y: float = -112.0  # fallback only; per-building value is computed
## Computed in _ready to sit just above each building's actual sprite top, so
## the bar hugs small Houses/Towers and tall Town Centers alike.
var _hp_bar_y: float = HP_BAR_Y
const HP_BAR_BG: Color = Color(0.08, 0.1, 0.12, 0.95)
const HP_BAR_OUTLINE: Color = Color(0.0, 0.0, 0.0, 0.85)

var hp: int
var queue: Array = []
var production_timer: float = 0.0
var attack_timer: float = 0.0
var dying: bool = false
var _food_accum: float = 0.0
var _damage_reduction: float = 0.0
var rally_point: Vector2 = Vector2.ZERO
var has_rally_point: bool = false
var _rally_marker: Node2D = null
var _base_modulate: Color = Color.WHITE
var _hp_fill_color: Color = Color(0.27, 0.86, 0.50)
## Construction: player-placed buildings start as a foundation that villagers
## raise over `_build_time` seconds (more builders = faster). Not functional and
## vulnerable until complete. AI/default buildings stay instant (never call begin).
var under_construction: bool = false
var build_progress: float = 0.0
var _build_time: float = 0.0
## Farm income only flows while a villager is working it (TTL refreshed by the
## worker each tick; expires shortly after it leaves or dies).
var _worker_ttl: float = 0.0

const CONSTRUCTION_TINT: Color = Color(0.55, 0.75, 1.0, 0.6)

func _ready() -> void:
	add_to_group("buildings")
	if FactionManager.is_player_faction(faction_id):
		add_to_group("player_buildings")
	else:
		add_to_group("enemy_buildings")
	if is_dropoff or building_name == "Town Center":
		add_to_group("dropoff")
	hp = max_hp
	if faction_id == FactionManager.IX:
		_apply_lattice_network()
	_apply_sprite(sprite_asset)
	_hp_bar_y = _compute_hp_bar_y()
	_base_modulate = modulate
	var fac: FactionData = FactionManager.get_faction(faction_id)
	if fac != null:
		_hp_fill_color = fac.primary_color
	if FactionManager.is_player_faction(faction_id):
		AlertManager.register_building(self)

## Ix "Lattice Network": if an allied Ix building sits within 300px, this building
## gains +15% max HP (and is restored to full). Evaluated once, on spawn.
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
		max_hp = int(round(float(max_hp) * 1.15))
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

## Player placement: start as a foundation. Villagers raise build_progress to 1.
func begin_construction(build_time: float) -> void:
	under_construction = true
	build_progress = 0.0
	_build_time = maxf(build_time, 0.1)
	hp = maxi(1, int(round(float(max_hp) * 0.25)))
	modulate = CONSTRUCTION_TINT
	queue_redraw()

## Called each physics tick by an adjacent builder. Builders stack (faster) and
## raise hp with progress; attacks still lower hp and can destroy the site.
func contribute_build(delta: float) -> void:
	if not under_construction or dying:
		return
	build_progress = clampf(build_progress + delta / _build_time, 0.0, 1.0)
	var target: int = int(round(float(max_hp) * lerpf(0.25, 1.0, build_progress)))
	if target > hp:
		hp = mini(target, max_hp)
	queue_redraw()
	if build_progress >= 1.0:
		_finish_construction()

func _finish_construction() -> void:
	under_construction = false
	build_progress = 1.0
	hp = max_hp
	modulate = _base_modulate
	SoundManager.play("building_place")
	queue_redraw()

func is_complete() -> bool:
	return not under_construction

## A farm worker refreshes this each tick it stands on the farm; income flows
## only while it is fresh (see _process).
func report_worker() -> void:
	_worker_ttl = 1.0

## Era gates: cavalry (slot 2) at Era II, siege (slot 3) at Era III.
const CAVALRY_ERA: int = 2
const SIEGE_ERA: int = 3

func _owner_era() -> int:
	return GameStats.era if FactionManager.is_player_faction(faction_id) else GameStats.ai_era

func has_train_slot(slot: int) -> bool:
	if slot == 0:
		return train_unit_scene != null
	if slot == 1:
		return train_unit_2_scene != null
	if slot == 2:
		return train_unit_3_scene != null and _owner_era() >= CAVALRY_ERA
	if slot == 3:
		return train_unit_4_scene != null and _owner_era() >= SIEGE_ERA
	return false

func get_train_cost_label(slot: int = 0) -> String:
	var costs: Dictionary = train_costs
	if slot == 1:
		costs = train_2_costs
	elif slot == 2:
		costs = train_3_costs
	elif slot == 3:
		costs = train_4_costs
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
	if slot == 3:
		return train_unit_4_label
	return train_unit_label

func try_queue_training(slot: int = 0) -> bool:
	if dying or under_construction:
		return false
	if not has_train_slot(slot):  # enforces the era gate on the cavalry slot
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
	elif slot == 3:
		scene = train_unit_4_scene
		costs = train_4_costs
		duration = train_4_duration
	else:
		return false
	if scene == null:
		return false
	# Population cap (player only — the AI is bounded by its own difficulty caps).
	# Cap is dynamic: build Houses (and Town Centers) to raise it, AoE-style.
	if FactionManager.is_player_faction(faction_id) and _player_population() >= GameSettings.player_pop_cap():
		AlertManager.push("Need more Houses (population limit)", "warn")
		return false
	if not ResourceManager.can_afford(costs, faction_id):
		return false
	ResourceManager.spend(costs, faction_id)
	_enqueue({"scene": scene, "duration": duration, "label": get_train_label(slot), "cost": costs})
	return true

## Living player units plus units still queued at any player building, so a full
## training queue can't push the army past the cap.
func _player_population() -> int:
	var count: int = get_tree().get_nodes_in_group("player_units").size()
	for b in get_tree().get_nodes_in_group("player_buildings"):
		if not is_instance_valid(b):
			continue
		var q: Variant = b.get("queue")
		if q is Array:
			for entry in q:
				if not (entry as Dictionary).has("research_id"):
					count += 1
	return count

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
	_enqueue({"scene": null, "duration": float(tier["duration"]), "research_id": research_id, "cost": costs})
	return true

## Cancels the most-recently queued item (training or research) and refunds its
## full cost. Cancelling the only item stops production; the active front item is
## otherwise left running. Called from the building panel's Cancel button.
func cancel_last() -> bool:
	if dying or queue.is_empty():
		return false
	var idx: int = queue.size() - 1
	var entry: Dictionary = queue[idx]
	var cost: Dictionary = entry.get("cost", {})
	for type in cost:
		ResourceManager.add_resource(String(type), int(cost[type]), faction_id)
	queue.remove_at(idx)
	if queue.is_empty():
		production_timer = 0.0
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
	# Aegis shield (Ix ability) reduces incoming damage while active.
	var actual: int = maxi(int(round(float(amount) * (1.0 - _damage_reduction))), 1)
	hp = max(0, hp - actual)
	SoundManager.play("building_hit", -8.0)
	_flash_hit()
	queue_redraw()
	DamageNumbers.spawn(get_tree().current_scene, float(actual), global_position + Vector2(0, HP_BAR_Y), Color(0.95, 0.95, 0.95))
	if FactionManager.is_player_faction(faction_id):
		building_damaged.emit(self)
	if hp <= 0:
		_die()

## Ability hook: restore HP up to the maximum.
func repair(amount: int) -> void:
	if dying:
		return
	hp = mini(hp + amount, max_hp)
	queue_redraw()

## Ability hook: temporary incoming-damage reduction (0..0.95) for `duration`.
func apply_shield(reduction: float, duration: float) -> void:
	_damage_reduction = clampf(reduction, 0.0, 0.95)
	await get_tree().create_timer(duration).timeout
	if is_instance_valid(self):
		_damage_reduction = 0.0

## Brief white flash on hit (mirrors villager.gd _flash_hit). modulate is an
## independent channel from the fog's visibility writes, so they don't fight.
func _flash_hit() -> void:
	if dying:
		return
	modulate = Color(2.0, 2.0, 2.0, _base_modulate.a)
	var tween := create_tween()
	tween.tween_property(self, "modulate", _base_modulate, 0.1)

## Sits the HP bar just above the building's rendered sprite (centered Sprite2D),
## so it hugs each building instead of floating at a fixed height.
func _compute_hp_bar_y() -> float:
	var spr: Node = get_node_or_null("BuildingSprite")
	if spr is Sprite2D and (spr as Sprite2D).texture != null:
		var s := spr as Sprite2D
		var frame_h: float = float(s.texture.get_height()) / float(maxi(1, s.vframes))
		var center_y: float = s.position.y + s.offset.y * s.scale.y
		return center_y - frame_h * s.scale.y * 0.5 - 8.0
	return HP_BAR_Y

const RING_COLOR: Color = Color(0.0, 0.88, 0.78, 1.0)
const RING_TRACK: Color = Color(0.06, 0.09, 0.12, 0.92)

## HP bar (only while damaged) + a production countdown ring (only while the
## player building is training/researching).
func _draw() -> void:
	if dying:
		return
	if max_hp > 0 and hp < max_hp:
		var ratio: float = clampf(float(hp) / float(max_hp), 0.0, 1.0)
		var origin := Vector2(-HP_BAR_WIDTH * 0.5, _hp_bar_y)
		# Dark outline so the bar reads against any terrain, then track, then fill.
		draw_rect(Rect2(origin - Vector2(1.5, 1.5), Vector2(HP_BAR_WIDTH + 3.0, HP_BAR_HEIGHT + 3.0)), HP_BAR_OUTLINE)
		draw_rect(Rect2(origin, Vector2(HP_BAR_WIDTH, HP_BAR_HEIGHT)), HP_BAR_BG)
		var fill: Color = _hp_fill_color.lerp(Color(0.85, 0.2, 0.15), 1.0 - ratio)
		draw_rect(Rect2(origin, Vector2(HP_BAR_WIDTH * ratio, HP_BAR_HEIGHT)), fill)
	_draw_production_ring()

## A reverse-sweeping countdown clock above the building: a teal arc that drains
## counter-clockwise from full as the unit builds, with the whole seconds left
## shown in the centre. Player buildings only (avoids leaking enemy timings).
func _draw_production_ring() -> void:
	if queue.is_empty() or production_timer <= 0.0:
		return
	if not FactionManager.is_player_faction(faction_id):
		return
	var dur: float = float(queue[0].get("duration", train_duration))
	if dur <= 0.0:
		return
	var frac: float = clampf(production_timer / dur, 0.0, 1.0)  # time remaining
	var center := Vector2(0.0, _hp_bar_y - 22.0)
	var radius := 16.0
	# Backing disc + full track ring.
	draw_circle(center, radius - 1.0, RING_TRACK)
	draw_arc(center, radius, 0.0, TAU, 48, Color(0.20, 0.26, 0.30, 0.9), 3.0, true)
	# Remaining-time arc, sweeping counter-clockwise from the top (12 o'clock).
	var start := -PI / 2.0
	draw_arc(center, radius, start, start - frac * TAU, 48, RING_COLOR, 3.5, true)
	# Whole seconds remaining, centred.
	var secs := str(int(ceil(production_timer)))
	var font := ThemeDB.fallback_font
	var fsize := 15
	var ts: Vector2 = font.get_string_size(secs, HORIZONTAL_ALIGNMENT_CENTER, -1, fsize)
	draw_string(font, center + Vector2(-ts.x * 0.5, ts.y * 0.32), secs, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, Color(0.95, 0.97, 0.98))

func _die() -> void:
	dying = true
	# Count enemy buildings the player razed (player-side losses aren't tallied
	# here — only destruction of hostiles matters for the summary).
	if not FactionManager.is_player_faction(faction_id):
		GameStats.buildings_destroyed += 1
	var cam: Node = get_tree().get_first_node_in_group("rts_camera")
	if cam != null and cam.has_method("shake"):
		cam.shake(6.0, 0.25)
	queue_free()

func _process(delta: float) -> void:
	if dying:
		return
	# A foundation does nothing until villagers finish it.
	if under_construction:
		return
	if _worker_ttl > 0.0:
		_worker_ttl = maxf(_worker_ttl - delta, 0.0)
	# Farm income flows only while a villager is working the farm.
	if food_per_sec > 0.0 and _worker_ttl > 0.0:
		_food_accum += delta * food_per_sec
		if _food_accum >= 1.0:
			var whole: int = int(_food_accum)
			_food_accum -= float(whole)
			ResourceManager.add_resource("comida", whole, faction_id)
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
	queue_redraw()  # animate the countdown ring (and clear it when the queue empties)

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
