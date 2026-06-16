class_name UnitSeparation

## Shared local-separation steering so units never stack on the same pixel.
## Used by MovementComponent (combat units) and the villager scripts (which move
## via NavigationAgent2D directly). Every unit joins the "combat_units" group, so
## one query covers villagers, soldiers, archers and cavalry of both sides.

const RADIUS: float = 28.0
const STRENGTH: float = 65.0
const GROUP: StringName = &"combat_units"

## Returns a push-away velocity from nearby units (stronger the closer they are).
static func push(unit: Node2D, radius: float = RADIUS, strength: float = STRENGTH) -> Vector2:
	var p: Vector2 = Vector2.ZERO
	var pos: Vector2 = unit.global_position
	var r2: float = radius * radius
	for other in unit.get_tree().get_nodes_in_group(GROUP):
		if other == unit or not is_instance_valid(other) or not (other is Node2D):
			continue
		var op: Vector2 = (other as Node2D).global_position
		var d2: float = pos.distance_squared_to(op)
		if d2 >= r2:
			continue
		if d2 <= 0.0001:
			# Coincident: nudge in a per-unit fixed direction so they still split.
			p += Vector2.from_angle(float(unit.get_instance_id() % 16) / 16.0 * TAU)
			continue
		var d: float = sqrt(d2)
		p += (pos - op) / d * (1.0 - d / radius)
	return p * strength
