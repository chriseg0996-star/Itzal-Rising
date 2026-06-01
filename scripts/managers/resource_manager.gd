extends Node

signal resources_changed

const INITIAL_WOOD: int = 300
const INITIAL_FOOD: int = 300
const INITIAL_GOLD: int = 150

var wood: int = INITIAL_WOOD
var food: int = INITIAL_FOOD
var gold: int = INITIAL_GOLD

var enemy_wood: int = INITIAL_WOOD
var enemy_food: int = INITIAL_FOOD
var enemy_gold: int = INITIAL_GOLD

func reset() -> void:
	wood = INITIAL_WOOD
	food = INITIAL_FOOD
	gold = INITIAL_GOLD
	enemy_wood = INITIAL_WOOD
	enemy_food = INITIAL_FOOD
	enemy_gold = INITIAL_GOLD
	resources_changed.emit()

func get_amount(type: String, faction: String = "player") -> int:
	if faction == "enemy":
		match type:
			"madera": return enemy_wood
			"comida": return enemy_food
			"oro": return enemy_gold
		return 0
	match type:
		"madera": return wood
		"comida": return food
		"oro": return gold
	return 0

func add(type: String, amount: int, faction: String = "player") -> void:
	if amount <= 0:
		return
	var changed: bool = true
	if faction == "enemy":
		match type:
			"madera": enemy_wood += amount
			"comida": enemy_food += amount
			"oro": enemy_gold += amount
			_: changed = false
	else:
		match type:
			"madera": wood += amount
			"comida": food += amount
			"oro": gold += amount
			_: changed = false
	if changed:
		resources_changed.emit()

func spend(type: String, amount: int, faction: String = "player") -> bool:
	if amount <= 0:
		return true
	if faction == "enemy":
		match type:
			"madera":
				if enemy_wood < amount: return false
				enemy_wood -= amount
			"comida":
				if enemy_food < amount: return false
				enemy_food -= amount
			"oro":
				if enemy_gold < amount: return false
				enemy_gold -= amount
			_:
				return false
	else:
		match type:
			"madera":
				if wood < amount: return false
				wood -= amount
			"comida":
				if food < amount: return false
				food -= amount
			"oro":
				if gold < amount: return false
				gold -= amount
			_:
				return false
	resources_changed.emit()
	return true
