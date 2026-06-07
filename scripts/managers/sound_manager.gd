extends Node

## Plays one-shot SFX via a pool of AudioStreamPlayer nodes.
## All sounds are optional — if the .ogg file is absent, plays nothing silently.
## Never crashes on missing audio files. Registered as the "SoundManager" autoload.

const SOUNDS: Dictionary = {
	"unit_select":     "res://assets/sfx/unit_select.ogg",
	"unit_move":       "res://assets/sfx/unit_move.ogg",
	"unit_attack":     "res://assets/sfx/unit_attack.ogg",
	"unit_death":      "res://assets/sfx/unit_death.ogg",
	"building_place":  "res://assets/sfx/building_place.ogg",
	"building_hit":    "res://assets/sfx/building_hit.ogg",
	"resource_gather": "res://assets/sfx/resource_gather.ogg",
}

# Pool of AudioStreamPlayer nodes for overlap support.
const POOL_SIZE: int = 8
var _pool: Array[AudioStreamPlayer] = []
var _pool_index: int = 0

func _ready() -> void:
	# Route to an "SFX" bus if the project defines one; otherwise Master.
	var bus: StringName = &"SFX" if AudioServer.get_bus_index("SFX") != -1 else &"Master"
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = bus
		add_child(p)
		_pool.append(p)

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
