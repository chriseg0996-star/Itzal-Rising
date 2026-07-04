class_name CommandMarker
extends Node2D

## Brief ground confirmation drawn where the player issues an order — a ring that
## converges on the point plus a small cross. Colour encodes intent:
## green = move, amber = attack-move, cyan = gather. Self-frees. Pure vector, no
## art. Spawned by SelectionManager so every command reads as acknowledged.

const LIFE: float = 0.42
const R0: float = 30.0

const MOVE: Color = Color(0.30, 0.92, 0.45)
const ATTACK: Color = Color(0.97, 0.55, 0.20)
const GATHER: Color = Color(0.0, 0.85, 0.85)

var _color: Color = MOVE
var _t: float = 0.0

static func spawn(tree: SceneTree, pos: Vector2, color: Color) -> void:
	var world: Node = tree.current_scene
	if world == null:
		return
	var m := CommandMarker.new()
	m._color = color
	m.z_index = 55
	world.add_child(m)
	m.global_position = pos

func _process(delta: float) -> void:
	_t += delta
	if _t >= LIFE:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var k: float = _t / LIFE            # 0 -> 1
	var a: float = 1.0 - k
	# Two rings contracting toward the point (classic "target locked" read).
	for off in [0.0, 0.16]:
		var kk: float = clampf(k + off, 0.0, 1.0)
		var r: float = R0 * (1.0 - kk) + 5.0
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 32,
			Color(_color.r, _color.g, _color.b, a * (1.0 - off)), 2.5, true)
	# Small centre cross that fades in as the rings converge.
	var c: Color = Color(_color.r, _color.g, _color.b, a * k)
	draw_line(Vector2(-5, 0), Vector2(5, 0), c, 2.0)
	draw_line(Vector2(0, -5), Vector2(0, 5), c, 2.0)
