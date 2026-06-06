extends Node

## Swaps the World's default starting villagers for Ix units when the human player
## has chosen the Ix Architects faction (GameSettings.player_faction_id == 2).
## Runs once, deferred, so the default Villager nodes exist before replacement.
## Scenes are injected via exports (no hardcoded scene paths).

@export var weaver_scene: PackedScene
@export var guard_scene: PackedScene
@export var villager_node_names: Array[String] = ["Villager1", "Villager2", "Villager3"]

func _ready() -> void:
	call_deferred("_apply_faction")

func _apply_faction() -> void:
	if GameSettings.player_faction_id != FactionManager.IX:
		return
	var world: Node = get_parent()
	if world == null:
		return
	var positions: Array[Vector2] = []
	for vname in villager_node_names:
		var v: Node = world.get_node_or_null(NodePath(vname))
		if v != null and v is Node2D:
			positions.append((v as Node2D).global_position)
			v.queue_free()
	for p in positions:
		_spawn(weaver_scene, world, p)
	# One guard near the player's town center for early defense.
	var tc: Node = world.get_node_or_null("PlayerTC")
	if tc != null and tc is Node2D:
		_spawn(guard_scene, world, (tc as Node2D).global_position + Vector2(80.0, 80.0))

func _spawn(scene: PackedScene, parent: Node, pos: Vector2) -> void:
	if scene == null:
		return
	var unit: Node = scene.instantiate()
	parent.add_child(unit)
	if unit is Node2D:
		(unit as Node2D).global_position = pos
