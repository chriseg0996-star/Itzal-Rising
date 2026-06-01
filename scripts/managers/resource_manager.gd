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

func _pool(faction: String) -> Dictionary:
	return _enemy if faction == "enemy" else _resources

func get_resource(type, faction: String = "player") -> int:
	return _pool(faction).get(_normalize(type), 0)

func get_amount(type, faction: String = "player") -> int:
	return get_resource(type, faction)

func can_afford(costs: Dictionary, faction: String = "player") -> bool:
	for type in costs:
		if get_resource(type, faction) < int(costs[type]):
			return false
	return true

func add_resource(type, amount: int, faction: String = "player") -> void:
	var key: StringName = _normalize(type)
	var pool: Dictionary = _pool(faction)
	if not pool.has(key):
		push_warning("ResourceManager: unknown type '%s'" % String(type))
		return
	pool[key] += amount
	resource_changed.emit(key, pool[key])

func add(type, amount: int, faction: String = "player") -> void:
	add_resource(type, amount, faction)

func spend(costs: Dictionary, faction: String = "player") -> bool:
	if not can_afford(costs, faction):
		for type in costs:
			if get_resource(type, faction) < int(costs[type]):
				resource_insufficient.emit(_normalize(type))
		return false
	var pool: Dictionary = _pool(faction)
	for type in costs:
		var key: StringName = _normalize(type)
		pool[key] -= int(costs[type])
		resource_changed.emit(key, pool[key])
	return true
