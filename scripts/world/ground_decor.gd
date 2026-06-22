extends Node2D

## Terrain presentation, driven by the SAME structured layout as the resources
## (MapGen, same seed) so the ground tells the map's story: excavated dirt under
## gold/bases, leaf litter under forests, fertile soil under berries, rocky
## patches, fertile clearings, and irregular dirt roads connecting key areas.
## The ground itself is a texture-splat shader (assets/shaders/terrain.gdshader);
## this node builds its control splat and draws a sparse VARIED detail scatter
## (grass tufts, stones, roots, branches, mining debris) plus the off-map void.

const EXT: float = 2600.0
const FOG_COLOR: Color = Color(0.035, 0.045, 0.060, 1.0)
const SHADER: String = "res://assets/shaders/terrain.gdshader"
const CONTROL_SIZE: int = 256

var _rng := RandomNumberGenerator.new()
var _world: float = MapConfig.WORLD_SIZE
var _scale: float = MapConfig.SCALE
var _layout: Dictionary = {}

func _ready() -> void:
	z_index = -9
	_rng.seed = hash(GameSettings.selected_map)
	var cfg: Dictionary = MapConfig.get_map(GameSettings.selected_map)
	var p: Vector2 = (cfg.get("player_start", Vector2(300, 500)) as Vector2) * _scale
	var e: Vector2 = (cfg.get("enemy_tc", MapConfig.DEFAULT_ENEMY_TC) as Vector2) * _scale
	_layout = MapGen.generate(p, e, _world, int(hash(GameSettings.selected_map)))
	_layout["bases"] = [p, e]
	_setup_ground_shader()
	queue_redraw()

# ── ground shader + control splat ──────────────────────────
func _setup_ground_shader() -> void:
	var ground := get_parent().get_node_or_null("Ground") as CanvasItem
	if ground == null or not ResourceLoader.exists(SHADER):
		return
	var cfg: Dictionary = MapConfig.get_map(GameSettings.selected_map)
	var base_path: String = String(cfg.get("ground_texture", MapConfig.DEFAULT_GROUND_TEXTURE))
	var base: Texture2D = load(base_path) if ResourceLoader.exists(base_path) else null
	var is_grass: bool = base_path.ends_with("grass.png")
	var mat := ShaderMaterial.new()
	mat.shader = load(SHADER)
	mat.set_shader_parameter("grass", base)
	mat.set_shader_parameter("drygrass", load("res://assets/terrain/grass_dry.png") if is_grass else base)
	mat.set_shader_parameter("dirt", load("res://assets/terrain/dirt.png"))
	mat.set_shader_parameter("noise_tex", load("res://assets/terrain/noise.png"))
	mat.set_shader_parameter("control", _build_control())
	mat.set_shader_parameter("world_size", _world)
	mat.set_shader_parameter("tile_px", 512.0)
	ground.material = mat
	ground.set_deferred("modulate", Color.WHITE)

