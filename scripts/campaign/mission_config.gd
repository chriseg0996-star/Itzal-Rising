class_name MissionConfig
extends RefCounted

## Ordered single-player campaign. Each mission reuses the skirmish World but
## overlays a fixed map/faction/difficulty plus an optional handicap modifier
## (applied by map_loader when ActiveMission.is_active()). Escalating challenge
## via difficulty + modifiers; victory v1 reuses destroy-all-enemy-buildings.
##
## modifier: "none" | "enemy_eco_boost" | "player_handicap" | "fast_aggro"

const MISSIONS: Array[Dictionary] = [
	{
		"id": "m1",
		"name": "First Light",
		"map": "Jungle Basin",
		"faction_id": 0,
		"difficulty": "easy",
		"modifier": "none",
		"intro": "The Decay have taken root in the basin. Build your base, raise an army, and burn out their outpost.",
	},
	{
		"id": "m2",
		"name": "Reef Assault",
		"map": "Sunken Reef",
		"faction_id": 0,
		"difficulty": "normal",
		"modifier": "none",
		"intro": "They regrouped on the reef. The footing is treacherous — expect a stiffer fight.",
	},
	{
		"id": "m3",
		"name": "Coastal Siege",
		"map": "Azure Coast",
		"faction_id": 0,
		"difficulty": "normal",
		"modifier": "enemy_eco_boost",
		"intro": "The coastal nest is well-supplied. The enemy starts with a resource stockpile — out-tech them fast.",
	},
	{
		"id": "m4",
		"name": "Into the Crags",
		"map": "Volcanic Crags",
		"faction_id": 0,
		"difficulty": "hard",
		"modifier": "fast_aggro",
		"intro": "Deep in the crags the Decay attack relentlessly. Hold the line and counter-push.",
	},
	{
		"id": "m5",
		"name": "Lattice Gambit",
		"map": "Jungle Basin",
		"faction_id": 2,
		"difficulty": "hard",
		"modifier": "enemy_eco_boost",
		"intro": "Lead the Ix Architects. No archers — lean on lattice guards and lancers to shatter their entrenched host.",
	},
]

static func get_mission(mission_id: String) -> Dictionary:
	for m in MISSIONS:
		if String(m.get("id", "")) == mission_id:
			return m
	return {}

static func index_of(mission_id: String) -> int:
	for i in MISSIONS.size():
		if String(MISSIONS[i].get("id", "")) == mission_id:
			return i
	return -1

## The id of the mission after `mission_id`, or "" if it was the last.
static func next_id(mission_id: String) -> String:
	var idx: int = index_of(mission_id)
	if idx >= 0 and idx + 1 < MISSIONS.size():
		return String(MISSIONS[idx + 1].get("id", ""))
	return ""
