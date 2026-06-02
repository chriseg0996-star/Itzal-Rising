class_name FactionData
extends Resource

## Pure data describing a single faction (team). Owned/registered by the
## FactionManager autoload. `hostile_to` lists the faction ids this faction
## treats as enemies for combat targeting.

@export var id: int = 0
@export var display_name: String = ""
@export var hostile_to: Array[int] = []
