extends Node

## Evens out the Decay player's start (mirrors the IxSpawner pattern). The
## baked World gives the SE base 2 villagers + 3 free soldiers while AI-Itzal
## opens with 3 villagers + 0 soldiers. When the human plays Decay
## (GameSettings.player_faction_id == 1): free the baked soldiers and add a
## third villager, so both sides open 3 workers / 0 soldiers.
## Runs once, deferred, after MapLoader has repositioned the bases.

@export var enemy_villager_scene: PackedScene
@export var enemy_node_names: Array[String] = ["Enemy1", "Enemy2", "Enemy3"]

func _ready() -> void:
	call_deferred("_apply_faction")

func _apply_faction() -> void:
	if GameSettings.player_faction_id != FactionManager.ENEMY:
		return
	var world: Node = get_parent()
	if world == null:
		return
	for ename in enemy_node_names:
		var e: Node = world.get_node_or_null(NodePath(ename))
		if e != null:
			e.queue_free()
	var tc_pos: Vector2 = _find_decay_tc_pos()
	if enemy_villager_scene == null:
		return
	var unit: Node = enemy_villager_scene.instantiate()
	world.add_child(unit)
	if unit is Node2D:
		(unit as Node2D).global_position = tc_pos + Vector2(60.0, 100.0)

func _find_decay_tc_pos() -> Vector2:
	for tc in get_tree().get_nodes_in_group("town_center"):
		if is_instance_valid(tc) and tc is Node2D and tc.get("faction_id") == FactionManager.ENEMY:
			return (tc as Node2D).global_position
	return Vector2(1600, 1600)
