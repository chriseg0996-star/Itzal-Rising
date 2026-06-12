extends Node

signal resource_changed(type: StringName, new_amount: int)
signal resource_insufficient(type: StringName)

const WOOD: StringName = &"wood"
const FOOD: StringName = &"food"
const GOLD: StringName = &"gold"

const _ALIASES: Dictionary = {
	&"madera": &"wood",
	&"comida": &"food",
	&"oro": &"gold",
	&"wood": &"wood",
	&"food": &"food",
	&"gold": &"gold",
}

const _INITIAL: Dictionary = {
	&"wood": 200,
	&"food": 200,
	&"gold": 100,
}

var _resources: Dictionary = {}
var _enemy: Dictionary = {}

func _ready() -> void:
	reset()

func reset() -> void:
	_resources = _INITIAL.duplicate(true)
	_enemy = _INITIAL.duplicate(true)
	for type: StringName in _resources:
		resource_changed.emit(type, _resources[type])

func _normalize(type) -> StringName:
	var key: StringName = StringName(type)
	return _ALIASES.get(key, key)

# Pools are keyed by faction id: 0 = player, 1 = enemy (see FactionManager).
func _pool(faction_id: int) -> Dictionary:
	return _enemy if faction_id == 1 else _resources

func get_resource(type, faction_id: int = 0) -> int:
	return _pool(faction_id).get(_normalize(type), 0)

func get_amount(type, faction_id: int = 0) -> int:
	return get_resource(type, faction_id)

func can_afford(costs: Dictionary, faction_id: int = 0) -> bool:
	for type in costs:
		if get_resource(type, faction_id) < int(costs[type]):
			return false
	return true

func add_resource(type, amount: int, faction_id: int = 0) -> void:
	var key: StringName = _normalize(type)
	var pool: Dictionary = _pool(faction_id)
	if not pool.has(key):
		push_warning("ResourceManager: unknown type '%s'" % String(type))
		return
	pool[key] += amount
	resource_changed.emit(key, pool[key])

func add(type, amount: int, faction_id: int = 0) -> void:
	add_resource(type, amount, faction_id)

## SaveManager hook: overwrite both pools and notify the HUD.
func restore(player: Dictionary, enemy: Dictionary) -> void:
	for key in player:
		_resources[_normalize(key)] = int(player[key])
	for key in enemy:
		_enemy[_normalize(key)] = int(enemy[key])
	for type: StringName in _resources:
		resource_changed.emit(type, _resources[type])

## Plain-String copy of both pools, JSON-safe (StringName keys stringified).
func snapshot() -> Dictionary:
	var out: Dictionary = {"player": {}, "enemy": {}}
	for key: StringName in _resources:
		(out["player"] as Dictionary)[String(key)] = _resources[key]
	for key: StringName in _enemy:
		(out["enemy"] as Dictionary)[String(key)] = _enemy[key]
	return out

func spend(costs: Dictionary, faction_id: int = 0) -> bool:
	if not can_afford(costs, faction_id):
		for type in costs:
			if get_resource(type, faction_id) < int(costs[type]):
				resource_insufficient.emit(_normalize(type))
		return false
	var pool: Dictionary = _pool(faction_id)
	for type in costs:
		var key: StringName = _normalize(type)
		pool[key] -= int(costs[type])
		resource_changed.emit(key, pool[key])
	return true
