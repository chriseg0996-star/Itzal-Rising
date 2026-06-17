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
	# Era bonus applies to both sides; armour research is player-only.
	var eff_armor: float = armor
	var is_player: bool = _owner_unit != null and FactionManager.is_player_faction(int(_owner_unit.get("faction_id")))
	eff_armor += GameStats.era_armor_bonus(is_player)
	if is_player:
		eff_armor += GameStats.player_armor_bonus()
	var dealt: float = max(amount - eff_armor, 1.0)
	_current_health = max(_current_health - dealt, 0.0)
	health_changed.emit(_current_health, max_health)
	if _current_health <= 0.0:
		# Tally exactly at the death edge (is_dead() guards re-entry). Never in
		# die()/_exit_tree — SaveManager.load frees units directly and must not
		# inflate the counts.
		if _owner_unit != null:
			if FactionManager.is_player_faction(int(_owner_unit.get("faction_id"))):
				GameStats.units_lost += 1
			else:
				GameStats.enemies_killed += 1
		died.emit(_owner_unit)

## SaveManager hook: set absolute health after _ready ran (load path).
func restore_health(value: float) -> void:
	_current_health = clampf(value, 0.0, max_health)
	health_changed.emit(_current_health, max_health)

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
