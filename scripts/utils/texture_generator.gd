extends Node

var cache: Dictionary = {}

func get_texture(asset: String) -> ImageTexture:
	if cache.has(asset):
		return cache[asset]
	var img: Image = _create_image(asset)
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	cache[asset] = tex
	return tex

func _create_image(asset: String) -> Image:
	match asset:
		"villager":
			return _make_humanoid(Color(0.95, 0.82, 0.55), Color(0.91, 0.75, 0.48), Color(0.35, 0.25, 0.15))
		"enemy_villager":
			return _make_humanoid(Color(0.78, 0.62, 0.85), Color(0.65, 0.41, 0.74), Color(0.30, 0.18, 0.36))
		"ix_weaver":
			return _make_humanoid(Color(1.0, 0.78, 0.42), Color(1.0, 0.6, 0.1), Color(0.5, 0.3, 0.05))
		"soldier":
			return _make_soldier(Color(0.75, 0.22, 0.17), Color(0.55, 0.15, 0.10))
		"enemy_soldier":
			return _make_soldier(Color(0.56, 0.27, 0.68), Color(0.38, 0.18, 0.48))
		"ix_lattice_guard":
			return _make_soldier(Color(1.0, 0.6, 0.1), Color(0.7, 0.4, 0.05))
		"archer":
			return _make_archer()
		"tree":
			return _make_tree()
		"goldmine":
			return _make_goldmine()
		"town_center":
			return _make_town_center(Color(0.55, 0.45, 0.33), Color(0.40, 0.32, 0.22), Color(0.30, 0.20, 0.10), Color(0.40, 0.50, 0.65))
		"enemy_town_center":
			return _make_town_center(Color(0.42, 0.20, 0.51), Color(0.28, 0.13, 0.35), Color(0.18, 0.08, 0.22), Color(0.30, 0.20, 0.45))
		"barracks":
			return _make_barracks(Color(0.36, 0.25, 0.20), Color(0.25, 0.17, 0.12), Color(0.18, 0.10, 0.05), Color(0.50, 0.40, 0.30))
		"enemy_barracks":
			return _make_barracks(Color(0.36, 0.17, 0.44), Color(0.25, 0.10, 0.30), Color(0.18, 0.05, 0.22), Color(0.45, 0.30, 0.50))
		"tower":
			return _make_tower()
		"monument":
			return _make_monument()
		"menu_bg":
			return _make_gradient(Color(0.039, 0.051, 0.078, 1), Color(0.106, 0.129, 0.188, 1), 128, 256)
	return _make_blank()

func _make_gradient(top: Color, bottom: Color, w: int, h: int) -> Image:
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in range(h):
		var t: float = float(y) / float(h - 1)
		var c: Color = top.lerp(bottom, t)
		for x in range(w):
			img.set_pixel(x, y, c)
	return img

func _make_blank() -> Image:
	var img: Image = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 0, 1, 1))
	return img

func _make_humanoid(head: Color, body: Color, leg: Color) -> Image:
	var img: Image = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	img.fill_rect(Rect2i(11, 5, 10, 8), head)
	img.fill_rect(Rect2i(12, 13, 8, 10), body)
	img.fill_rect(Rect2i(8, 14, 4, 6), body)
	img.fill_rect(Rect2i(20, 14, 4, 6), body)
	img.fill_rect(Rect2i(12, 23, 3, 8), leg)
	img.fill_rect(Rect2i(17, 23, 3, 8), leg)
	return img

func _make_soldier(armor: Color, dark: Color) -> Image:
	var img: Image = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var skin: Color = Color(0.95, 0.78, 0.55)
	var weapon: Color = Color(0.75, 0.75, 0.80)
	var weapon_grip: Color = Color(0.30, 0.20, 0.12)
	img.fill_rect(Rect2i(10, 3, 12, 7), dark)
	img.fill_rect(Rect2i(13, 9, 6, 4), skin)
	img.fill_rect(Rect2i(9, 13, 14, 12), armor)
	img.fill_rect(Rect2i(11, 13, 10, 2), dark)
	img.fill_rect(Rect2i(6, 14, 3, 8), armor)
	img.fill_rect(Rect2i(23, 14, 3, 8), armor)
	img.fill_rect(Rect2i(11, 25, 4, 6), dark)
	img.fill_rect(Rect2i(17, 25, 4, 6), dark)
	img.fill_rect(Rect2i(26, 22, 2, 2), weapon_grip)
	img.fill_rect(Rect2i(25, 5, 3, 17), weapon)
	return img

