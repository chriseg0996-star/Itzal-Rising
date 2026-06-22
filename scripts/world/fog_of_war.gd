extends Node2D

## Smooth fog of war. Vision is stamped with a soft RADIAL falloff into a
## low-res buffer, then the whole fog is drawn as ONE texture upscaled with
## linear filtering — so transitions are smooth gradients with no visible tile
## boundaries or square chunk reveals (AoE4 / SC2 style). Gameplay still reads
## discrete cell states (visible / explored / unexplored). The AI stays
## omniscient; all hostile-visibility writes live HERE.

const CELL: float = 32.0
const GRID: int = int(MapConfig.WORLD_SIZE / CELL)
const POLL: float = 0.2
const UNIT_RADIUS: float = 300.0
const BUILDING_RADIUS: float = 360.0
## Inner fraction of the radius that is fully clear; the rest is the soft edge.
const CORE: float = 0.6
const COL_FOG: Color = Color(0.035, 0.045, 0.072)
const EXPLORED_DIM: float = 0.34   # veil left over explored-but-unseen ground
const DEBUG_DISABLE: bool = false

const UNEXPLORED: int = 0
const EXPLORED: int = 1
const VISIBLE_STATE: int = 2

var _vis: PackedFloat32Array = PackedFloat32Array()      # current smooth visibility 0..1
var _explored: PackedByteArray = PackedByteArray()       # ever-seen memory
var _fog_tex: ImageTexture = null
var _accum: float = 0.0

func _ready() -> void:
	add_to_group("fog_of_war")
	z_index = 20
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR  # bilinear upscale = smooth
	_vis.resize(GRID * GRID)
	_explored.resize(GRID * GRID)
	_poll()

func _process(delta: float) -> void:
	if DEBUG_DISABLE:
		return
	_accum += delta
	if _accum < POLL:
		return
	_accum = 0.0
	_poll()

func _poll() -> void:
	for i in _vis.size():
		_vis[i] = 0.0
	for u in get_tree().get_nodes_in_group("player_units"):
		if is_instance_valid(u) and u is Node2D:
			_stamp((u as Node2D).global_position, UNIT_RADIUS)
	for b in get_tree().get_nodes_in_group("buildings"):
		if not (is_instance_valid(b) and b is Node2D):
			continue
		var fid: Variant = b.get("faction_id")
		if fid != null and FactionManager.is_player_faction(int(fid)):
			_stamp((b as Node2D).global_position, BUILDING_RADIUS)
	for i in _vis.size():
		if _vis[i] > 0.5:
			_explored[i] = 1
	_apply_visibility()
	_refresh_texture()
	queue_redraw()

## Soft radial vision stamp: fully clear within CORE*radius, smooth falloff to 0.
func _stamp(world_pos: Vector2, radius: float) -> void:
	var min_cx: int = maxi(int((world_pos.x - radius) / CELL), 0)
	var max_cx: int = mini(int((world_pos.x + radius) / CELL), GRID - 1)
	var min_cy: int = maxi(int((world_pos.y - radius) / CELL), 0)
	var max_cy: int = mini(int((world_pos.y + radius) / CELL), GRID - 1)
	var inner: float = radius * CORE
	var span: float = maxf(radius - inner, 1.0)
	for cy in range(min_cy, max_cy + 1):
		for cx in range(min_cx, max_cx + 1):
			var center := Vector2((float(cx) + 0.5) * CELL, (float(cy) + 0.5) * CELL)
			var d: float = world_pos.distance_to(center)
			if d >= radius:
				continue
			var v: float = clampf((radius - d) / span, 0.0, 1.0)
			var idx: int = cy * GRID + cx
			if v > _vis[idx]:
				_vis[idx] = v

func _apply_visibility() -> void:
	for u in get_tree().get_nodes_in_group("combat_units"):
		if not (is_instance_valid(u) and u is Node2D) or u.is_in_group("player_units"):
			continue
		(u as Node2D).visible = get_cell_state((u as Node2D).global_position) == VISIBLE_STATE
	for b in get_tree().get_nodes_in_group("buildings"):
		if not (is_instance_valid(b) and b is Node2D):
			continue
		var fid: Variant = b.get("faction_id")
		if fid == null or FactionManager.is_player_faction(int(fid)):
			continue
		(b as Node2D).visible = get_cell_state((b as Node2D).global_position) != UNEXPLORED
	for r in get_tree().get_nodes_in_group("resources"):
		if is_instance_valid(r) and r is Node2D:
			(r as Node2D).visible = get_cell_state((r as Node2D).global_position) != UNEXPLORED

func _exit_tree() -> void:
	for group in ["combat_units", "buildings", "resources"]:
		for n in get_tree().get_nodes_in_group(group):
			if is_instance_valid(n) and n is Node2D:
				(n as Node2D).visible = true

## Rebuild the fog texture: alpha = darkness. Visible -> clear (with a soft
## radial edge), explored -> faint veil, unexplored -> opaque.
func _refresh_texture() -> void:
	var bytes := PackedByteArray()
	bytes.resize(GRID * GRID * 4)
	var r: int = int(COL_FOG.r * 255.0)
	var g: int = int(COL_FOG.g * 255.0)
	var b: int = int(COL_FOG.b * 255.0)
	for i in GRID * GRID:
		var base: float = EXPLORED_DIM if _explored[i] != 0 else 1.0
		var a: float = base * (1.0 - clampf(_vis[i], 0.0, 1.0))
		var o: int = i * 4
		bytes[o] = r
		bytes[o + 1] = g
		bytes[o + 2] = b
		bytes[o + 3] = int(clampf(a, 0.0, 1.0) * 255.0)
	var img := Image.create_from_data(GRID, GRID, false, Image.FORMAT_RGBA8, bytes)
	if _fog_tex == null:
		_fog_tex = ImageTexture.create_from_image(img)
	else:
		_fog_tex.update(img)

func _draw() -> void:
	if DEBUG_DISABLE or _fog_tex == null:
		return
	# One upscaled, linearly-filtered quad — smooth, no tile edges. Inset by half
	# a cell so texel centres align to the world (avoids an edge seam).
	var half := CELL * 0.5
	draw_texture_rect(_fog_tex, Rect2(-half, -half, MapConfig.WORLD_SIZE + CELL, MapConfig.WORLD_SIZE + CELL), false)

func get_cell_state(world_pos: Vector2) -> int:
	if DEBUG_DISABLE:
		return VISIBLE_STATE
	var cx: int = clampi(int(world_pos.x / CELL), 0, GRID - 1)
	var cy: int = clampi(int(world_pos.y / CELL), 0, GRID - 1)
	var idx: int = cy * GRID + cx
	if _vis[idx] > 0.5:
		return VISIBLE_STATE
	if _explored[idx] != 0:
		return EXPLORED
	return UNEXPLORED

## SaveManager hooks: persist the explored-memory grid.
func get_explored() -> PackedByteArray:
	return _explored.duplicate()

func set_explored(bytes: PackedByteArray) -> void:
	if bytes.size() != GRID * GRID:
		return
	_explored = bytes.duplicate()
	_poll()
