extends Node2D

## Terrain system. The ground itself is rendered by a texture-splatting shader
## (assets/shaders/terrain.gdshader) that blends grass / dry grass / dirt by
## noise with crisp transitions, plus a per-map CONTROL splat that turns the
## ground under resources into the right material (gold -> excavated dirt,
## forest -> leaf litter, berries -> fertile soil). On top, this node draws a
## sparse, VARIED scatter of ground detail (grass tufts, small stones, leaf
## litter) — no blurry overlays, no repeated stamps — and fills the off-map void
## with solid dark so there is no black border. Deterministic from the map seed.

const EXT: float = 2600.0
const FOG_COLOR: Color = Color(0.035, 0.045, 0.060, 1.0)
const SHADER: String = "res://assets/shaders/terrain.gdshader"
const CONTROL_SIZE: int = 256

var _rng := RandomNumberGenerator.new()
var _world: float = MapConfig.WORLD_SIZE
var _scale: float = MapConfig.SCALE

## Large, intentional terrain features (placed once per map, deterministic).
var _rocky: Array[Vector2] = []
var _fertile: Array[Vector2] = []

func _ready() -> void:
	z_index = -9
	_rng.seed = hash(GameSettings.selected_map)
	for i in 4:
		_rocky.append(_rand_pt(340.0))
	for i in 3:
		_fertile.append(_rand_pt(340.0))
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
	# Only the grass biome gets the dry-grass second layer; others blend with
	# their own base so no green creeps onto sand/ash.
	mat.set_shader_parameter("drygrass", load("res://assets/terrain/grass_dry.png") if is_grass else base)
	mat.set_shader_parameter("dirt", load("res://assets/terrain/dirt.png"))
	mat.set_shader_parameter("noise_tex", load("res://assets/terrain/noise.png"))
	mat.set_shader_parameter("control", _build_control())
	mat.set_shader_parameter("world_size", _world)
	mat.set_shader_parameter("tile_px", 512.0)
	ground.material = mat
	# The shader handles colour; drop the old flat per-map tint (deferred so it
	# wins over map_loader, which also sets modulate in its _ready).
	(ground as CanvasItem).set_deferred("modulate", Color.WHITE)

## RGBA control splat over the whole map. r = excavated dirt/gravel (gold mines,
## bases), g = leaf litter (forests), b = fertile soil (berries). Crisp noisy
## discs, not soft gradients.
func _build_control() -> ImageTexture:
	var s := CONTROL_SIZE
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 1))
	var k: float = float(s) / _world
	for c in _seeds("gold_mines") + _seeds("extra_gold_mines"):
		_stamp(img, c * k, 15.0, 0)
	for c in _seeds("trees") + _seeds("extra_trees"):
		_stamp(img, c * k, 11.0, 1)
	for c in _seeds("food_nodes"):
		_stamp(img, c * k, 9.0, 2)
	var tc: Vector2 = (MapConfig.get_map(GameSettings.selected_map).get("player_start", Vector2(300, 500)) as Vector2)
	var etc: Vector2 = (MapConfig.get_map(GameSettings.selected_map).get("enemy_tc", MapConfig.DEFAULT_ENEMY_TC) as Vector2)
	_stamp(img, tc * _scale * k, 17.0, 0)
	_stamp(img, etc * _scale * k, 17.0, 0)
	# Intentional features: rocky patches (dirt+gravel), fertile areas, and a
	# worn travel route between the two bases.
	for c in _rocky:
		_stamp(img, c * k, 22.0, 0)
	for c in _fertile:
		_stamp(img, c * k, 24.0, 2)
	var a: Vector2 = tc * _scale * k
	var b: Vector2 = etc * _scale * k
	var steps: int = maxi(1, int(a.distance_to(b) / 3.0))
	for i in range(steps + 1):
		_stamp(img, a.lerp(b, float(i) / float(steps)), 3.5, 0)
	return ImageTexture.create_from_image(img)

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
			var v: float = clampf(1.0 - (d / rr) * 0.35, 0.5, 1.0)
			px[channel] = maxf(px[channel], v)
			img.set_pixel(x, y, px)

# ── helpers ────────────────────────────────────────────────
func _cfg() -> Dictionary:
	return MapConfig.get_map(GameSettings.selected_map)

func _seeds(key: String) -> Array:
	var out: Array = []
	for p in _cfg().get(key, []) as Array:
		out.append((p as Vector2) * _scale)
	return out

func _rand_pt(margin: float) -> Vector2:
	return Vector2(_rng.randf_range(margin, _world - margin), _rng.randf_range(margin, _world - margin))

# ── crisp varied scatter + off-map void ────────────────────
func _draw() -> void:
	_draw_void()
	var area := _world * _world
	# Sparse scatter (~60% fewer than before); stones live mostly in the rocky
	# patches so they read as an intentional feature, not random litter.
	for i in int(area / 175000.0):
		_grass_tuft(_rand_pt(40.0))
	for i in int(area / 300000.0):
		_small_stone(_rand_pt(50.0))
	for c in _rocky:
		for k in 12:
			_small_stone(c + Vector2(_rng.randf_range(-95.0, 95.0), _rng.randf_range(-80.0, 80.0)))
	for c in _seeds("trees") + _seeds("extra_trees"):
		_leaf_litter(c)

func _draw_void() -> void:
	var w := _world
	draw_rect(Rect2(-EXT, -EXT, w + 2.0 * EXT, EXT), FOG_COLOR)
	draw_rect(Rect2(-EXT, w, w + 2.0 * EXT, EXT), FOG_COLOR)
	draw_rect(Rect2(-EXT, 0.0, EXT, w), FOG_COLOR)
	draw_rect(Rect2(w, 0.0, EXT, w), FOG_COLOR)

func _grass_tuft(c: Vector2) -> void:
	var g := Color(0.22, 0.40, 0.16).lerp(Color(0.44, 0.56, 0.26), _rng.randf())
	var blades := 3 + _rng.randi() % 4
	for k in blades:
		var x := c.x + _rng.randf_range(-7.0, 7.0)
		var h := _rng.randf_range(6.0, 13.0)
		draw_line(Vector2(x, c.y), Vector2(x + _rng.randf_range(-3.0, 3.0), c.y - h), g, 1.5)

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

func _leaf_litter(c: Vector2) -> void:
	var cols := [Color(0.42, 0.30, 0.15), Color(0.52, 0.38, 0.17), Color(0.34, 0.40, 0.18)]
	for k in 6:
		var p := c + Vector2(_rng.randf_range(-95.0, 95.0), _rng.randf_range(-80.0, 80.0))
		draw_circle(p, _rng.randf_range(1.2, 2.6), cols[_rng.randi() % cols.size()])
