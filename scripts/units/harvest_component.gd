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
@export var map_bounds:       Rect2  = Rect2(0.0, 0.0, 2048.0, 2048.0)

var _state:        State             = State.IDLE
var _target_node:  ResourceNode      = null
var _nav_agent:    NavigationAgent2D = null
var _home:         Node2D            = null
var _faction_id:   int               = 0
var _timer:        float             = 0.0
var _carrying:     int               = 0
var _carry_type:   StringName        = &""

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
	if _home == null:
		_deposit_and_resume()
		return
	if unit_pos.distance_to(_home.global_position) <= 64.0:
		_deposit_and_resume()
		return
	_nav_agent.target_position = _safe_target(_home.global_position)

func _deposit_and_resume() -> void:
	if _carrying > 0 and _carry_type != &"":
		ResourceManager.add_resource(_carry_type, _carrying, _faction_id)
		if _faction_id == FactionManager.PLAYER:
			GameStats.resources_gathered += _carrying
		deposit_made.emit(_carry_type, _carrying)
	_carrying   = 0
	_carry_type = &""
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
