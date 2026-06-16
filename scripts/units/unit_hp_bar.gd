class_name UnitHpBar
extends Object

## Makes a unit's on-map HP bar readable over the (green) terrain: adds a dark
## contrast frame behind the existing red/green ColorRects and grows the bar a
## little taller. Called once from each unit's _ready as `UnitHpBar.enhance(self)`.
## The red (HPBarBG) / green (HPBarFG) bars and their resize logic are untouched.

const FRAME_COLOR: Color = Color(0.0, 0.0, 0.0, 0.85)
const EXTRA_HEIGHT: float = 3.0
const PAD: float = 1.0

static func enhance(unit: Node) -> void:
	var bg := unit.get_node_or_null("HPBarBG") as ColorRect
	var fg := unit.get_node_or_null("HPBarFG") as ColorRect
	if bg == null or fg == null:
		return
	# Grow upward so the bottom edge (the FG's resize anchor) stays put.
	bg.offset_top -= EXTRA_HEIGHT
	fg.offset_top -= EXTRA_HEIGHT
	var frame := ColorRect.new()
	frame.name = "HPBarFrame"
	frame.color = FRAME_COLOR
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.offset_left = bg.offset_left - PAD
	frame.offset_top = bg.offset_top - PAD
	frame.offset_right = bg.offset_right + PAD
	frame.offset_bottom = bg.offset_bottom + PAD
	# Deferred: units present at scene load run _ready while the tree is "busy
	# setting up children", which makes a direct add_child fail. Render the frame
	# behind the red/green bars (move to the bg's slot, also deferred so it runs
	# after the add).
	unit.add_child.call_deferred(frame)
	unit.move_child.call_deferred(frame, bg.get_index())
