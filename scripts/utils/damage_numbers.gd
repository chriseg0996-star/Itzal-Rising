class_name DamageNumbers

## Spawns short-lived floating damage numbers at world positions. Static helper
## (mirrors Particles). Capped so a 50-unit brawl can't flood the scene.

const MAX_ACTIVE: int = 40
const RISE: float = 28.0
const LIFETIME: float = 0.6

static var _active: int = 0

static func spawn(parent: Node, amount: float, world_pos: Vector2, color: Color, prefix: String = "") -> void:
	if parent == null or not is_instance_valid(parent):
		return
	if _active >= MAX_ACTIVE:
		return
	var lbl := Label.new()
	lbl.text = "%s%d" % [prefix, int(round(amount))]
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.z_index = 60
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.position = world_pos + Vector2(-8.0, -44.0)
	parent.add_child(lbl)
	_active += 1
	var tween := lbl.create_tween()
	tween.tween_property(lbl, "position:y", lbl.position.y - RISE, LIFETIME)
	tween.parallel().tween_property(lbl, "modulate:a", 0.0, LIFETIME)
	tween.tween_callback(func() -> void: _release(lbl))

static func _release(lbl: Label) -> void:
	_active = maxi(_active - 1, 0)
	if is_instance_valid(lbl):
		lbl.queue_free()
