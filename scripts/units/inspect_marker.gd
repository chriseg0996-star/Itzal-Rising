class_name InspectMarker
extends Node2D

## Neutral targeting ring drawn on a hostile unit/building the player is
## inspecting (read-only). Added as a child of the inspected node so it follows
## it and dies with it. Neutral colour distinguishes it from the player's own
## faction-coloured selection ring.

var radius: float = 26.0
var color: Color = Color(0.95, 0.97, 1.0, 0.9)

func _ready() -> void:
	z_index = 200
	z_as_relative = false
	queue_redraw()

func _draw() -> void:
	# Broken ring (four arcs) reads as a "target" reticle rather than a selection.
	var gap: float = 0.18
	var quarter: float = TAU / 4.0
	for i in 4:
		var start: float = float(i) * quarter + gap
		draw_arc(Vector2.ZERO, radius, start, start + quarter - gap * 2.0, 10, color, 2.5, true)
