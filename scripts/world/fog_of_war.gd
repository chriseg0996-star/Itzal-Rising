extends Node2D

## Player-presentation fog of war over the 2048x2048 world: a 32x32 grid of
## 64px cells drawn in a single _draw pass (one canvas item — no node spam).
## Cell states: 0 unexplored (opaque), 1 explored-but-unseen (dim), 2 visible.
## The player's units and buildings reveal; the AI stays omniscient (it reads
## groups directly). All hostile-visibility writes live HERE and nowhere else.
## Known v1 limitation: player units can still auto-acquire fogged targets.

const CELL: float = 64.0
const GRID: int = int(MapConfig.WORLD_SIZE / CELL)
const POLL: float = 0.25
const UNIT_RADIUS: float = 280.0
const BUILDING_RADIUS: float = 320.0
const COL_UNEXPLORED: Color = Color(0.04, 0.05, 0.08, 1.0)
## Faint veil left over explored-but-unseen ground (classic RTS dim memory).
const COL_EXPLORED_DIM: Color = Color(0.04, 0.05, 0.08, 0.32)
## Feathered alpha for unexplored cells by Chebyshev distance to seen ground
## (index 0 = touching seen) — turns the hard black border into a soft gradient.
const EDGE_ALPHA: Array = [0.38, 0.62, 0.82, 0.94]
## Flip to true to neutralize fog entirely (debug).
const DEBUG_DISABLE: bool = false

const UNEXPLORED: int = 0
const EXPLORED: int = 1
const VISIBLE_STATE: int = 2

var _cells: PackedByteArray = PackedByteArray()
var _accum: float = 0.0

func _ready() -> void:
	add_to_group("fog_of_war")
	z_index = 20  # above ground and unit sprites, below rally markers (50)
	_cells.resize(GRID * GRID)
	_cells.fill(UNEXPLORED)
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
	# Visible decays to explored each poll; revealers re-stamp.
	for i in _cells.size():
		if _cells[i] == VISIBLE_STATE:
			_cells[i] = EXPLORED
	for u in get_tree().get_nodes_in_group("player_units"):
		if is_instance_valid(u) and u is Node2D:
			_stamp((u as Node2D).global_position, UNIT_RADIUS)
	for b in get_tree().get_nodes_in_group("buildings"):
		if not (is_instance_valid(b) and b is Node2D):
			continue
		var fid: Variant = b.get("faction_id")
		if fid != null and FactionManager.is_player_faction(int(fid)):
			_stamp((b as Node2D).global_position, BUILDING_RADIUS)
	_apply_visibility()
	queue_redraw()

## Centralized hostile-visibility writes: enemy units show only in visible
## cells; enemy buildings and resources show once their cell is explored.
## (Death fades use modulate.a — an independent channel — so no conflicts.)
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
	# Defensive: never leave entities hidden if the fog node goes away.
	for group in ["combat_units", "buildings", "resources"]:
		for n in get_tree().get_nodes_in_group(group):
			if is_instance_valid(n) and n is Node2D:
				(n as Node2D).visible = true

func _stamp(world_pos: Vector2, radius: float) -> void:
	var min_cx: int = maxi(int((world_pos.x - radius) / CELL), 0)
	var max_cx: int = mini(int((world_pos.x + radius) / CELL), GRID - 1)
	var min_cy: int = maxi(int((world_pos.y - radius) / CELL), 0)
	var max_cy: int = mini(int((world_pos.y + radius) / CELL), GRID - 1)
	var r2: float = radius * radius
	for cy in range(min_cy, max_cy + 1):
		for cx in range(min_cx, max_cx + 1):
			var center := Vector2((float(cx) + 0.5) * CELL, (float(cy) + 0.5) * CELL)
			if world_pos.distance_squared_to(center) <= r2:
				_cells[cy * GRID + cx] = VISIBLE_STATE

func _draw() -> void:
	if DEBUG_DISABLE:
		return
	# Explored-but-unseen keeps a faint veil; unexplored darkens, but feathered
	# near seen ground so the border reads as a soft fog gradient, not a hard
	# black edge.
	for cy in GRID:
		for cx in GRID:
			var st: int = _cells[cy * GRID + cx]
			if st == VISIBLE_STATE:
				continue
			var rect := Rect2(float(cx) * CELL, float(cy) * CELL, CELL, CELL)
			if st == EXPLORED:
				draw_rect(rect, COL_EXPLORED_DIM)
				continue
			var a: float = _edge_alpha(cx, cy)
			draw_rect(rect, Color(COL_UNEXPLORED.r, COL_UNEXPLORED.g, COL_UNEXPLORED.b, a))

## Soft-edge alpha: the nearest seen cell within a few rings fades this cell.
func _edge_alpha(cx: int, cy: int) -> float:
	for ring in range(1, EDGE_ALPHA.size() + 1):
		for dy in range(-ring, ring + 1):
			for dx in range(-ring, ring + 1):
				if maxi(absi(dx), absi(dy)) != ring:
					continue
				var nx: int = cx + dx
				var ny: int = cy + dy
				if nx < 0 or ny < 0 or nx >= GRID or ny >= GRID:
					continue
				if _cells[ny * GRID + nx] != UNEXPLORED:
					return EDGE_ALPHA[ring - 1]
	return 1.0

func get_cell_state(world_pos: Vector2) -> int:
	if DEBUG_DISABLE:
		return VISIBLE_STATE
	var cx: int = clampi(int(world_pos.x / CELL), 0, GRID - 1)
	var cy: int = clampi(int(world_pos.y / CELL), 0, GRID - 1)
	return _cells[cy * GRID + cx]

## SaveManager hooks: explored grid with visibility normalized away.
func get_explored() -> PackedByteArray:
	var out: PackedByteArray = _cells.duplicate()
	for i in out.size():
		if out[i] == VISIBLE_STATE:
			out[i] = EXPLORED
	return out

func set_explored(bytes: PackedByteArray) -> void:
	if bytes.size() != GRID * GRID:
		return
	_cells = bytes.duplicate()
	_poll()
