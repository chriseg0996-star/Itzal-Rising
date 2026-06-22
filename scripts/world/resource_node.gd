class_name ResourceNode
extends Node2D

signal resource_depleted(node: ResourceNode)
signal amount_changed(remaining: int)

@export var resource_type:    StringName = &"wood"
@export var amount:           int        = 100
@export var harvest_per_tick: int        = 10
@export var sprite_asset:     String     = "tree"

## Gold keeps a type-coded pad so it reads apart; forests & berry bushes use
## painted art instead and show a circle only when selected.
const TINT_WOOD: Color = Color(0.30, 0.78, 0.36, 1.0)
const TINT_GOLD: Color = Color(0.97, 0.78, 0.16, 1.0)
const TINT_FOOD: Color = Color(0.90, 0.27, 0.36, 1.0)

## Painted resource variants — one chosen at random per node; MapLoader nudges
## adjacent duplicates apart afterwards.
const FOREST_VARIANTS: Array[String] = [
	"res://assets/world/forest_a.png", "res://assets/world/forest_b.png",
	"res://assets/world/forest_c.png", "res://assets/world/forest_d.png",
]
const BERRY_VARIANTS: Array[String] = [
	"res://assets/world/berry_a.png", "res://assets/world/berry_b.png",
	"res://assets/world/berry_c.png", "res://assets/world/berry_d.png",
]
const MINE_VARIANTS: Array[String] = [
	"res://assets/world/mine_a.png", "res://assets/world/mine_b.png",
	"res://assets/world/mine_c.png", "res://assets/world/mine_d.png",
]
const FOREST_WIDTH: float = 120.0   # ~1.5x the Town Hall's visible core
const BERRY_WIDTH: float = 42.0     # ~35% of a forest — a compact food node
const MINE_WIDTH: float = 140.0     # between a berry patch and a forest cluster
const FOREST_AMOUNT: int = 2200
const MINE_AMOUNT: int = 3500     # fewer, larger formations carry more ore

var variant: int = -1
var selected: bool = false
var _variants: Array[String] = []
var _width: float = 0.0

func _ready() -> void:
	add_to_group("resources")
	if is_forest():
		amount = maxi(amount, FOREST_AMOUNT)
		_setup_painted(FOREST_VARIANTS, FOREST_WIDTH, "forests", -2)
	elif is_food():
		_setup_painted(BERRY_VARIANTS, BERRY_WIDTH, "berries", -1)
	elif is_gold():
		amount = maxi(amount, MINE_AMOUNT)
		_setup_painted(MINE_VARIANTS, MINE_WIDTH, "mines", -1)
	else:
		_apply_sprite(sprite_asset)
		TextureGenerator.attach_shadow(self, 32.0, 13.0, 2.0, 0.30)
	queue_redraw()

func is_forest() -> bool:
	var t: String = String(resource_type)
	return t == "wood" or t == "madera"

func is_food() -> bool:
	var t: String = String(resource_type)
	return t == "comida" or t == "food"

func is_gold() -> bool:
	var t: String = String(resource_type)
	return t == "oro" or t == "gold"

func is_painted() -> bool:
	return is_forest() or is_food() or is_gold()

## Shared setup for painted resource art (forests, berry bushes): random variant,
## grove/bush sprite scaled to `width`, ground shadow, drawn below units (so a
## unit is never hidden), and a click/harvest footprint over the visible body.
func _setup_painted(variants: Array[String], width: float, grp: String, z: int) -> void:
	add_to_group(grp)
	_variants = variants
	_width = width
	variant = randi() % variants.size()
	_apply_painted_sprite()
	TextureGenerator.attach_shadow(self, width * 0.60, width * 0.22, width * 0.05, 0.34)
	z_index = z
	_fit_painted_collision()

## Swaps/creates the BuildingSprite to the chosen variant, scaled to `_width` and
## lifted so the base sits at the node origin (where the shadow + harvest are).
func _apply_painted_sprite() -> void:
	var spr: Node = get_node_or_null("BuildingSprite")
	if spr == null:
		var made := Sprite2D.new()
		made.name = "BuildingSprite"
		add_child(made)
		spr = made
		var placeholder := get_node_or_null("Sprite")
		if placeholder is CanvasItem:
			(placeholder as CanvasItem).visible = false
	var s := spr as Sprite2D
	var tex: Texture2D = load(_variants[variant])
	if tex == null:
		return
	s.texture = tex
	s.centered = true
	var sc: float = _width / float(tex.get_width())
	s.scale = Vector2(sc, sc)
	s.position = Vector2(0.0, -float(tex.get_height()) * sc * 0.40)

## Used by MapLoader's de-dup pass to avoid same-variant neighbours.
func set_painted_variant(i: int) -> void:
	if _variants.is_empty():
		return
	variant = i % _variants.size()
	_apply_painted_sprite()

## Fits the click/harvest footprint to the painted body (canopy + base) — picking
## is a point query, so the shape must cover where the art is drawn (lifted with
## the sprite) or right-click-to-harvest misses it.
func _fit_painted_collision() -> void:
	var col: Node = get_node_or_null("Area2D/CollisionShape2D")
	if not (col is CollisionShape2D):
		return
	var rs := RectangleShape2D.new()
	rs.size = Vector2(_width * 0.74, _width * 0.62)
	(col as CollisionShape2D).shape = rs
	(col as CollisionShape2D).position = Vector2(0.0, -_width * 0.32)

func set_selected(value: bool) -> void:
	if selected == value:
		return
	selected = value
	queue_redraw()

## Painted resources (forest/berry): only a ring when selected. Gold: a
## persistent type-coded pad so it reads apart.
func _draw() -> void:
	var c: Color = type_color()
	if is_painted():
		if selected:
			draw_arc(Vector2.ZERO, _width * 0.5, 0.0, TAU, 48, Color(c.r, c.g, c.b, 0.9), 3.0, true)
		return
	draw_circle(Vector2.ZERO, 26.0, Color(c.r, c.g, c.b, 0.18))
	draw_arc(Vector2.ZERO, 26.0, 0.0, TAU, 40, Color(c.r, c.g, c.b, 0.7), 3.0, true)

func type_color() -> Color:
	var t: String = String(resource_type)
	if t == "oro" or t == "gold":
		return TINT_GOLD
	if is_food():
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
