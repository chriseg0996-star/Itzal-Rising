extends Node

## Pure data store for skirmish/match configuration. Read by SkirmishMenu (writes)
## and EnemyAI (reads difficulty). Registered as the "GameSettings" autoload.
## NOTE: no `class_name` — an autoload that shares its name with a global class
## raises "Class hides an autoload singleton" in Godot 4. Access via the singleton.

var difficulty: String = "normal"
var faction: String = "itzal"
var map: String = "jungle_basin"
## Team id the human player controls this match (FactionManager ids).
## 0 = default player, 2 = Ix Architects. Set to 2 to field the Ix faction.
var player_faction_id: int = 0

## SkirmishSetup screen selections.
var selected_map: String = "Jungle Basin"
var faction_id: int = 0
