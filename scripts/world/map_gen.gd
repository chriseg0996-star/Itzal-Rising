class_name MapGen
extends RefCounted

## Structured RTS map layout where FORESTS ARE GEOGRAPHY: connected formations
## (walls, corners, lines) that block movement (the navmesh is carved around
## them) and shape the battlefield — chokepoints, lanes, clearings, expansion
## pockets. Deterministic from a seed so resources, terrain and the navmesh all
## agree. Asymmetric on purpose.
##
## Returns:
##   forests : Array[Vector2]            grove spawn points (dense along formations)
##   blockers: Array[PackedVector2Array] obstruction polygons for the navmesh
##   berries, golds, rocky, fertile      Array[Vector2] resource/terrain seeds
##   roads   : Array[Array[Vector2]]     dirt-road polylines
##   bases   : Array[Vector2]            [player, enemy]

const GROVE_STEP: float = 76.0   # spacing of groves along a formation
const WALL_T: float = 150.0      # forest-wall thickness (nav + visual)

static func generate(p: Vector2, e: Vector2, world: float, seed_val: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	var forests: Array[Vector2] = []
	var blockers: Array = []
	var berries: Array[Vector2] = []
	var golds: Array[Vector2] = []
	var rocky: Array[Vector2] = []
	var fertile: Array[Vector2] = []
	var roads: Array = []

	var mid: Vector2 = (p + e) * 0.5
	var axis: Vector2 = (e - p).normalized()
	var perp: Vector2 = axis.orthogonal()

	# ── central forest WALL across the axis, with one off-centre gap (chokepoint) ──
	var gap_t: float = rng.randf_range(0.38, 0.60)
	var span: float = world * 1.4
	var w0: Vector2 = mid - perp * span * 0.5
	var w1: Vector2 = mid + perp * span * 0.5
	var gap_c: Vector2 = mid + perp * (gap_t - 0.5) * span + axis * rng.randf_range(-90.0, 90.0)
	var gap_half: Vector2 = perp * 165.0
	_wall(forests, blockers, w0, gap_c - gap_half, WALL_T, world, rng)
	_wall(forests, blockers, gap_c + gap_half, w1, WALL_T, world, rng)
	# contested centre: gold + fertile clearing right at the chokepoint (unsafe).
	golds.append(_clamp(gap_c + axis * rng.randf_range(-60.0, 60.0), world))
	fertile.append(_clamp(gap_c, world))

	# ── home pockets: each base framed by an L of forest (corner), open inward ──
	for idx in 2:
		var base: Vector2 = p if idx == 0 else e
		var inward: Vector2 = (mid - base).normalized()
		var bperp: Vector2 = inward.orthogonal()
		var s: float = 1.0 if rng.randf() < 0.5 else -1.0
		# two short forest arms making a sheltered corner behind the base
		var corner: Vector2 = base - inward * 360.0
		_wall(forests, blockers, corner - bperp * 360.0, corner + bperp * 60.0, 130.0, world, rng)
		_wall(forests, blockers, corner + bperp * s * 70.0, corner + bperp * s * 70.0 - inward * 360.0, 130.0, world, rng)
		# safe home resources inside the pocket
		_cluster(berries, _clamp(base + inward * 250.0 + bperp * s * rng.randf_range(60.0, 150.0), world), 3, 55.0, rng)
		golds.append(_clamp(base + inward * 470.0 - bperp * s * rng.randf_range(120.0, 260.0), world))
		# a wood line to one side (safe wood), partly blocking
		_wall(forests, blockers, base + bperp * s * 330.0 + inward * 120.0, base + bperp * s * 330.0 - inward * 280.0, 120.0, world, rng)
		roads.append([base, gap_c])

	# ── two off-axis EXPANSION pockets: forest line on the outer side, gold inside ──
	for s2 in [1.0, -1.0]:
		var ex: Vector2 = _clamp(mid + perp * s2 * world * 0.36 + axis * rng.randf_range(-world * 0.16, world * 0.16), world)
		var out: Vector2 = (ex - mid).normalized()
		_wall(forests, blockers, ex + out * 150.0 - perp * 240.0, ex + out * 150.0 + perp * 240.0, 130.0, world, rng)
		golds.append(ex)
		_cluster(berries, _clamp(ex - out * 150.0, world), 2, 50.0, rng)
		rocky.append(_clamp(ex + axis * rng.randf_range(-150.0, 150.0), world))
		roads.append([_nearest(ex, [p, e]), ex])

	return {"forests": forests, "blockers": blockers, "berries": berries,
		"golds": golds, "rocky": rocky, "fertile": fertile, "roads": roads,
		"bases": [p, e]}


## Places groves densely along a->b (organic jitter) and appends a thick
## obstruction quad covering the band, so the formation reads and blocks as a
## continuous forest wall.
static func _wall(forests: Array, blockers: Array, a: Vector2, b: Vector2, thickness: float, world: float, rng: RandomNumberGenerator) -> void:
	var delta: Vector2 = b - a
	var length: float = delta.length()
	if length < 1.0:
		return
	var dir: Vector2 = delta / length
	var perp: Vector2 = dir.orthogonal()
	var n: int = int(length / GROVE_STEP)
	for i in n + 1:
		var t: float = float(i) / float(maxi(n, 1))
		var pos: Vector2 = a + dir * length * t
		pos += perp * rng.randf_range(-thickness * 0.3, thickness * 0.3)
		pos += dir * rng.randf_range(-16.0, 16.0)
		forests.append(_clamp(pos, world))
	var e0: Vector2 = a - dir * thickness * 0.5
	var e1: Vector2 = b + dir * thickness * 0.5
	var h: Vector2 = perp * thickness * 0.5
	blockers.append(PackedVector2Array([e0 + h, e1 + h, e1 - h, e0 - h]))


static func _cluster(arr: Array, center: Vector2, n: int, spread: float, rng: RandomNumberGenerator) -> void:
	arr.append(center)
	for i in maxi(0, n - 1):
		arr.append(center + Vector2(rng.randf_range(-spread, spread), rng.randf_range(-spread, spread)))


static func _clamp(v: Vector2, world: float) -> Vector2:
	return Vector2(clampf(v.x, 150.0, world - 150.0), clampf(v.y, 150.0, world - 150.0))


static func _nearest(v: Vector2, pts: Array) -> Vector2:
	var best: Vector2 = pts[0]
	for q in pts:
		if v.distance_to(q) < v.distance_to(best):
			best = q
	return best
