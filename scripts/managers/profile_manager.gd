extends Node

## Persistent player profile across sessions (user://profile.cfg). Tracks
## career totals, per-faction win/loss, best clear times per map, and which
## campaign missions are cleared. Mirrors game_settings.gd's ConfigFile pattern.
## Registered as the "ProfileManager" autoload.

const PROFILE_PATH: String = "user://profile.cfg"

var first_run: bool = true
var games_played: int = 0
var wins: int = 0
var losses: int = 0
var total_enemies_killed: int = 0
var total_units_lost: int = 0
var total_buildings_destroyed: int = 0
var playtime: float = 0.0
var faction_wins: Dictionary = {0: 0, 1: 0, 2: 0}
var faction_losses: Dictionary = {0: 0, 1: 0, 2: 0}
var best_times: Dictionary = {}        # map name -> seconds (lower is better)
var cleared_missions: Array[String] = []

func _ready() -> void:
	load_profile()

func load_profile() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PROFILE_PATH) != OK:
		return  # first run / unreadable: keep defaults (never corrupts)
	first_run = bool(cfg.get_value("meta", "first_run", true))
	games_played = int(cfg.get_value("totals", "games_played", 0))
	wins = int(cfg.get_value("totals", "wins", 0))
	losses = int(cfg.get_value("totals", "losses", 0))
	total_enemies_killed = int(cfg.get_value("totals", "enemies_killed", 0))
	total_units_lost = int(cfg.get_value("totals", "units_lost", 0))
	total_buildings_destroyed = int(cfg.get_value("totals", "buildings_destroyed", 0))
	playtime = float(cfg.get_value("totals", "playtime", 0.0))
	for fid in [0, 1, 2]:
		faction_wins[fid] = int(cfg.get_value("faction_%d" % fid, "wins", 0))
		faction_losses[fid] = int(cfg.get_value("faction_%d" % fid, "losses", 0))
	var bt: Variant = cfg.get_value("best_times", "map_times", "{}")
	var parsed: Variant = JSON.parse_string(String(bt))
	if parsed is Dictionary:
		best_times = parsed
	# Stored as a JSON array string for robust round-tripping.
	var cm: Variant = cfg.get_value("campaign", "cleared", "[]")
	var cm_parsed: Variant = JSON.parse_string(String(cm))
	cleared_missions.clear()
	if cm_parsed is Array:
		for id in cm_parsed:
			cleared_missions.append(String(id))

func save_profile() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "first_run", first_run)
	cfg.set_value("totals", "games_played", games_played)
	cfg.set_value("totals", "wins", wins)
	cfg.set_value("totals", "losses", losses)
	cfg.set_value("totals", "enemies_killed", total_enemies_killed)
	cfg.set_value("totals", "units_lost", total_units_lost)
	cfg.set_value("totals", "buildings_destroyed", total_buildings_destroyed)
	cfg.set_value("totals", "playtime", playtime)
	for fid in [0, 1, 2]:
		cfg.set_value("faction_%d" % fid, "wins", int(faction_wins.get(fid, 0)))
		cfg.set_value("faction_%d" % fid, "losses", int(faction_losses.get(fid, 0)))
	cfg.set_value("best_times", "map_times", JSON.stringify(best_times))
	cfg.set_value("campaign", "cleared", JSON.stringify(cleared_missions))
	cfg.save(PROFILE_PATH)

## Records a finished match and returns notable deltas for the end screen:
## {"new_best": bool, "prev_best": float}.
func record_match(won: bool, faction_id: int, map_name: String, clear_time: float, stats: Dictionary) -> Dictionary:
	games_played += 1
	playtime += clear_time
	total_enemies_killed += int(stats.get("enemies_killed", 0))
	total_units_lost += int(stats.get("units_lost", 0))
	total_buildings_destroyed += int(stats.get("buildings_destroyed", 0))
	if won:
		wins += 1
		faction_wins[faction_id] = int(faction_wins.get(faction_id, 0)) + 1
	else:
		losses += 1
		faction_losses[faction_id] = int(faction_losses.get(faction_id, 0)) + 1
	var result: Dictionary = {"new_best": false, "prev_best": 0.0}
	if won:
		var prev: float = float(best_times.get(map_name, 0.0))
		if prev <= 0.0 or clear_time < prev:
			result["new_best"] = true
			result["prev_best"] = prev
			best_times[map_name] = clear_time
	if first_run:
		first_run = false
	save_profile()
	return result

func is_mission_cleared(mission_id: String) -> bool:
	return cleared_missions.has(mission_id)

func mark_mission_cleared(mission_id: String) -> void:
	if not cleared_missions.has(mission_id):
		cleared_missions.append(mission_id)
		save_profile()

func get_first_run() -> bool:
	return first_run

func clear_first_run() -> void:
	if first_run:
		first_run = false
		save_profile()
