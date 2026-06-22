extends Node2D

## Procedural dark-fantasy terrain decoration, drawn ONCE over the base grass and
## retained (no per-frame cost — the canvas command buffer is cached; we only
## queue_redraw when the playfield changes). Layers, bottom→top:
##   1. dark fog fill beyond the playfield (kills the black void)
##   2. grass tone variation (soft darker/lighter green patches)
##   3. forest-floor patches under tree groves
##   4. dirt patches under bases + resource clusters
##   5. worn dirt path between the bases
##   6. scattered decals: rocks, flowers, moss, leaf litter
##   7. edge vignette fading the map into darkness
## Everything is deterministic from a per-map seed, so a map always looks the
## same. Sits at z = -9 (above the grass at -10, below objects/units at 0).

const EXT: float = 2600.0          # how far the void fog reaches past the map
const VIGNETTE: float = 420.0      # edge fade width

const FOG_COLOR: Color = Color(0.035, 0.045, 0.060, 1.0)
const VIGNETTE_EDGE: Color = Color(0.02, 0.03, 0.045, 0.92)

var _tex: Texture2D
var _rng := RandomNumberGenerator.new()
var _world: float = MapConfig.WORLD_SIZE
var _scale: float = MapConfig.SCALE

func _ready() -> void:
	z_index = -9
	_tex = TextureGenerator.get_texture("soft_blob")
	_rng.seed = hash(GameSettings.selected_map)
	queue_redraw()

# ── soft primitive ─────────────────────────────────────────
func _blob(c: Vector2, rx: float, ry: float, col: Color) -> void:
	draw_texture_rect(_tex, Rect2(c.x - rx, c.y - ry, rx * 2.0, ry * 2.0), false, col)

func _cfg() -> Dictionary:
	return MapConfig.get_map(GameSettings.selected_map)

## Scaled copy of a config position list (design space → world space).
func _seeds(key: String) -> Array:
	var out: Array = []
	for p in _cfg().get(key, []) as Array:
		out.append((p as Vector2) * _scale)
	return out

func _rand_pt(margin: float) -> Vector2:
	return Vector2(_rng.randf_range(margin, _world - margin), _rng.randf_range(margin, _world - margin))

func _draw() -> void:
	_draw_void_fog()
	_draw_grass_variation()
	_draw_forest_floor()
	_draw_dirt()
	_draw_path()
	_draw_decals()
	_draw_vignette()

# 1 ── dark fog beyond the playable square (no pure-black void) ──
func _draw_void_fog() -> void:
	var w := _world
	draw_rect(Rect2(-EXT, -EXT, w + 2.0 * EXT, EXT), FOG_COLOR)             # top
	draw_rect(Rect2(-EXT, w, w + 2.0 * EXT, EXT), FOG_COLOR)                # bottom
	draw_rect(Rect2(-EXT, 0.0, EXT, w), FOG_COLOR)                          # left
	draw_rect(Rect2(w, 0.0, EXT, w), FOG_COLOR)                             # right

# 2 ── grass tone variation patches ────────────────────────
func _draw_grass_variation() -> void:
	# Near-neutral value shifts (not strongly green) so they read as tonal
	# variation on any biome — grass, sand, azure or volcanic.
	var dark := Color(0.06, 0.09, 0.07, 0.18)
	var light := Color(0.62, 0.62, 0.50, 0.10)
	var n := int(_world * _world / 95000.0)  # density scales with map area
	for i in n:
		var p := _rand_pt(40.0)
		var r := _rng.randf_range(150.0, 360.0)
		_blob(p, r, r * _rng.randf_range(0.6, 0.9), dark if (i % 2 == 0) else light)

# 3 ── darker forest floor under tree groves ───────────────
func _draw_forest_floor() -> void:
	var floor_col := Color(0.07, 0.12, 0.08, 0.5)
	for c in _seeds("trees") + _seeds("extra_trees"):
		_blob(c, 150.0, 130.0, floor_col)
		_blob(c, 95.0, 80.0, Color(0.06, 0.09, 0.06, 0.45))

# 4 ── dirt patches under bases + resource clusters ────────
func _draw_dirt() -> void:
	var dirt := Color(0.30, 0.22, 0.14, 0.55)
	var dirt_soft := Color(0.34, 0.25, 0.16, 0.4)
	var player_tc: Vector2 = (_cfg().get("player_start", Vector2(300, 500)) as Vector2) * _scale
	var enemy_tc: Vector2 = (_cfg().get("enemy_tc", MapConfig.DEFAULT_ENEMY_TC) as Vector2) * _scale
	for base in [player_tc, enemy_tc]:
		_blob(base, 170.0, 130.0, dirt)
		_blob(base, 240.0, 180.0, dirt_soft)
	for c in _seeds("gold_mines") + _seeds("extra_gold_mines"):
		_blob(c, 95.0, 78.0, dirt)
	for c in _seeds("food_nodes"):
		_blob(c, 80.0, 66.0, dirt_soft)

