extends Node

## Applies the selected map config (MapConfig.MAPS) to the baked World layout:
## repositions the named nodes, moves the enemy base as a whole, tints the
## ground, spawns extra resource nodes and places the camera on the player
## start. "Jungle Basin" equals the baked literals, so the default map is a
## behavioral no-op. Runs in plain _ready: the whole baked tree already exists,
## ix_spawner applies deferred (after) and EnemyAI bootstraps two frames later.

const TREE_SCENE: PackedScene = preload("res://scenes/world/ResourceNode.tscn")
const GOLD_SCENE: PackedScene = preload("res://scenes/world/GoldMine.tscn")
const FOOD_SCENE: PackedScene = preload("res://scenes/world/BerryBush.tscn")

func _ready() -> void:
	# Swap menu music for the match playlist (silent if the match folder is empty).
	SoundManager.start_match_music()
	var cfg: Dictionary = _scaled(MapConfig.get_map(GameSettings.selected_map))
	var world: Node = get_parent()
	if world == null:
		return
	var player_start: Vector2 = cfg.get("player_start", Vector2(300, 500)) as Vector2
	_move(world, "PlayerTC", player_start)
	_apply_list(world, "Villager", cfg.get("villagers", []) as Array)
	_apply_list(world, "Enemy", cfg.get("enemy_soldiers", []) as Array)
	var enemy_base: Node = world.get_node_or_null("EnemyBase")
	if enemy_base != null and enemy_base is Node2D:
		var enemy_tc: Vector2 = cfg.get("enemy_tc", MapConfig.DEFAULT_ENEMY_TC) as Vector2
		(enemy_base as Node2D).position = enemy_tc - MapConfig.DEFAULT_ENEMY_TC
	var ground: Node = world.get_node_or_null("Ground")
	if ground != null and ground is CanvasItem:
		(ground as CanvasItem).modulate = cfg.get("ground_tint", Color.WHITE) as Color
	if ground != null and ground is Sprite2D:
		var tex_path: String = String(cfg.get("ground_texture", MapConfig.DEFAULT_GROUND_TEXTURE))
		if ResourceLoader.exists(tex_path):
			(ground as Sprite2D).texture = load(tex_path)
	# Structured procedural layout (MapGen) replaces the authored resource lists
	# with strategic geography — same seed as ground_decor, so terrain matches.
	_clear_baked(world, "Tree")
	_clear_baked(world, "GoldMine")
	var enemy_tc_pos: Vector2 = cfg.get("enemy_tc", MapConfig.DEFAULT_ENEMY_TC) as Vector2
	var layout: Dictionary = MapGen.generate(player_start, enemy_tc_pos, MapConfig.WORLD_SIZE, int(hash(GameSettings.selected_map)))
	for fp in layout["forests"]:
		_spawn(TREE_SCENE, world, fp as Vector2)
	for bp in layout["berries"]:
		_spawn(FOOD_SCENE, world, bp as Vector2)
	for gp in layout["golds"]:
		_spawn(GOLD_SCENE, world, gp as Vector2)
	_bake_nav(world, layout.get("blockers", []) as Array)
	var cam: Node = world.get_node_or_null("RTSCamera")
	if cam != null and cam is Node2D:
		# A Decay player starts at the enemy base — open the camera there.
		if GameSettings.player_faction_id == FactionManager.ENEMY:
			(cam as Node2D).position = cfg.get("enemy_tc", MapConfig.DEFAULT_ENEMY_TC) as Vector2
		else:
			(cam as Node2D).position = player_start
	_apply_mission_modifier(world, player_start)
	# Run after the deferred spawns have positioned every node.
	_dedup_painted.call_deferred(world)

## Avoid identical painted variants sitting next to each other. Forests and berry
## bushes are de-duped within their own group (their variant indices are
## independent). Runs deferred, once positions are set.
func _dedup_painted(world: Node) -> void:
	_dedup_group(world, "forests", 300.0)
	_dedup_group(world, "berries", 120.0)
	_dedup_group(world, "mines", 320.0)

