class_name StatComponent
extends Node

signal died(owner_unit: CharacterBody2D)
signal health_changed(current: float, maximum: float)

@export var max_health: float = 100.0
@export var armor: float = 0.0

var _current_health: float = 0.0
var _owner_unit: CharacterBody2D = null

func _ready() -> void:
	_owner_unit = get_parent() as CharacterBody2D
	# Faction stat profile applies before health init so units spawn at the
	# modified maximum (exports are assigned at instantiation, safe to read).
	if _owner_unit != null:
		var fac: FactionData = FactionManager.get_faction(int(_owner_unit.get("faction_id")))
		if fac != null:
			max_health *= fac.hp_mult
			armor += fac.armor_bonus
	_current_health = max_health
	health_changed.emit(_current_health, max_health)

func take_damage(amount: float) -> void:
	if is_dead():
		return
	var dealt: float = max(amount - armor, 1.0)
	_current_health = max(_current_health - dealt, 0.0)
	health_changed.emit(_current_health, max_health)
	if _current_health <= 0.0:
		died.emit(_owner_unit)

func heal(amount: float) -> void:
	if is_dead():
		return
	_current_health = min(_current_health + amount, max_health)
	health_changed.emit(_current_health, max_health)

func is_dead() -> bool:
	return _current_health <= 0.0

func get_health_ratio() -> float:
	if max_health <= 0.0:
		return 0.0
	return _current_health / max_health
