extends Node

## Applies the selected map config (MapConfig.MAPS) to the baked World layout:
## repositions the named nodes, moves the enemy base as a whole, tints the
## ground, spawns extra resource nodes and places the camera on the player
## start. "Jungle Basin" equals the baked literals, so the default map is a
## behavioral no-op. Runs in plain _ready: the whole baked tree already exists,
## ix_spawner applies deferred (after) and EnemyAI bootstraps two frames later.

const TREE_SCENE: PackedScene = preload("res://scenes/world/ResourceNode.tscn")
const GOLD_SCENE: PackedScene = preload("res://scenes/world/GoldMine.tscn")

func _ready() -> void:
	# Matches are SFX-only; silence any menu track as the world loads.
	SoundManager.stop_music()
	var cfg: Dictionary = MapConfig.get_map(GameSettings.selected_map)
	var world: Node = get_parent()
	if world == null:
		return
	var player_start: Vector2 = cfg.get("player_start", Vector2(300, 500)) as Vector2
	_move(world, "PlayerTC", player_start)
	_apply_list(world, "Villager", cfg.get("villagers", []) as Array)
	_apply_list(world, "Tree", cfg.get("trees", []) as Array)
	_apply_list(world, "GoldMine", cfg.get("gold_mines", []) as Array)
	_apply_list(world, "Enemy", cfg.get("enemy_soldiers", []) as Array)
	var enemy_base: Node = world.get_node_or_null("EnemyBase")
	if enemy_base != null and enemy_base is Node2D:
		var enemy_tc: Vector2 = cfg.get("enemy_tc", MapConfig.DEFAULT_ENEMY_TC) as Vector2
		(enemy_base as Node2D).position = enemy_tc - MapConfig.DEFAULT_ENEMY_TC
	var ground: Node = world.get_node_or_null("Ground")
	if ground != null and ground is CanvasItem:
		(ground as CanvasItem).modulate = cfg.get("ground_tint", Color.WHITE) as Color
	for p in cfg.get("extra_trees", []) as Array:
		_spawn(TREE_SCENE, world, p as Vector2)
	for p in cfg.get("extra_gold_mines", []) as Array:
		_spawn(GOLD_SCENE, world, p as Vector2)
	var cam: Node = world.get_node_or_null("RTSCamera")
	if cam != null and cam is Node2D:
		# A Decay player starts at the enemy base — open the camera there.
		if GameSettings.player_faction_id == FactionManager.ENEMY:
			(cam as Node2D).position = cfg.get("enemy_tc", MapConfig.DEFAULT_ENEMY_TC) as Vector2
		else:
			(cam as Node2D).position = player_start

func _move(world: Node, node_name: String, pos: Vector2) -> void:
	var n: Node = world.get_node_or_null(NodePath(node_name))
	if n != null and n is Node2D:
		(n as Node2D).position = pos

## Repositions baked numbered nodes (Name1..NameN); frees the surplus when the
## map config uses fewer than the baked count.
func _apply_list(world: Node, base_name: String, positions: Array) -> void:
	var index: int = 0
	while true:
		var n: Node = world.get_node_or_null(NodePath("%s%d" % [base_name, index + 1]))
		if n == null:
			break
		if index < positions.size() and n is Node2D:
			(n as Node2D).position = positions[index] as Vector2
		elif index >= positions.size():
			n.queue_free()
		index += 1

func _spawn(scene: PackedScene, parent: Node, pos: Vector2) -> void:
	if scene == null:
		return
	var node: Node = scene.instantiate()
	parent.add_child(node)
	if node is Node2D:
		(node as Node2D).global_position = pos
