class_name FactionData
extends Resource

## Pure data describing a single faction (team). Owned/registered by the
## FactionManager autoload. `hostile_to` lists the faction ids this faction
## treats as enemies for combat targeting.

@export var id: int = 0
@export var display_name: String = ""
@export var hostile_to: Array[int] = []
@export var primary_color: Color = Color.WHITE

## Combat stat modifiers applied to this faction's UNITS at spawn
## (StatComponent/CombatComponent _ready). Buildings are unaffected.
@export var atk_mult: float = 1.0
@export var armor_bonus: float = 0.0
@export var hp_mult: float = 1.0
