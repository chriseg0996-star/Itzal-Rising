extends Node2D

const HARVEST_AMOUNT: int = 10

@export var resource_type: String = "madera"
@export var amount: int = 100
@export var sprite_asset: String = "tree"

func _ready() -> void:
	add_to_group("resources")
	_apply_sprite(sprite_asset)

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

func harvest(faction: String = "player") -> int:
	var taken: int = min(HARVEST_AMOUNT, amount)
	if taken <= 0:
		return 0
	amount -= taken
	ResourceManager.add(resource_type, taken, faction)
	if faction == "player":
		GameStats.resources_gathered += taken
	if amount <= 0:
		queue_free()
	return taken
