class_name ResourceNode
extends Node2D

signal resource_depleted(node: ResourceNode)
signal amount_changed(remaining: int)

@export var resource_type:    StringName = &"wood"
@export var amount:           int        = 100
@export var harvest_per_tick: int        = 10
@export var sprite_asset:     String     = "tree"

## Type-coded ground tint so gold / food read apart at a glance. Forests use the
## painted grove art instead and show a circle only when selected.
const TINT_WOOD: Color = Color(0.30, 0.78, 0.36, 1.0)
const TINT_GOLD: Color = Color(0.97, 0.78, 0.16, 1.0)
const TINT_FOOD: Color = Color(0.90, 0.27, 0.36, 1.0)

## Painted forest grove variants (replace the old triangle trees). One is chosen
## at random per node; MapLoader nudges adjacent duplicates apart afterwards.
const FOREST_VARIANTS: Array[String] = [
	"res://assets/world/forest_a.png",
	"res://assets/world/forest_b.png",
	"res://assets/world/forest_c.png",
	"res://assets/world/forest_d.png",
]
const FOREST_WIDTH: float = 200.0
const FOREST_AMOUNT: int = 2200

var forest_variant: int = -1
var selected: bool = false

func _ready() -> void:
	add_to_group("resources")
	if is_forest():
		add_to_group("forests")
		amount = maxi(amount, FOREST_AMOUNT)
		forest_variant = randi() % FOREST_VARIANTS.size()
		_apply_forest_sprite()
		TextureGenerator.attach_shadow(self, FOREST_WIDTH * 0.60, FOREST_WIDTH * 0.22, 8.0, 0.34)
	else:
		_apply_sprite(sprite_asset)
		TextureGenerator.attach_shadow(self, 32.0, 13.0, 2.0, 0.30)
	queue_redraw()

func is_forest() -> bool:
	var t: String = String(resource_type)
	return t == "wood" or t == "madera"

## Swaps the baked sprite for the chosen grove, scaled to FOREST_WIDTH and lifted
## so the grove's base sits at the node origin (where the shadow + harvest are).
func _apply_forest_sprite() -> void:
	var spr: Node = get_node_or_null("BuildingSprite")
	if not (spr is Sprite2D):
		return
	var s := spr as Sprite2D
	var tex: Texture2D = load(FOREST_VARIANTS[forest_variant])
	if tex == null:
		return
	s.texture = tex
	var sc: float = FOREST_WIDTH / float(tex.get_width())
	s.scale = Vector2(sc, sc)
	s.centered = true
	s.position = Vector2(0.0, -float(tex.get_height()) * sc * 0.40)

## Used by MapLoader's de-dup pass to avoid same-variant neighbours.
func set_forest_variant(i: int) -> void:
	forest_variant = i % FOREST_VARIANTS.size()
	_apply_forest_sprite()

func set_selected(value: bool) -> void:
	if selected == value:
		return
	selected = value
	queue_redraw()

## Forests: only a selection ring when selected. Gold/food: a persistent
## type-coded pad so they read apart.
func _draw() -> void:
	var c: Color = type_color()
	if is_forest():
		if selected:
			draw_arc(Vector2.ZERO, 60.0, 0.0, TAU, 48, Color(c.r, c.g, c.b, 0.9), 3.0, true)
		return
	draw_circle(Vector2.ZERO, 26.0, Color(c.r, c.g, c.b, 0.18))
	draw_arc(Vector2.ZERO, 26.0, 0.0, TAU, 40, Color(c.r, c.g, c.b, 0.7), 3.0, true)

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
