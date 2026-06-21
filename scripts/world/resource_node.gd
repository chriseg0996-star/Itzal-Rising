class_name ResourceNode
extends Node2D

signal resource_depleted(node: ResourceNode)
signal amount_changed(remaining: int)

@export var resource_type:    StringName = &"wood"
@export var amount:           int        = 100
@export var harvest_per_tick: int        = 10
@export var sprite_asset:     String     = "tree"

## Type-coded ground tint so wood / gold / food read apart at a glance (the
## sprites share the slate-&-neon palette and otherwise blend together).
const TINT_WOOD: Color = Color(0.30, 0.78, 0.36, 1.0)
const TINT_GOLD: Color = Color(0.97, 0.78, 0.16, 1.0)
const TINT_FOOD: Color = Color(0.90, 0.27, 0.36, 1.0)

func _ready() -> void:
	add_to_group("resources")
	_apply_sprite(sprite_asset)
	queue_redraw()

## A soft color-coded pad on the ground under the node + a brighter ring.
func _draw() -> void:
	var c: Color = type_color()
	draw_circle(Vector2.ZERO, 26.0, Color(c.r, c.g, c.b, 0.18))
	draw_arc(Vector2.ZERO, 26.0, 0.0, TAU, 40, Color(c.r, c.g, c.b, 0.7), 3.0, true)

## Resource accent colour, by type (handles both en/es type strings).
func type_color() -> Color:
	var t: String = String(resource_type)
	if t == "oro" or t == "gold":
		return TINT_GOLD
	if t == "comida" or t == "food":
		return TINT_FOOD
	return TINT_WOOD

func is_depleted() -> bool:
	return amount <= 0

func get_remaining() -> int:
	return amount

func harvest() -> int:
	if is_depleted():
		return 0
	var taken: int = mini(harvest_per_tick, amount)
	amount -= taken
	amount_changed.emit(amount)
	if is_depleted():
		resource_depleted.emit(self)
		queue_free()
	return taken

func _apply_sprite(asset: String) -> void:
	if asset == "":
		return
	var existing := get_node_or_null("Sprite")
	if existing != null and existing is CanvasItem:
		(existing as CanvasItem).visible = false
	var sprite_2d := Sprite2D.new()
	sprite_2d.texture = TextureGenerator.get_texture(asset)
	sprite_2d.centered = true
	add_child(sprite_2d)
	if existing != null:
		move_child(sprite_2d, existing.get_index() + 1)
