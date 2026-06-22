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
var _patch_tex: Texture2D
var _rng := RandomNumberGenerator.new()
var _world: float = MapConfig.WORLD_SIZE
var _scale: float = MapConfig.SCALE

func _ready() -> void:
	z_index = -9
	_tex = TextureGenerator.get_texture("soft_blob")
	_patch_tex = TextureGenerator.get_texture("soft_patch")
	_rng.seed = hash(GameSettings.selected_map)
	queue_redraw()

# ── soft primitives ────────────────────────────────────────
func _blob(c: Vector2, rx: float, ry: float, col: Color) -> void:
	draw_texture_rect(_tex, Rect2(c.x - rx, c.y - ry, rx * 2.0, ry * 2.0), false, col)

## Flatter, solid-core patch — for terrain tone/dirt that must read clearly.
func _patch(c: Vector2, rx: float, ry: float, col: Color) -> void:
	draw_texture_rect(_patch_tex, Rect2(c.x - rx, c.y - ry, rx * 2.0, ry * 2.0), false, col)

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

# 2 ── grass tone variation + scattered dirt patches ───────
func _draw_grass_variation() -> void:
	var n := int(_world * _world / 52000.0)  # density scales with map area
	for i in n:
		var p := _rand_pt(40.0)
		var r := _rng.randf_range(110.0, 300.0)
		var roll := _rng.randf()
		var col: Color
		if roll < 0.42:
			col = Color(0.10, 0.18, 0.09, 0.30)    # darker grass
			_patch(p, r, r * _rng.randf_range(0.6, 0.85), col)
		elif roll < 0.78:
			col = Color(0.54, 0.55, 0.35, 0.22)    # warm lighter grass
			_patch(p, r, r * _rng.randf_range(0.6, 0.85), col)
		else:
			r *= 0.55
			# layered for a solid bare-dirt centre with a soft rim
			_patch(p, r, r * 0.78, Color(0.37, 0.28, 0.17, 0.5))
			_patch(p, r * 0.6, r * 0.46, Color(0.32, 0.24, 0.14, 0.55))

# 3 ── darker forest floor under tree groves ───────────────
func _draw_forest_floor() -> void:
	for c in _seeds("trees") + _seeds("extra_trees"):
		_patch(c, 120.0, 100.0, Color(0.08, 0.13, 0.08, 0.5))
		_patch(c, 70.0, 58.0, Color(0.06, 0.09, 0.06, 0.5))

# 4 ── dirt patches under bases + resource clusters ────────
func _draw_dirt() -> void:
	var dirt := Color(0.30, 0.22, 0.14, 0.55)
	var dirt_soft := Color(0.34, 0.25, 0.16, 0.4)
	var player_tc: Vector2 = (_cfg().get("player_start", Vector2(300, 500)) as Vector2) * _scale
	var enemy_tc: Vector2 = (_cfg().get("enemy_tc", MapConfig.DEFAULT_ENEMY_TC) as Vector2) * _scale
	for base in [player_tc, enemy_tc]:
		_patch(base, 170.0, 130.0, dirt)
		_patch(base, 240.0, 180.0, dirt_soft)
	for c in _seeds("gold_mines") + _seeds("extra_gold_mines"):
		_patch(c, 95.0, 78.0, dirt)
	for c in _seeds("food_nodes"):
		_patch(c, 80.0, 66.0, dirt_soft)

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
		_patch(p, 46.0, 30.0, path_col)

# 6 ── scattered decals (rocks / grass tufts / flowers / moss) ──
func _draw_decals() -> void:
	var area := _world * _world
	for i in int(area / 170000.0):
		_rock(_rand_pt(60.0), _rng.randf_range(11.0, 24.0))
	for i in int(area / 80000.0):
		_grass_tuft(_rand_pt(40.0))
	for i in int(area / 140000.0):
		_flower(_rand_pt(60.0))
	for i in int(area / 200000.0):
		_moss(_rand_pt(40.0))
	for c in _seeds("trees") + _seeds("extra_trees"):
		_leaf_litter(c)

## A light-grey boulder (rounded, soft contact shadow) that reads as a rock, not
## a dark blob.
func _rock(c: Vector2, s: float) -> void:
	_blob(c + Vector2(0, s * 0.42), s * 1.25, s * 0.42, Color(0, 0, 0, 0.16))  # soft contact shadow
	var base := Color(0.46, 0.47, 0.50).lerp(Color(0.34, 0.35, 0.39), _rng.randf())
	var pts := PackedVector2Array()
	for k in 9:
		var ang := float(k) / 9.0 * TAU
		var rad := s * (0.78 + 0.22 * _rng.randf())
		pts.append(c + Vector2(cos(ang) * rad, sin(ang) * rad * 0.72 - s * 0.12))
	draw_colored_polygon(pts, base)
	# top-left light face
	draw_circle(c + Vector2(-s * 0.22, -s * 0.34), s * 0.42, base.lightened(0.22))

## A small clump of grass blades.
func _grass_tuft(c: Vector2) -> void:
	var g := Color(0.24, 0.42, 0.18).lerp(Color(0.42, 0.54, 0.26), _rng.randf())
	for k in 5:
		var x := c.x + _rng.randf_range(-7.0, 7.0)
		var h := _rng.randf_range(7.0, 13.0)
		draw_line(Vector2(x, c.y), Vector2(x + _rng.randf_range(-3.0, 3.0), c.y - h), g, 1.6)

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