## RGBA control splat. r = compacted earth (roads/bases), g = dark forest soil,
## b = fertile soil (berries), a = rocky ground (mines/rocky). Crisp discs from
## the structured layout. NOTE alpha starts at 0 — it is the rocky channel now.
func _build_control() -> ImageTexture:
	var img := Image.create(CONTROL_SIZE, CONTROL_SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var k: float = float(CONTROL_SIZE) / _world
	for c in _arr("golds"):
		_stamp(img, c * k, 15.0, 3)   # rocky ground around mines
	for c in _arr("rocky"):
		_stamp(img, c * k, 22.0, 3)
	for c in _arr("forests"):
		_stamp(img, c * k, 10.0, 1)   # dark forest soil
	for c in _arr("berries"):
		_stamp(img, c * k, 9.0, 2)
	for c in _arr("fertile"):
		_stamp(img, c * k, 24.0, 2)
	for b in _arr("bases"):
		_stamp(img, b * k, 17.0, 0)   # compacted earth
	for road in _layout.get("roads", []):
		_stamp_road(img, road, k)     # roads -> channel 0 (see _stamp_road)
	return ImageTexture.create_from_image(img)

## A dirt road: discs along the polyline with varying width, small jitter and
## occasional gaps so grass intrudes — never a perfectly smooth band.
func _stamp_road(img: Image, pts: Array, k: float) -> void:
	for s in range(pts.size() - 1):
		var a: Vector2 = (pts[s] as Vector2) * k
		var b: Vector2 = (pts[s + 1] as Vector2) * k
		var steps: int = maxi(1, int(a.distance_to(b) / 2.5))
		for i in range(steps + 1):
			if _rng.randf() < 0.12:
				continue  # grass intrusion
			var t: float = float(i) / float(steps)
			var pos: Vector2 = a.lerp(b, t) + Vector2(_rng.randf_range(-1.6, 1.6), _rng.randf_range(-1.6, 1.6))
			var w: float = 3.2 + 1.5 * sin(t * 9.0 + float(s) * 1.7)
			_stamp(img, pos, w, 0)

func _stamp(img: Image, center: Vector2, radius: float, channel: int) -> void:
	var s := img.get_width()
	var y0: int = maxi(0, int(center.y - radius - 1))
	var y1: int = mini(s - 1, int(center.y + radius + 1))
	var x0: int = maxi(0, int(center.x - radius - 1))
	var x1: int = mini(s - 1, int(center.x + radius + 1))
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var d: float = Vector2(float(x) - center.x, float(y) - center.y).length()
			var rr: float = radius * (0.82 + 0.18 * sin(float(x) * 1.7 + float(y) * 2.3))
			if d > rr:
				continue
			var px: Color = img.get_pixel(x, y)
			px[channel] = maxf(px[channel], clampf(1.0 - (d / rr) * 0.35, 0.5, 1.0))
			img.set_pixel(x, y, px)

# ── helpers ────────────────────────────────────────────────
func _arr(key: String) -> Array:
	return _layout.get(key, [])

func _rand_pt(margin: float) -> Vector2:
	return Vector2(_rng.randf_range(margin, _world - margin), _rng.randf_range(margin, _world - margin))

# ── crisp varied detail scatter + off-map void ─────────────
func _draw() -> void:
	_draw_void()
	for i in int(_world * _world / 175000.0):
		_grass_tuft(_rand_pt(40.0))
	for i in int(_world * _world / 320000.0):
		_small_stone(_rand_pt(50.0))
	for i in int(_world * _world / 260000.0):
		_branch(_rand_pt(60.0))
	for i in int(_world * _world / 300000.0):
		_flower(_rand_pt(60.0))
	for c in _arr("rocky"):
		for k in 12:
			_small_stone(c + Vector2(_rng.randf_range(-95.0, 95.0), _rng.randf_range(-80.0, 80.0)))
	for c in _arr("forests"):
		_leaf_litter(c)
		_roots(c)
	for c in _arr("golds"):
		_mining_debris(c)

func _draw_void() -> void:
	var w := _world
	draw_rect(Rect2(-EXT, -EXT, w + 2.0 * EXT, EXT), FOG_COLOR)
	draw_rect(Rect2(-EXT, w, w + 2.0 * EXT, EXT), FOG_COLOR)
	draw_rect(Rect2(-EXT, 0.0, EXT, w), FOG_COLOR)
	draw_rect(Rect2(w, 0.0, EXT, w), FOG_COLOR)

func _grass_tuft(c: Vector2) -> void:
	var g := Color(0.22, 0.40, 0.16).lerp(Color(0.44, 0.56, 0.26), _rng.randf())
	for k in 3 + _rng.randi() % 4:
		var x := c.x + _rng.randf_range(-7.0, 7.0)
		draw_line(Vector2(x, c.y), Vector2(x + _rng.randf_range(-3.0, 3.0), c.y - _rng.randf_range(6.0, 13.0)), g, 1.5)

func _small_stone(c: Vector2) -> void:
	var s := _rng.randf_range(2.5, 6.0)
	var grey := Color(0.46, 0.47, 0.50).lerp(Color(0.34, 0.35, 0.39), _rng.randf())
	var pts := PackedVector2Array()
	var sides := 5 + _rng.randi() % 3
	var rot := _rng.randf() * TAU
	for k in sides:
		var a := rot + float(k) / float(sides) * TAU
		var r := s * (0.75 + 0.25 * _rng.randf())
		pts.append(c + Vector2(cos(a) * r, sin(a) * r * 0.8))
	draw_colored_polygon(pts, grey)

func _flower(c: Vector2) -> void:
	var palette := [Color(0.92, 0.92, 0.95), Color(0.95, 0.82, 0.30), Color(0.70, 0.45, 0.85), Color(0.90, 0.55, 0.70)]
	var col: Color = palette[_rng.randi() % palette.size()]
	for k in 2 + _rng.randi() % 2:
		var p := c + Vector2(_rng.randf_range(-6.0, 6.0), _rng.randf_range(-5.0, 5.0))
		draw_line(p, p + Vector2(0, 5), Color(0.20, 0.34, 0.16), 1.3)
		draw_circle(p, 2.0, col)

func _branch(c: Vector2) -> void:
	var col := Color(0.34, 0.24, 0.13).lerp(Color(0.46, 0.34, 0.18), _rng.randf())
	var dir := Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(7.0, 14.0)
	draw_line(c - dir, c + dir, col, 1.8)
	draw_line(c, c + dir.rotated(0.6) * 0.5, col, 1.4)  # a small offshoot

func _leaf_litter(c: Vector2) -> void:
	var cols := [Color(0.42, 0.30, 0.15), Color(0.52, 0.38, 0.17), Color(0.34, 0.40, 0.18)]
	for k in 6:
		var p := c + Vector2(_rng.randf_range(-90.0, 90.0), _rng.randf_range(-75.0, 75.0))
		draw_circle(p, _rng.randf_range(1.2, 2.6), cols[_rng.randi() % cols.size()])

## Roots creeping out from a grove base.
func _roots(c: Vector2) -> void:
	var col := Color(0.32, 0.22, 0.12)
	var base := c + Vector2(0.0, 18.0)
	for k in 4:
		var a := PI * 0.5 + _rng.randf_range(-1.1, 1.1)
		var tip := base + Vector2(cos(a), sin(a)) * _rng.randf_range(18.0, 34.0)
		draw_line(base, tip, col, 2.0)
		draw_line(tip, tip + Vector2(cos(a), sin(a)).rotated(0.5) * 10.0, col, 1.4)

## Rubble + a couple of tailing piles near a mine.
func _mining_debris(c: Vector2) -> void:
	for k in 5:
		_small_stone(c + Vector2(_rng.randf_range(-70.0, 70.0), _rng.randf_range(30.0, 70.0)))
	var rubble := Color(0.40, 0.36, 0.30, 0.9)
	draw_circle(c + Vector2(_rng.randf_range(-50.0, 50.0), 60.0), _rng.randf_range(6.0, 10.0), rubble)
