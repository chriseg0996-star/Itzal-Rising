class_name MapConfig
extends RefCounted

## Data-driven skirmish map layouts, consumed by MapLoader at World load.
## "Jungle Basin" mirrors the literals baked into World.tscn exactly, so the
## default map is a behavioral no-op. Layout rules: all positions inside
## 80..1968 (EnemyAI clamps), TCs >= 1400px apart, at least one gold mine
## within reach of each base.

const DEFAULT_MAP: String = "Jungle Basin"
## EnemyTC's baked offset inside EnemyBase.tscn — moving the EnemyBase root by
## (enemy_tc - this) relocates the whole base while children keep relative pos.
const DEFAULT_ENEMY_TC: Vector2 = Vector2(1600, 1600)

## Biome ground texture per map (tiled by the Ground Sprite2D). Falls back to
## grass for unknown maps (e.g. campaign missions reusing a base map name).
const DEFAULT_GROUND_TEXTURE: String = "res://assets/terrain/grass.png"

const MAPS: Dictionary = {
	"Jungle Basin": {
		"ground_tint": Color(1.0, 1.0, 1.0, 1.0),
		"ground_texture": "res://assets/terrain/grass.png",
		"player_start": Vector2(300, 500),
		"villagers": [Vector2(200, 200), Vector2(300, 200), Vector2(400, 200)],
		"enemy_tc": Vector2(1600, 1600),
		"enemy_soldiers": [Vector2(1400, 1400), Vector2(1500, 1400), Vector2(1450, 1500)],
		"trees": [Vector2(600, 500), Vector2(1200, 400), Vector2(800, 1100), Vector2(1500, 1300), Vector2(350, 1500)],
		"gold_mines": [Vector2(900, 700), Vector2(1700, 900), Vector2(250, 1100)],
		"food_nodes": [Vector2(450, 380), Vector2(700, 650), Vector2(1750, 1500), Vector2(1450, 1750)],
		"extra_trees": [Vector2(1000, 900), Vector2(450, 800)],
		"extra_gold_mines": [Vector2(1300, 1100)],
	},
	"Sunken Reef": {
		"ground_tint": Color(0.75, 0.92, 1.05, 1.0),
		"ground_texture": "res://assets/terrain/sand_reef.png",
		"player_start": Vector2(1700, 350),
		"villagers": [Vector2(1600, 200), Vector2(1700, 200), Vector2(1800, 200)],
		"enemy_tc": Vector2(420, 1650),
		"enemy_soldiers": [Vector2(600, 1450), Vector2(700, 1450), Vector2(650, 1550)],
		"trees": [Vector2(1400, 500), Vector2(900, 400), Vector2(1200, 1100), Vector2(500, 1300), Vector2(1700, 1500)],
		"gold_mines": [Vector2(1500, 650), Vector2(350, 1300), Vector2(1100, 900)],
		"food_nodes": [Vector2(1600, 480), Vector2(1300, 700), Vector2(500, 1550), Vector2(750, 1400)],
		"extra_trees": [Vector2(300, 700), Vector2(1800, 1200), Vector2(1000, 1000)],
		"extra_gold_mines": [Vector2(800, 1100)],
	},
	"Azure Coast": {
		"ground_tint": Color(0.85, 0.95, 1.1, 1.0),
		"ground_texture": "res://assets/terrain/azure_coast.png",
		"player_start": Vector2(280, 1024),
		"villagers": [Vector2(180, 860), Vector2(280, 860), Vector2(380, 860)],
		"enemy_tc": Vector2(1750, 1050),
		"enemy_soldiers": [Vector2(1550, 900), Vector2(1600, 1000), Vector2(1550, 1150)],
		"trees": [Vector2(700, 600), Vector2(700, 1400), Vector2(1200, 300), Vector2(1200, 1750), Vector2(1000, 1024)],
		"gold_mines": [Vector2(450, 1300), Vector2(1650, 1450), Vector2(1024, 700)],
		"food_nodes": [Vector2(420, 900), Vector2(620, 1100), Vector2(1620, 920), Vector2(1500, 1150)],
		"extra_trees": [Vector2(350, 500), Vector2(1500, 600), Vector2(900, 1500)],
		"extra_gold_mines": [Vector2(1024, 1350)],
	},
	"Volcanic Crags": {
		"ground_tint": Color(1.1, 0.85, 0.8, 1.0),
		"ground_texture": "res://assets/terrain/volcanic.png",
		"player_start": Vector2(300, 300),
		"villagers": [Vector2(200, 450), Vector2(300, 470), Vector2(400, 450)],
		"enemy_tc": Vector2(1720, 1720),
		"enemy_soldiers": [Vector2(1500, 1550), Vector2(1600, 1600), Vector2(1550, 1680)],
		# Lean wood (3 of the 5 baked trees survive), rich gold (4 mines).
		"trees": [Vector2(800, 500), Vector2(500, 1000), Vector2(1300, 800)],
		"gold_mines": [Vector2(550, 550), Vector2(1500, 1500), Vector2(1100, 1150)],
		"food_nodes": [Vector2(400, 450), Vector2(620, 700), Vector2(1650, 1600), Vector2(1450, 1850)],
		"extra_trees": [Vector2(950, 650), Vector2(1200, 1300)],
		"extra_gold_mines": [Vector2(1450, 350)],
	},
}

static func get_map(map_name: String) -> Dictionary:
	return MAPS.get(map_name, MAPS[DEFAULT_MAP])
