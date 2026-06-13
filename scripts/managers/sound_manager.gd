extends Node

## Plays one-shot SFX via a pool of AudioStreamPlayer nodes.
## All sounds are optional — if the .ogg file is absent, plays nothing silently.
## Never crashes on missing audio files. Registered as the "SoundManager" autoload.

const SOUNDS: Dictionary = {
	"unit_select":     "res://assets/sfx/unit_select.wav",
	"unit_move":       "res://assets/sfx/unit_move.wav",
	"unit_attack":     "res://assets/sfx/unit_attack.wav",
	"unit_death":      "res://assets/sfx/unit_death.wav",
	"building_place":  "res://assets/sfx/building_place.wav",
	"building_hit":    "res://assets/sfx/building_hit.wav",
	"resource_gather": "res://assets/sfx/resource_gather.wav",
}

# Music is whatever real files the user drops into these folders
# (.ogg/.mp3/.wav — Godot 4 imports all three). Menus play the menu folder,
# matches the match folder. Each ships empty/silent until a file exists.
const MENU_MUSIC_DIR: String = "res://assets/music/menu"
const MATCH_MUSIC_DIR: String = "res://assets/music/match"
const MUSIC_VOLUME_DB: float = -6.0  # the playing level; the MUSIC bus slider scales from here

# Pool of AudioStreamPlayer nodes for overlap support.
const POOL_SIZE: int = 8
var _pool: Array[AudioStreamPlayer] = []
var _pool_index: int = 0
var _music_player: AudioStreamPlayer = null
var _playlist: Array[String] = []
var _track_index: int = 0
var _mode: String = ""  # "menu" | "match" | "" — what the active playlist is
var _fade_tween: Tween = null

func _ready() -> void:
	# Route to an "SFX" bus if the project defines one; otherwise Master.
	var bus: StringName = &"SFX" if AudioServer.get_bus_index("SFX") != -1 else &"Master"
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = bus
		add_child(p)
		_pool.append(p)
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = &"MUSIC" if AudioServer.get_bus_index("MUSIC") != -1 else &"Master"
	add_child(_music_player)
	_music_player.finished.connect(_on_track_finished)

## Shuffled list of res:// audio paths in a folder. Empty if the dir is absent.
func _scan_dir(dir_path: String) -> Array[String]:
	var out: Array[String] = []
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return out
	for file in dir.get_files():
		# Exported builds list remapped names — trim the import suffix first.
		var name: String = file
		if name.ends_with(".import") or name.ends_with(".remap"):
			name = name.get_basename()
		var ext: String = name.get_extension().to_lower()
		if ext in ["ogg", "mp3", "wav"]:
			var path: String = "%s/%s" % [dir_path, name]
			if not out.has(path):
				out.append(path)
	out.shuffle()
	return out

## Called by every menu scene's _ready. No-op while already playing menu music
## so hopping MainMenu <-> Settings <-> Skirmish never restarts the track.
func start_menu_music() -> void:
	if _mode == "menu" and _music_player != null and _music_player.playing:
		return
	_switch_to("menu", _scan_dir(MENU_MUSIC_DIR))

## Called when a match world loads. Empty match folder => silence (the menu
## track is stopped so it doesn't bleed into the match).
func start_match_music() -> void:
	if _mode == "match" and _music_player != null and _music_player.playing:
		return
	_switch_to("match", _scan_dir(MATCH_MUSIC_DIR))

func _switch_to(mode: String, playlist: Array[String]) -> void:
	_mode = mode
	_playlist = playlist
	_track_index = 0
	if _music_player == null:
		return
	if _playlist.is_empty():
		stop_music()  # nothing for this context — silence the current track
		return
	_play_current()

func _play_current() -> void:
	if _track_index >= _playlist.size():
		_track_index = 0
		_playlist.shuffle()
	var path: String = _playlist[_track_index]
	if not ResourceLoader.exists(path):
		return
	var stream: AudioStream = load(path)
	if stream == null:
		return
	_set_no_loop(stream)  # full tracks play once, then `finished` advances
	_music_player.stream = stream
	_music_player.volume_db = -40.0
	_music_player.play()
	_fade_to(MUSIC_VOLUME_DB, 1.0)

func _on_track_finished() -> void:
	if _playlist.is_empty():
		return
	_track_index += 1
	_play_current()

func stop_music(fade: float = 0.8) -> void:
	if _music_player == null or not _music_player.playing:
		return
	if fade <= 0.0:
		_music_player.stop()
		return
	_fade_to(-40.0, fade)
	# stop after the fade so the next start_*_music begins cleanly. If a new
	# track started during the fade (playlist switch), don't cut it.
	var stream_at_fade: AudioStream = _music_player.stream
	await get_tree().create_timer(fade).timeout
	if _music_player != null and _music_player.stream == stream_at_fade:
		_music_player.stop()

func _fade_to(target_db: float, duration: float) -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(_music_player, "volume_db", target_db, duration)

func _set_no_loop(stream: AudioStream) -> void:
	if stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_DISABLED
	elif "loop" in stream:
		stream.set("loop", false)

func play(sound_name: String, volume_db: float = 0.0) -> void:
	if not SOUNDS.has(sound_name):
		return
	var path: String = SOUNDS[sound_name]
	if not ResourceLoader.exists(path):
		return  # silent — file not yet added
	var stream: AudioStream = load(path)
	if stream == null:
		return
	var player: AudioStreamPlayer = _pool[_pool_index % POOL_SIZE]
	_pool_index += 1
	player.stream = stream
	player.volume_db = volume_db
	player.play()
