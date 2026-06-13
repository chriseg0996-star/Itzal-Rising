extends Node2D

## A simple homing tracer for ranged attacks (archers, towers). Flies from the
## shooter to the target, then applies the damage on impact. Damage is deferred
## to land — if the target dies or frees mid-flight the projectile just fizzles,
## so it never double-applies or crashes.

const SPEED: float = 700.0
const HIT_DISTANCE: float = 12.0
const LENGTH: float = 14.0  # tracer trail length

var _target: Node2D = null
var _damage: float = 0.0
var _color: Color = Color(1.0, 0.85, 0.3, 1.0)
var _dir: Vector2 = Vector2.RIGHT

func setup(target: Node2D, damage: float, color: Color) -> void:
	_target = target
	_damage = damage
	_color = color

func _physics_process(delta: float) -> void:
	if _target == null or not is_instance_valid(_target):
		queue_free()
		return
	var to_target: Vector2 = _target.global_position - global_position
	var dist: float = to_target.length()
	if dist <= HIT_DISTANCE:
		_apply()
		return
	_dir = to_target / dist
	global_position += _dir * SPEED * delta
	queue_redraw()

func _apply() -> void:
	if _target != null and is_instance_valid(_target):
		var stat: Node = _target.get_node_or_null("StatComponent")
		if stat != null and stat.has_method("take_damage"):
			stat.take_damage(_damage)
		elif _target.has_method("take_damage"):
			_target.take_damage(int(_damage))
		_spawn_impact(_target.global_position)
	queue_free()

func _draw() -> void:
	draw_line(Vector2.ZERO, -_dir * LENGTH, _color, 2.0, true)
	draw_circle(Vector2.ZERO, 2.5, _color)

func _spawn_impact(world_pos: Vector2) -> void:
	var scene: Node = get_tree().current_scene
	if scene != null:
		Particles.spawn(scene, "attack_impact", world_pos)

## Instances a projectile into `parent` and launches it at `target`.
static func fire(parent: Node, from: Vector2, target: Node2D, damage: float, color: Color) -> void:
	if parent == null or not is_instance_valid(parent) or target == null:
		return
	var scene: PackedScene = load("res://scenes/world/Projectile.tscn")
	if scene == null:
		return
	var proj: Node = scene.instantiate()
	parent.add_child(proj)
	if proj is Node2D:
		(proj as Node2D).global_position = from
	if proj.has_method("setup"):
		proj.setup(target, damage, color)