func _make_archer() -> Image:
	var img: Image = Image.create(28, 28, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var green: Color = Color(0.15, 0.68, 0.38)
	var dark_green: Color = Color(0.08, 0.42, 0.22)
	var skin: Color = Color(0.95, 0.78, 0.55)
	var bow: Color = Color(0.40, 0.25, 0.10)
	img.fill_rect(Rect2i(9, 3, 10, 6), dark_green)
	img.fill_rect(Rect2i(11, 7, 6, 3), skin)
	img.fill_rect(Rect2i(9, 10, 10, 9), green)
	img.fill_rect(Rect2i(6, 11, 3, 6), green)
	img.fill_rect(Rect2i(19, 11, 3, 6), green)
	img.fill_rect(Rect2i(10, 19, 3, 6), dark_green)
	img.fill_rect(Rect2i(15, 19, 3, 6), dark_green)
	for y in range(4, 23):
		var t: float = float(y - 13) / 9.0
		var dx: int = int((1.0 - t * t) * 3.0)
		var px: int = 1 + dx
		if px >= 0 and px < 28:
			img.set_pixel(px, y, bow)
		if px + 1 >= 0 and px + 1 < 28:
			img.set_pixel(px + 1, y, bow)
	for y in range(5, 22):
		img.set_pixel(5, y, bow)
	return img

func _make_tree() -> Image:
	var img: Image = Image.create(48, 48, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var dark_green: Color = Color(0.10, 0.40, 0.18)
	var mid_green: Color = Color(0.20, 0.55, 0.25)
	var trunk: Color = Color(0.35, 0.22, 0.12)
	var trunk_dark: Color = Color(0.22, 0.14, 0.08)
	img.fill_rect(Rect2i(20, 36, 8, 12), trunk)
	img.fill_rect(Rect2i(20, 36, 2, 12), trunk_dark)
	for y in range(2, 38):
		var spread: int = int(float(y - 2) / 36.0 * 22.0) + 2
		var x0: int = 24 - spread
		var x1: int = 24 + spread
		for x in range(x0, x1):
			if x >= 0 and x < 48:
				var c: Color = mid_green if ((x * 3 + y * 5) % 7) < 3 else dark_green
				img.set_pixel(x, y, c)
	return img

func _make_goldmine() -> Image:
	var img: Image = Image.create(48, 48, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var rock: Color = Color(0.50, 0.38, 0.25)
	var rock_dark: Color = Color(0.32, 0.24, 0.16)
	var gold: Color = Color(0.95, 0.82, 0.25)
	var gold_dark: Color = Color(0.70, 0.55, 0.15)
	for y in range(8, 44):
		var ny: float = float(y - 26) / 18.0
		var width_f: float = 18.0 * sqrt(max(0.0, 1.0 - ny * ny))
		var w: int = int(width_f)
		for x in range(24 - w, 24 + w):
			if x >= 0 and x < 48:
				var c: Color = rock if ((x * 3 + y * 5) % 7) < 5 else rock_dark
				img.set_pixel(x, y, c)
	var flecks: Array = [Vector2i(18, 18), Vector2i(28, 22), Vector2i(20, 28), Vector2i(30, 30), Vector2i(22, 36)]
	for f in flecks:
		for dx in range(2):
			for dy in range(2):
				var px: int = f.x + dx
				var py: int = f.y + dy
				if px >= 0 and px < 48 and py >= 0 and py < 48:
					var c: Color = gold if (dx + dy) % 2 == 0 else gold_dark
					img.set_pixel(px, py, c)
	return img

func _make_town_center(wall: Color, roof: Color, door: Color, window: Color) -> Image:
	var img: Image = Image.create(96, 96, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	img.fill_rect(Rect2i(8, 30, 80, 60), wall)
	for y in range(2, 30):
		var spread: int = int(float(30 - y) / 28.0 * 46.0)
		for x in range(48 - spread, 48 + spread):
			if x >= 0 and x < 96:
				img.set_pixel(x, y, roof)
	img.fill_rect(Rect2i(40, 60, 16, 30), door)
	img.fill_rect(Rect2i(18, 42, 12, 12), window)
	img.fill_rect(Rect2i(66, 42, 12, 12), window)
	img.fill_rect(Rect2i(18, 47, 12, 2), wall)
	img.fill_rect(Rect2i(23, 42, 2, 12), wall)
	img.fill_rect(Rect2i(66, 47, 12, 2), wall)
	img.fill_rect(Rect2i(71, 42, 2, 12), wall)
	img.fill_rect(Rect2i(4, 86, 88, 4), roof)
	return img

func _make_barracks(wall: Color, accent: Color, door: Color, window: Color) -> Image:
	var img: Image = Image.create(80, 80, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	img.fill_rect(Rect2i(4, 16, 72, 60), wall)
	img.fill_rect(Rect2i(2, 8, 76, 12), accent)
	for y in range(2, 8):
		var spread: int = int(float(8 - y) / 6.0 * 32.0)
		for x in range(40 - spread, 40 + spread):
			if x >= 0 and x < 80:
				img.set_pixel(x, y, accent)
	img.fill_rect(Rect2i(32, 46, 16, 30), door)
	img.fill_rect(Rect2i(14, 28, 10, 10), window)
	img.fill_rect(Rect2i(56, 28, 10, 10), window)
	img.fill_rect(Rect2i(6, 68, 6, 4), accent)
	img.fill_rect(Rect2i(68, 68, 6, 4), accent)
	return img

func _make_monument() -> Image:
	var img: Image = Image.create(64, 96, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var basalt: Color = Color(0.10, 0.11, 0.14)
	var basalt_dark: Color = Color(0.06, 0.07, 0.09)
	var glyph: Color = Color(0.0, 0.90, 0.78)
	# Stepped base
	img.fill_rect(Rect2i(8, 84, 48, 10), basalt_dark)
	img.fill_rect(Rect2i(14, 76, 36, 10), basalt)
	# Obelisk column, tapering to a point
	for y in range(8, 78):
		var t: float = float(y - 8) / 70.0
		var half: int = 4 + int(t * 10.0)
		for x in range(32 - half, 32 + half):
			img.set_pixel(x, y, basalt if ((x + y) % 9) > 0 else basalt_dark)
	# Neon glyph bands
	for band_y in [24, 44, 64]:
		var t: float = float(band_y - 8) / 70.0
		var half: int = 3 + int(t * 9.0)
		img.fill_rect(Rect2i(32 - half, band_y, half * 2, 3), glyph)
	# Glowing apex
	img.fill_rect(Rect2i(30, 4, 4, 6), glyph)
	return img

func _make_tower() -> Image:
	var img: Image = Image.create(48, 48, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var stone: Color = Color(0.55, 0.58, 0.58)
	var stone_dark: Color = Color(0.35, 0.40, 0.42)
	var window: Color = Color(0.15, 0.15, 0.20)
	img.fill_rect(Rect2i(14, 12, 20, 32), stone)
	for y in range(12, 44):
		if y % 4 == 0:
			for x in range(14, 34):
				img.set_pixel(x, y, stone_dark)
	img.fill_rect(Rect2i(10, 42, 28, 4), stone_dark)
	img.fill_rect(Rect2i(12, 6, 24, 6), stone_dark)
	img.fill_rect(Rect2i(12, 2, 4, 4), stone)
	img.fill_rect(Rect2i(20, 2, 4, 4), stone)
	img.fill_rect(Rect2i(28, 2, 4, 4), stone)
	img.fill_rect(Rect2i(22, 18, 4, 8), window)
	return img
