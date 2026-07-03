class_name HarvestComponent
extends Node

signal harvest_started(node: ResourceNode)
signal harvest_stopped()
signal deposit_made(type: StringName, amount: int)

enum State { IDLE, MOVING_TO_NODE, HARVESTING, RETURNING }

@export var harvest_interval: float  = 1.5
@export var harvest_range:    float  = 80.0
@export var carry_capacity:   int    = 20
## Set this to match your NavigationRegion2D polygon extents in the Inspector.
@export var map_bounds:       Rect2  = Rect2(0.0, 0.0, MapConfig.WORLD_SIZE, MapConfig.WORLD_SIZE)

var _state:        State             = State.IDLE
var _target_node:  ResourceNode      = null
var _nav_agent:    NavigationAgent2D = null
var _home:         Node2D            = null
var _faction_id:   int               = 0
var _timer:        float             = 0.0
var _carrying:     int               = 0
var _carry_type:   StringName        = &""
var _dropoff:      Node2D            = null  ## chosen drop-off for the current trip

## The resource type this worker is currently working (target node's type, or
## what it's carrying home). Empty when idle — feeds the HUD economy readout.
func current_type() -> StringName:
	if _state == State.IDLE:
		return &""
	if _target_node != null and is_instance_valid(_target_node):
		return ResourceManager._normalize(_target_node.resource_type)
	if _carrying > 0:
		return ResourceManager._normalize(_carry_type)
	return &""

func setup(nav_agent: NavigationAgent2D, home: Node2D, faction_id: int = 0) -> void:
	_nav_agent = nav_agent
	_home      = home
	_faction_id = faction_id

func assign_node(node: ResourceNode) -> void:
	if node == null or node.is_depleted():
		return
	_target_node = node
	_carrying    = 0
	_carry_type  = &""
	_set_state(State.MOVING_TO_NODE)
	harvest_started.emit(node)

func stop() -> void:
	_target_node = null
	_set_state(State.IDLE)
	harvest_stopped.emit()

func is_active() -> bool:
	return _state != State.IDLE

func tick(delta: float, unit_position: Vector2) -> void:
	_timer += delta
	match _state:
		State.MOVING_TO_NODE: _tick_moving(unit_position)
		State.HARVESTING:     _tick_harvesting()
		State.RETURNING:      _tick_returning(unit_position)

func _tick_moving(unit_pos: Vector2) -> void:
	if _target_node == null or _target_node.is_depleted():
		_set_state(State.IDLE)
		return
	if unit_pos.distance_to(_target_node.global_position) <= harvest_range:
		_nav_agent.target_position = unit_pos
		_set_state(State.HARVESTING)
		return
	_nav_agent.target_position = _safe_target(_target_node.global_position)

func _tick_harvesting() -> void:
	if _target_node == null or _target_node.is_depleted():
		_set_state(State.IDLE)
		return
	if _timer < harvest_interval:
		return
	_timer      = 0.0
	var gained: int = _target_node.harvest()
	_carrying  += gained
	_carry_type = _target_node.resource_type
	if _carrying >= carry_capacity:
		_set_state(State.RETURNING)

func _tick_returning(unit_pos: Vector2) -> void:
	var dest: Node2D = _drop_target(unit_pos)
	if dest == null:
		_deposit_and_resume()
		return
	if unit_pos.distance_to(dest.global_position) <= 64.0:
		_deposit_and_resume()
		return
	_nav_agent.target_position = _safe_target(dest.global_position)

## Drop-off for this trip: the nearest friendly Town Center (so a villager that
## gathers near a freshly-built TC deposits there instead of trekking home).
## Cached per trip, recomputed after each deposit.
func _drop_target(from: Vector2) -> Node2D:
	if _dropoff != null and is_instance_valid(_dropoff):
		return _dropoff
	_dropoff = _nearest_dropoff(from)
	return _dropoff

func _nearest_dropoff(from: Vector2) -> Node2D:
	var best: Node2D = null
	var best_dist: float = INF
	# Town Centers AND Storehouses both accept deposits (group "dropoff").
	for d_node in get_tree().get_nodes_in_group("dropoff"):
		if not is_instance_valid(d_node) or not (d_node is Node2D):
			continue
		if int(d_node.get("faction_id")) != _faction_id:
			continue
		# A storehouse under construction isn't a valid drop-off yet.
		if d_node.get("under_construction") == true:
			continue
		var d: float = from.distance_to((d_node as Node2D).global_position)
		if d < best_dist:
			best_dist = d
			best = d_node as Node2D
	return best if best != null else _home

func _deposit_and_resume() -> void:
	if _carrying > 0 and _carry_type != &"":
		ResourceManager.add_resource(_carry_type, _carrying, _faction_id)
		if FactionManager.is_player_faction(_faction_id):
			GameStats.resources_gathered += _carrying
		deposit_made.emit(_carry_type, _carrying)
	_carrying   = 0
	_carry_type = &""
	_dropoff    = null  # recompute nearest drop-off for the next trip
	if _target_node != null and not _target_node.is_depleted():
		_set_state(State.MOVING_TO_NODE)
	else:
		_set_state(State.IDLE)

func _set_state(new_state: State) -> void:
	_state = new_state
	_timer = 0.0

# ── Nav safety ────────────────────────────────

## Clamps a world position to map_bounds before passing to NavigationAgent2D.
## Prevents the agent from computing paths that exit the NavigationRegion2D.
func _safe_target(world_pos: Vector2) -> Vector2:
	var b: Rect2 = map_bounds.grow(-4.0)
	return world_pos.clamp(b.position, b.end)
