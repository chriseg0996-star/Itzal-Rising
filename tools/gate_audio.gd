extends SceneTree

## Audio gate: every SoundManager sound (and music track, if defined) must
## exist, load as a WAV stream with real length, and play without error.
## Exit 0 = pass, 1 = any failure (printed).
## Usage: godot --headless --path . --script res://tools/gate_audio.gd

var _frames: int = 0

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 2:
		return false
	var sm: Node = root.get_node("/root/SoundManager")
	var failed: bool = false
	for key in sm.SOUNDS:
		var path: String = String(sm.SOUNDS[key])
		if not ResourceLoader.exists(path):
			print("FAIL missing: %s -> %s" % [key, path])
			failed = true
			continue
		var stream: AudioStream = load(path)
		if stream == null or not (stream is AudioStreamWAV):
			print("FAIL not a WAV stream: %s" % key)
			failed = true
			continue
		if stream.get_length() <= 0.04:
			print("FAIL too short (%f s): %s" % [stream.get_length(), key])
			failed = true
	for key in sm.SOUNDS:
		sm.play(String(key))
	# Menu music: must not error with an empty (or populated) playlist folder.
	sm.start_menu_music()
	if failed:
		print("GATE_AUDIO_FAIL")
		quit(1)
	else:
		print("GATE_AUDIO_OK")
		quit(0)
	return false
