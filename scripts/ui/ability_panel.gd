extends CanvasLayer

## One active ability per faction, cast with E or the panel button, on a
## shared 60s cooldown. Match-scoped on purpose: lives in the World tree so a
## restart/exit resets it for free (no autoload reset wiring). The cooldown is
## exposed for SaveManager via the "ability_panel" group.

const ABILITIES: Dictionary = {
	0: {"name": "Jaguar's Vigor", "desc": "Heal all your units +30 HP"},
	1: {"name": "Corruption Burst", "desc": "25 dmg to hostiles near your TC"},
	2: {"name": "Lattice Overcharge", "desc": "+5 armor to your units, 10 s"},
}
const COOLDOWN: float = 60.0
const ACCENT: Color = Color(0.0, 0.85, 0.85, 1.0)
const WHITE: Color = Color(0.92, 0.95, 0.98, 1.0)

const BURST_RADIUS: float = 350.0
const BURST_DAMAGE: int = 25
const VIGOR_HEAL: float = 30.0
const OVERCHARGE_ARMOR: float = 5.0
const OVERCHARGE_DURATION: float = 10.0

var _cooldown_remaining: float = 0.0
var _buff_active: bool = false
var _button: Button = null
var _sweep: ColorRect = null

func _ready() -> void:
	add_to_group("ability_panel")
	_build()

func _build() -> void:
	var def: Dictionary = ABILITIES.get(GameSettings.player_faction_id, ABILITIES[0])
	var accent: Color = ACCENT
	var fac: FactionData = FactionManager.get_faction(GameSettings.player_faction_id)
	if fac != null:
		accent = fac.primary_color

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.15, 0.18, 0.96)
	sb.set_border_width_all(1)
	sb.border_color = Color(accent.r, accent.g, accent.b, 0.7)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(6)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_left = -470.0
	panel.offset_top = 52.0
	panel.offset_right = -260.0
	panel.offset_bottom = 100.0

	_button = Button.new()
	_button.text = "%s (E)" % def["name"]
	_button.tooltip_text = String(def["desc"])
	_button.flat = true
	_button.add_theme_color_override("font_color", WHITE)
	_button.add_theme_color_override("font_hover_color", accent)
	_button.add_theme_font_size_override("font_size", 13)
	_button.pressed.connect(try_cast)
	panel.add_child(_button)

	_sweep = ColorRect.new()
	_sweep.color = Color(0.04, 0.05, 0.08, 0.7)
	_sweep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_button.add_child(_sweep)
	_sweep.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	_sweep.visible = false

func _process(delta: float) -> void:
	if _cooldown_remaining <= 0.0:
		return
	_cooldown_remaining = maxf(_cooldown_remaining - delta, 0.0)
	var def: Dictionary = ABILITIES.get(GameSettings.player_faction_id, ABILITIES[0])
	if _cooldown_remaining > 0.0:
		_button.text = "%s %.0fs" % [def["name"], ceilf(_cooldown_remaining)]
		_sweep.visible = true
		_sweep.offset_right = -_button.size.x * (1.0 - _cooldown_remaining / COOLDOWN)
	else:
		_button.text = "%s (E)" % def["name"]
		_button.disabled = false
		_sweep.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("use_ability"):
		try_cast()
		get_viewport().set_input_as_handled()

func try_cast() -> void:
	if get_tree().paused or _cooldown_remaining > 0.0:
		return
	_execute_ability()
	_cooldown_remaining = COOLDOWN
	_button.disabled = true

func get_cooldown() -> float:
	return _cooldown_remaining

func set_cooldown(value: float) -> void:
	_cooldown_remaining = clampf(value, 0.0, COOLDOWN)
	if _button != null:
		_button.disabled = _cooldown_remaining > 0.0

func _execute_ability() -> void:
	var def: Dictionary = ABILITIES.get(GameSettings.player_faction_id, ABILITIES[0])
	AlertManager.push("%s!" % def["name"], "info")
	SoundManager.play("unit_select")
