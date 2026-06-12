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

const MUSIC_TRACKS: Dictionary = {
	"ambient": "res://assets/music/ambient_loop.wav",
}

# Pool of AudioStreamPlayer nodes for overlap support.
const POOL_SIZE: int = 8
var _pool: Array[AudioStreamPlayer] = []
var _pool_index: int = 0
var _music_player: AudioStreamPlayer = null

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
	call_deferred("play_music", "ambient")

func play_music(track: String) -> void:
	if not MUSIC_TRACKS.has(track):
		return
	var path: String = MUSIC_TRACKS[track]
	if not ResourceLoader.exists(path):
		return  # silent — file not yet added
	var stream: AudioStream = load(path)
	if stream == null:
		return
	if stream is AudioStreamWAV:
		# Loop in code so it survives reimports; 16-bit mono → 2 bytes/frame.
		var wav := stream as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = wav.data.size() / 2
	_music_player.stream = stream
	_music_player.play()

func stop_music() -> void:
	if _music_player != null:
		_music_player.stop()

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