# 5 ── worn dirt path between the two bases ────────────────
func _draw_path() -> void:
	var a: Vector2 = (_cfg().get("player_start", Vector2(300, 500)) as Vector2) * _scale
	var b: Vector2 = (_cfg().get("enemy_tc", MapConfig.DEFAULT_ENEMY_TC) as Vector2) * _scale
	var steps := int(a.distance_to(b) / 70.0)
	var path_col := Color(0.26, 0.20, 0.13, 0.30)
	for i in range(1, steps):
		var t := float(i) / float(steps)
		# gentle sine wander so the trail isn't a ruler-straight line
		var perp := (b - a).orthogonal().normalized()
		var off := perp * sin(t * PI) * 120.0 * sin(t * 9.0 + _rng.randf())
		var p := a.lerp(b, t) + off * 0.15
		_blob(p, 46.0, 30.0, path_col)

# 6 ── scattered decals (rocks / flowers / moss / litter) ──
func _draw_decals() -> void:
	var area := _world * _world
	for i in int(area / 110000.0):
		_rock(_rand_pt(60.0), _rng.randf_range(9.0, 20.0))
	for i in int(area / 150000.0):
		_flower(_rand_pt(60.0))
	for i in int(area / 130000.0):
		_moss(_rand_pt(40.0))
	for c in _seeds("trees") + _seeds("extra_trees"):
		_leaf_litter(c)

func _rock(c: Vector2, s: float) -> void:
	_blob(c + Vector2(0, s * 0.35), s * 1.2, s * 0.5, Color(0, 0, 0, 0.22))  # ground shadow
	var grey := Color(0.30, 0.31, 0.34).lerp(Color(0.20, 0.21, 0.24), _rng.randf())
	var pts := PackedVector2Array([
		c + Vector2(-s, s * 0.2), c + Vector2(-s * 0.6, -s * 0.7),
		c + Vector2(s * 0.45, -s * 0.85), c + Vector2(s, s * 0.1),
		c + Vector2(s * 0.4, s * 0.55), c + Vector2(-s * 0.5, s * 0.55)])
	draw_colored_polygon(pts, grey)
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(-s * 0.6, -s * 0.7), c + Vector2(s * 0.45, -s * 0.85),
		c + Vector2(s * 0.1, -s * 0.2), c + Vector2(-s * 0.3, -s * 0.1)]),
		grey.lightened(0.22))

func _flower(c: Vector2) -> void:
	var palette := [Color(0.92, 0.92, 0.95), Color(0.95, 0.82, 0.30),
		Color(0.70, 0.45, 0.85), Color(0.90, 0.55, 0.70), Color(0.45, 0.60, 0.90)]
	var col: Color = palette[_rng.randi() % palette.size()]
	var n := 2 + _rng.randi() % 3
	for i in n:
		var p := c + Vector2(_rng.randf_range(-7, 7), _rng.randf_range(-6, 6))
		draw_line(p, p + Vector2(0, 5), Color(0.20, 0.34, 0.16), 1.4)
		draw_circle(p, 2.2, col)
		draw_circle(p, 0.9, Color(0.95, 0.85, 0.35))

func _moss(c: Vector2) -> void:
	var col := Color(0.16, 0.30, 0.14, 0.5)
	for i in 3:
		_blob(c + Vector2(_rng.randf_range(-14, 14), _rng.randf_range(-10, 10)),
			_rng.randf_range(10, 20), _rng.randf_range(7, 13), col)

func _leaf_litter(c: Vector2) -> void:
	var cols := [Color(0.45, 0.32, 0.16), Color(0.55, 0.40, 0.18), Color(0.38, 0.42, 0.20)]
	for i in 14:
		var p := c + Vector2(_rng.randf_range(-130, 130), _rng.randf_range(-115, 115))
		draw_circle(p, _rng.randf_range(1.4, 2.8), cols[_rng.randi() % cols.size()])

# 7 ── edge vignette ───────────────────────────────────────
func _draw_vignette() -> void:
	var w := _world
	var v := VIGNETTE
	var e := VIGNETTE_EDGE
	var clear := Color(e.r, e.g, e.b, 0.0)
	# Each edge: a band from the border (opaque) to inward (transparent).
	_grad_quad([Vector2(0, 0), Vector2(w, 0), Vector2(w, v), Vector2(0, v)], [e, e, clear, clear])          # top
	_grad_quad([Vector2(0, w), Vector2(w, w), Vector2(w, w - v), Vector2(0, w - v)], [e, e, clear, clear])  # bottom
	_grad_quad([Vector2(0, 0), Vector2(0, w), Vector2(v, w), Vector2(v, 0)], [e, e, clear, clear])          # left
	_grad_quad([Vector2(w, 0), Vector2(w, w), Vector2(w - v, w), Vector2(w - v, 0)], [e, e, clear, clear])  # right

func _grad_quad(points: Array, colors: Array) -> void:
	draw_polygon(PackedVector2Array(points), PackedColorArray(colors))
