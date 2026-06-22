class_name MapGen
extends RefCounted

## Structured RTS map layout — strategic geography instead of scattered resources.
## Deterministic from a seed, so map_loader (spawns resources) and ground_decor
## (terrain control splat, roads, decorations) produce the SAME layout from the
## same inputs without sharing state.
##
## Composition (AoE4 / WC3 inspired):
##   - home wood + berries next to each base; gold a little farther.
##   - a forest WALL across the middle with a single off-centre gap (chokepoint).
##   - a contested gold + fertile clearing at the chokepoint.
##   - two off-axis EXPANSION sites (gold + wood + rocky), resource-rich.
##   - a few secondary forest clusters with open clearings between them.
##   - dirt ROADS (polylines) base -> chokepoint -> base and base -> expansion.
## Asymmetric on purpose (jittered, off-centre gap) — never a mirror.

static func generate(p: Vector2, e: Vector2, world: float, seed_val: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	var forests: Array[Vector2] = []
	var berries: Array[Vector2] = []
	var golds: Array[Vector2] = []
	var rocky: Array[Vector2] = []
	var fertile: Array[Vector2] = []
	var roads: Array = []

	var mid: Vector2 = (p + e) * 0.5
	var axis: Vector2 = (e - p).normalized()
	var perp: Vector2 = axis.orthogonal()
	var span: float = world * 0.78

	# ── home resources at each base ───────────────────────────
	for idx in 2:
		var base: Vector2 = p if idx == 0 else e
		var inward: Vector2 = (mid - base).normalized()
		var side: float = 1.0 if rng.randf() < 0.5 else -1.0
		_patch(berries, _clamp(base + inward * 250.0 + perp * side * rng.randf_range(60.0, 150.0), world), 3, 55.0, rng)
		_patch(forests, _clamp(base + inward * 380.0 - perp * side * rng.randf_range(180.0, 320.0), world), 4, 95.0, rng)
		_patch(forests, _clamp(base + inward * 300.0 + perp * side * rng.randf_range(280.0, 430.0), world), 3, 90.0, rng)
		golds.append(_clamp(base + inward * 560.0 + perp * side * rng.randf_range(-120.0, 120.0), world))

	# ── forest wall across the middle with one off-centre gap (chokepoint) ──
	var gap_t: float = rng.randf_range(0.36, 0.60)
	var count: int = 9
	for i in count:
		var t: float = (float(i) + 0.5) / float(count)
		if absf(t - gap_t) < 0.10:
			continue  # the chokepoint
		var pos: Vector2 = mid + perp * (t - 0.5) * span + axis * rng.randf_range(-150.0, 150.0)
		_patch(forests, _clamp(pos, world), 2 + rng.randi() % 2, 90.0, rng)

	# ── contested centre: gold + fertile clearing at the chokepoint ──
	var choke: Vector2 = _clamp(mid + perp * (gap_t - 0.5) * span * 0.5, world)
	golds.append(choke + axis * rng.randf_range(-70.0, 70.0))
	fertile.append(choke)

	# ── two off-axis expansion sites (resource-rich) ──
	for s in [1.0, -1.0]:
		var ex: Vector2 = _clamp(mid + perp * s * world * 0.34 + axis * rng.randf_range(-world * 0.12, world * 0.12), world)
		golds.append(ex)
		_patch(forests, _clamp(ex - perp * s * 190.0, world), 3, 95.0, rng)
		_patch(berries, _clamp(ex + axis * 170.0, world), 2, 50.0, rng)
		rocky.append(ex + axis * rng.randf_range(-160.0, 160.0))
		roads.append([_nearest(ex, [p, e]), ex])

	# ── secondary forest clusters (leave clearings between) ──
	for i in 3:
		var c: Vector2 = _clamp(Vector2(rng.randf_range(world * 0.2, world * 0.8), rng.randf_range(world * 0.2, world * 0.8)), world)
		if c.distance_to(p) < 700.0 or c.distance_to(e) < 700.0:
			continue
		_patch(forests, c, 3, 95.0, rng)

	# ── roads: main route through the chokepoint ──
	roads.append([p, choke, e])

	return {"forests": forests, "berries": berries, "golds": golds,
		"rocky": rocky, "fertile": fertile, "roads": roads}


static func _patch(arr: Array, center: Vector2, n: int, spread: float, rng: RandomNumberGenerator) -> void:
	arr.append(center)
	for i in maxi(0, n - 1):
		arr.append(center + Vector2(rng.randf_range(-spread, spread), rng.randf_range(-spread, spread)))


static func _clamp(v: Vector2, world: float) -> Vector2:
	return Vector2(clampf(v.x, 170.0, world - 170.0), clampf(v.y, 170.0, world - 170.0))


static func _nearest(v: Vector2, pts: Array) -> Vector2:
	var best: Vector2 = pts[0]
	for q in pts:
		if v.distance_to(q) < v.distance_to(best):
			best = q
	return best
