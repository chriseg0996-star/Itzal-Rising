extends "res://scripts/buildings/building.gd"

## Ascension Beacon — late-game alternate victory. Once construction completes
## it charges over CHARGE_TIME seconds; full charge wins the match for its
## faction (game_end_panel polls the "beacons" group). Counterplay is baked in:
## the beacon announces itself (alert + minimap ping + AI force-attack), pulses
## cyan while charging, and charge PAUSES while it took damage in the last 3s.
## Standard building HP, no bonus armor — it dies like anything else.

const CHARGE_TIME: float = 180.0
const DAMAGE_PAUSE: float = 3.0
const PULSE_COLOR: Color = Color(0.0, 0.92, 0.80, 1.0)

var charge: float = 0.0
var _last_damage: float = -1000.0
var _announced: bool = false
var _pulse_glow: Sprite2D = null
var _pulse_t: float = 0.0

func _ready() -> void:
	super._ready()
	add_to_group("beacons")
	_pulse_glow = Sprite2D.new()
	_pulse_glow.texture = TextureGenerator.get_texture("soft_blob")
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_pulse_glow.material = mat
	_pulse_glow.position = Vector2(0, -46)
	_pulse_glow.z_index = 2
	_pulse_glow.visible = false
	add_child(_pulse_glow)

func take_damage(amount: int) -> void:
	_last_damage = GameStats.game_time
	super.take_damage(amount)

func is_charge_paused() -> bool:
	return GameStats.game_time - _last_damage < DAMAGE_PAUSE

func get_charge_ratio() -> float:
	return clampf(charge / CHARGE_TIME, 0.0, 1.0)

func is_fully_charged() -> bool:
	return charge >= CHARGE_TIME

func _process(delta: float) -> void:
	super._process(delta)
	if dying or under_construction:
		return
	if not _announced:
		_announced = true
		_announce()
	if not is_charge_paused():
		charge = minf(charge + delta, CHARGE_TIME)
	_tick_pulse(delta)

## The moment a completed beacon exists, both sides know: alert + minimap ping,
## and the AI marches on a player beacon at once (parity with the Monument).
func _announce() -> void:
	var mine: bool = FactionManager.is_player_faction(faction_id)
	AlertManager.push("Ascension Beacon charging!" if mine else "ENEMY BEACON CHARGING — destroy it!",
		"warning" if mine else "error")
	var mm: Node = get_tree().get_first_node_in_group("minimap")
	if mm != null and mm.has_method("ping"):
		mm.ping(global_position)
	if mine:
		EnemyAI.force_attack(global_position)

## Cyan heartbeat while charging; still and dim while paused by damage.
func _tick_pulse(delta: float) -> void:
	if _pulse_glow == null:
		return
	_pulse_glow.visible = not is_fully_charged()
	if is_charge_paused():
		_pulse_glow.modulate = Color(PULSE_COLOR.r, PULSE_COLOR.g, PULSE_COLOR.b, 0.12)
		return
	_pulse_t += delta * 3.0
	var a: float = 0.22 + 0.16 * (0.5 + 0.5 * sin(_pulse_t))
	var s: float = (52.0 + 8.0 * sin(_pulse_t)) / 64.0
	_pulse_glow.modulate = Color(PULSE_COLOR.r, PULSE_COLOR.g, PULSE_COLOR.b, a)
	_pulse_glow.scale = Vector2(s, s)
