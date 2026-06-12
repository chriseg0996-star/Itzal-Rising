extends Node

## Pure data store for skirmish/match configuration plus persisted user settings.
## Read by SkirmishSetup (writes) and EnemyAI (reads difficulty). Registered as
## the "GameSettings" autoload.
## NOTE: no `class_name` — an autoload that shares its name with a global class
## raises "Class hides an autoload singleton" in Godot 4. Access via the singleton.

const SETTINGS_PATH: String = "user://settings.cfg"

var difficulty: String = "normal"
## Team id the human player controls this match (FactionManager ids).
## 0 = default player, 2 = Ix Architects. Set to 2 to field the Ix faction.
var player_faction_id: int = 0

## SkirmishSetup screen selection.
var selected_map: String = "Jungle Basin"

## Persisted user settings (user://settings.cfg).
var master_volume: float = 1.0
var sfx_volume: float = 1.0
var music_volume: float = 1.0
var fullscreen: bool = true

func _ready() -> void:
	# This autoload runs before SoundManager, so the SFX/MUSIC buses exist
	# before the pool players pick their bus.
	_ensure_bus(&"SFX")
	_ensure_bus(&"MUSIC")
	load_settings()
	apply_settings()

func _ensure_bus(bus_name: StringName) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	var idx: int = AudioServer.bus_count
	AudioServer.add_bus(idx)
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, &"Master")

func apply_settings() -> void:
	_apply_bus_volume(&"Master", master_volume)
	_apply_bus_volume(&"SFX", sfx_volume)
	_apply_bus_volume(&"MUSIC", music_volume)
	var mode: DisplayServer.WindowMode = DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)

func _apply_bus_volume(bus: StringName, linear: float) -> void:
	var idx: int = AudioServer.get_bus_index(bus)
	if idx == -1:
		return
	# linear_to_db(0) is -inf — mute instead.
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.0001)))
	AudioServer.set_bus_mute(idx, linear <= 0.0)

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return  # first run / unreadable: keep defaults
	master_volume = clampf(float(cfg.get_value("audio", "master_volume", master_volume)), 0.0, 1.0)
	sfx_volume = clampf(float(cfg.get_value("audio", "sfx_volume", sfx_volume)), 0.0, 1.0)
	music_volume = clampf(float(cfg.get_value("audio", "music_volume", music_volume)), 0.0, 1.0)
	fullscreen = bool(cfg.get_value("display", "fullscreen", fullscreen))

func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master_volume", master_volume)
	cfg.set_value("audio", "sfx_volume", sfx_volume)
	cfg.set_value("audio", "music_volume", music_volume)
	cfg.set_value("display", "fullscreen", fullscreen)
	cfg.save(SETTINGS_PATH)
