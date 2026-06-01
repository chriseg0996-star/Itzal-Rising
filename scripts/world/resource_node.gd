class_name ResourceNode
extends Node2D

signal resource_depleted(node: ResourceNode)
signal amount_changed(remaining: int)

@export var resource_type:    StringName = &"wood"
@export var amount:           int        = 100
@export var harvest_per_tick: int        = 10
@export var sprite_asset:     String     = "tree"

func _ready() -> void:
	add_to_group("resources")
	_apply_sprite(sprite_asset)

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