func _dedup_group(world: Node, group: String, radius: float) -> void:
	var nodes: Array = world.get_tree().get_nodes_in_group(group)
	for f in nodes:
		if not (is_instance_valid(f) and f is Node2D):
			continue
		var used: Dictionary = {}
		var clash: bool = false
		for o in nodes:
			if o == f or not (is_instance_valid(o) and o is Node2D):
				continue
			if (o as Node2D).global_position.distance_to((f as Node2D).global_position) < radius:
				used[int(o.get("variant"))] = true
				if int(o.get("variant")) == int(f.get("variant")):
					clash = true
		if not clash:
			continue
		var free: Array = []
		for i in 4:
			if not used.has(i):
				free.append(i)
		if not free.is_empty() and f.has_method("set_painted_variant"):
			f.set_painted_variant(free[(int(f.get("variant")) + 1) % free.size()])

## Campaign handicaps that need the live world. fast_aggro is handled in
## EnemyAI.reset(); the rest are applied here.
func _apply_mission_modifier(world: Node, player_start: Vector2) -> void:
	if not ActiveMission.is_active():
		return
	match String(ActiveMission.get_data().get("modifier", "")):
		"enemy_eco_boost":
			# Campaign AI is always Decay (faction 1) — top up its pool.
			ResourceManager.add_resource("madera", 300, FactionManager.ENEMY)
			ResourceManager.add_resource("oro", 200, FactionManager.ENEMY)
		"player_handicap":
			# Offset a harder scenario with one extra starting worker.
			var scene_path: String = "res://scenes/units/Villager.tscn"
			if GameSettings.player_faction_id == FactionManager.IX:
				scene_path = "res://scenes/units/IxWeaver.tscn"
			var packed: PackedScene = load(scene_path)
			if packed != null:
				var v: Node = packed.instantiate()
				if v is Node2D:
					(v as Node2D).call_deferred("set_global_position", player_start + Vector2(0, 90))
				world.add_child.call_deferred(v)

## Scale every position (and position list) in a map config from DESIGN_SIZE to
## WORLD_SIZE space. Non-position values (tints, texture paths) pass through.
## DEFAULT_ENEMY_TC stays unscaled — it is the EnemyBase's baked local offset, so
## `scaled_enemy_tc - DEFAULT` lands the TC at the scaled position.
func _scaled(raw: Dictionary) -> Dictionary:
	if is_equal_approx(MapConfig.SCALE, 1.0):
		return raw
	var out: Dictionary = {}
	for k in raw:
		var v: Variant = raw[k]
		if v is Vector2:
			out[k] = (v as Vector2) * MapConfig.SCALE
		elif v is Array:
			var a: Array = []
			for p in v:
				a.append((p as Vector2) * MapConfig.SCALE if p is Vector2 else p)
			out[k] = a
		else:
			out[k] = v
	return out

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
	parent.add_child.call_deferred(node)
	if node is Node2D:
		(node as Node2D).call_deferred("set_global_position", pos)

## Re-bakes the navigation polygon with forest formations carved out, so forests
## block movement and the wall gaps become real chokepoints. Falls back silently
## if anything is off (units keep the open baked mesh).
func _bake_nav(world: Node, blockers: Array) -> void:
	var region := world.get_node_or_null("NavigationRegion2D") as NavigationRegion2D
	if region == null or blockers.is_empty():
		return
	var w: float = MapConfig.WORLD_SIZE
	var bounds := PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, w), Vector2(0, w)])
	var src := NavigationMeshSourceGeometryData2D.new()
	src.add_traversable_outline(bounds)
	for b in blockers:
		src.add_obstruction_outline(b as PackedVector2Array)
	var np := NavigationPolygon.new()
	np.agent_radius = 18.0
	np.add_outline(bounds)
	NavigationServer2D.bake_from_source_geometry_data(np, src)
	region.navigation_polygon = np

## Frees the baked numbered resource nodes (Name1..NameN) — the procedural
## MapGen layout supplies all resources now.
func _clear_baked(world: Node, base_name: String) -> void:
	var i: int = 1
	while true:
		var n: Node = world.get_node_or_null(NodePath("%s%d" % [base_name, i]))
		if n == null:
			break
		n.queue_free()
		i += 1
