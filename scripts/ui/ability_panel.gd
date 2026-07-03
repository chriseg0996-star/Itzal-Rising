extends CanvasLayer

## Three active abilities per faction, cast with E / R / Q or the panel buttons,
## each on its own cooldown. Match-scoped (lives in the World tree so a restart
## resets it for free). Cooldowns are exposed for SaveManager via the
## "ability_panel" group.

# faction_id -> ordered list of ability defs. Effects are dispatched by "id".
const ABILITIES: Dictionary = {
	0: [
		{"id": "vigor",  "name": "Jaguar's Vigor",   "desc": "Heal all your units +40 HP",        "cooldown": 60.0},
		{"id": "pack",   "name": "Pack Hunt",        "desc": "+35% move & attack speed, 8s",      "cooldown": 70.0},
		{"id": "ward",   "name": "Ancestral Ward",   "desc": "Repair all your buildings +250 HP", "cooldown": 90.0},
	],
	1: [
		{"id": "burst",  "name": "Corruption Burst", "desc": "30 dmg to hostiles near your TC",    "cooldown": 70.0},
		{"id": "plague", "name": "Plague",           "desc": "8 dmg/s to all enemy units, 5s",     "cooldown": 95.0},
		{"id": "devour", "name": "Devour",           "desc": "Heal units +25 and +25% attack, 8s", "cooldown": 80.0},
	],
	2: [
		{"id": "overcharge", "name": "Lattice Overcharge", "desc": "+6 armor to your units, 10s",      "cooldown": 65.0},
		{"id": "aegis",      "name": "Aegis Field",        "desc": "Your buildings take half dmg, 8s", "cooldown": 90.0},
		{"id": "energize",   "name": "Energize",          "desc": "+150 wood, +120 gold, +90 food",   "cooldown": 110.0},
	],
}
const ACTIONS: Array[String] = ["use_ability", "use_ability_2", "use_ability_3"]
const KEY_LABELS: Array[String] = ["E", "R", "Q"]

const WHITE: Color = Color(0.92, 0.95, 0.98, 1.0)

const VIGOR_HEAL: float = 40.0
const WARD_REPAIR: int = 250
const PACK_SPEED_MULT: float = 1.35
const PACK_ATK_MULT: float = 1.35
const PACK_DURATION: float = 8.0
const BURST_RADIUS: float = 350.0
const BURST_DAMAGE: int = 30
const PLAGUE_DPS: int = 8
const PLAGUE_DURATION: float = 5.0
const DEVOUR_HEAL: float = 25.0
const DEVOUR_ATK_MULT: float = 1.25
const DEVOUR_DURATION: float = 8.0
const OVERCHARGE_ARMOR: float = 6.0
const OVERCHARGE_DURATION: float = 10.0
const AEGIS_REDUCTION: float = 0.5
const AEGIS_DURATION: float = 8.0

var _defs: Array = []
var _cooldowns: Array[float] = []
var _buttons: Array[Button] = []
var _sweeps: Array[ColorRect] = []
var _busy: Dictionary = {}  # ability id -> bool, guards timed buffs from stacking

func _ready() -> void:
	add_to_group("ability_panel")
	_defs = ABILITIES.get(GameSettings.player_faction_id, ABILITIES[0])
	_cooldowns.resize(_defs.size())
	_cooldowns.fill(0.0)
	_build()

func _build() -> void:
	var accent: Color = Color(0.0, 0.85, 0.85, 1.0)
	var fac: FactionData = FactionManager.get_faction(GameSettings.player_faction_id)
	if fac != null:
		accent = fac.primary_color

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", MenuKit.flat_box(4.0, 0.13, true))
	add_child(panel)
	# Integrated into the bottom console's right column: flush on the minimap's
	# top edge, same width — always visible, never overlaps the growing card.
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	panel.offset_left = -312.0
	panel.offset_top = -348.0
	panel.offset_right = 0.0
	panel.offset_bottom = -312.0

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	panel.add_child(hbox)

	for i in _defs.size():
		var def: Dictionary = _defs[i]
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(72, 28)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.text = _short_name(def)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.tooltip_text = "%s (%s)\n%s" % [String(def["name"]), KEY_LABELS[i], String(def["desc"])]
		btn.flat = true
		btn.clip_text = true
		btn.add_theme_color_override("font_color", WHITE)
		btn.add_theme_color_override("font_hover_color", accent)
		btn.add_theme_font_size_override("font_size", 10)
		var idx: int = i
		btn.pressed.connect(func() -> void: try_cast(idx))
		hbox.add_child(btn)
		_buttons.append(btn)
		btn.add_child(_hotkey_chip(KEY_LABELS[i], accent))

		var sweep := ColorRect.new()
		sweep.color = Color(0.04, 0.05, 0.08, 0.7)
		sweep.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(sweep)
		sweep.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
		sweep.visible = false
		_sweeps.append(sweep)

## Small bordered hotkey chip (AoE4-style) docked at the button's right edge.
func _hotkey_chip(key: String, accent: Color) -> PanelContainer:
	var chip := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.06, 0.09, 0.95)
	sb.set_border_width_all(1)
	sb.border_color = Color(accent.r, accent.g, accent.b, 0.5)
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 5.0
	sb.content_margin_right = 5.0
	sb.content_margin_top = 1.0
	sb.content_margin_bottom = 1.0
	chip.add_theme_stylebox_override("panel", sb)
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lbl := Label.new()
	lbl.text = key
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", Color(accent.r, accent.g, accent.b, 0.95))
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(lbl)
	chip.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	chip.offset_left = -24.0
	chip.offset_right = -6.0
	chip.offset_top = -9.0
	chip.offset_bottom = 9.0
	return chip

func _process(delta: float) -> void:
	for i in _cooldowns.size():
		if _cooldowns[i] <= 0.0:
			continue
		_cooldowns[i] = maxf(_cooldowns[i] - delta, 0.0)
		var def: Dictionary = _defs[i]
		if _cooldowns[i] > 0.0:
			_buttons[i].text = "%s %.0fs" % [_short_name(def), ceilf(_cooldowns[i])]
			_sweeps[i].visible = true
			_sweeps[i].offset_right = -_buttons[i].size.x * (1.0 - _cooldowns[i] / float(def["cooldown"]))
		else:
			_buttons[i].text = _short_name(def)
			_buttons[i].disabled = false
			_sweeps[i].visible = false

## Compact label for the integrated ability row ("vigor" -> "Vigor").
func _short_name(def: Dictionary) -> String:
	return String(def["id"]).capitalize()

func _unhandled_input(event: InputEvent) -> void:
	for i in ACTIONS.size():
		if i < _defs.size() and event.is_action_pressed(ACTIONS[i]):
			try_cast(i)
			get_viewport().set_input_as_handled()
			return

func try_cast(index: int) -> void:
	if index < 0 or index >= _defs.size():
		return
	if get_tree().paused or _cooldowns[index] > 0.0:
		return
	var def: Dictionary = _defs[index]
	_execute(String(def["id"]))
	_cooldowns[index] = float(def["cooldown"])
	_buttons[index].disabled = true
	AlertManager.push("%s!" % def["name"], "info")
	SoundManager.play("unit_select")
	var cam: Node = get_tree().get_first_node_in_group("rts_camera")
	if cam != null and cam.has_method("shake"):
		cam.shake(4.0, 0.2)

# SaveManager hooks — cooldowns persist as an array.
func get_cooldowns() -> Array:
	return _cooldowns.duplicate()

func set_cooldowns(values: Array) -> void:
	for i in mini(values.size(), _cooldowns.size()):
		var maxcd: float = float(_defs[i]["cooldown"])
		_cooldowns[i] = clampf(float(values[i]), 0.0, maxcd)
		if _buttons.size() > i:
			_buttons[i].disabled = _cooldowns[i] > 0.0

# Legacy single-cooldown hooks (kept so old saves don't error).
func get_cooldown() -> float:
	return _cooldowns[0] if _cooldowns.size() > 0 else 0.0

func set_cooldown(value: float) -> void:
	if _cooldowns.size() > 0:
		set_cooldowns([value])

func _execute(id: String) -> void:
	match id:
		"vigor": _cast_vigor()
		"pack": _cast_pack()
		"ward": _cast_ward()
		"burst": _cast_burst()
		"plague": _cast_plague()
		"devour": _cast_devour()
		"overcharge": _cast_armor_buff(OVERCHARGE_ARMOR, OVERCHARGE_DURATION)
		"aegis": _cast_aegis()
		"energize": _cast_energize()

# ── Itzal ──────────────────────────────────────────────
func _cast_vigor() -> void:
	var shown: int = 0
	for u in get_tree().get_nodes_in_group("player_units"):
		if not is_instance_valid(u):
			continue
		var stat: Node = u.get_node_or_null("StatComponent")
		if stat != null and stat.has_method("heal"):
			stat.heal(VIGOR_HEAL)
			if shown < 12 and u is Node2D:
				Particles.spawn((u as Node2D).get_parent(), "selection_pulse", (u as Node2D).global_position)
				shown += 1

func _cast_pack() -> void:
	if _busy.get("pack", false):
		return
	_busy["pack"] = true
	var movers: Array = []
	var combats: Array = []
	for u in get_tree().get_nodes_in_group("player_units"):
		if not is_instance_valid(u):
			continue
		var mv: Node = u.get_node_or_null("MovementComponent")
		if mv != null:
			mv.set("speed", float(mv.get("speed")) * PACK_SPEED_MULT)
			movers.append(mv)
		var cc: Node = u.get_node_or_null("CombatComponent")
		if cc != null:
			cc.set("attack_cooldown", float(cc.get("attack_cooldown")) / PACK_ATK_MULT)
			combats.append(cc)
	await get_tree().create_timer(PACK_DURATION).timeout
	for mv in movers:
		if is_instance_valid(mv):
			mv.set("speed", float(mv.get("speed")) / PACK_SPEED_MULT)
	for cc in combats:
		if is_instance_valid(cc):
			cc.set("attack_cooldown", float(cc.get("attack_cooldown")) * PACK_ATK_MULT)
	_busy["pack"] = false

func _cast_ward() -> void:
	for b in get_tree().get_nodes_in_group("player_buildings"):
		if is_instance_valid(b) and b.has_method("repair"):
			b.repair(WARD_REPAIR)
			if b is Node2D:
				Particles.spawn((b as Node2D).get_parent(), "building_place", (b as Node2D).global_position)

# ── Decay ──────────────────────────────────────────────
func _cast_burst() -> void:
	var tc: Node2D = _find_player_tc()
	if tc == null:
		return
	for u in get_tree().get_nodes_in_group("combat_units"):
		if not is_instance_valid(u) or not (u is Node2D) or u.is_in_group("player_units"):
			continue
		var unit: Node2D = u as Node2D
		if tc.global_position.distance_to(unit.global_position) > BURST_RADIUS:
			continue
		if unit.has_method("take_damage"):
			unit.take_damage(BURST_DAMAGE)
			Particles.spawn(unit.get_parent(), "attack_impact", unit.global_position)

func _cast_plague() -> void:
	if _busy.get("plague", false):
		return
	_busy["plague"] = true
	var ticks: int = int(PLAGUE_DURATION)
	for _t in ticks:
		for u in get_tree().get_nodes_in_group("combat_units"):
			if not is_instance_valid(u) or u.is_in_group("player_units"):
				continue
			if u.has_method("take_damage"):
				u.take_damage(PLAGUE_DPS)
				if u is Node2D:
					Particles.spawn((u as Node2D).get_parent(), "death_burst", (u as Node2D).global_position)
		await get_tree().create_timer(1.0).timeout
	_busy["plague"] = false

func _cast_devour() -> void:
	if _busy.get("devour", false):
		return
	_busy["devour"] = true
	var combats: Array = []
	for u in get_tree().get_nodes_in_group("player_units"):
		if not is_instance_valid(u):
			continue
		var stat: Node = u.get_node_or_null("StatComponent")
		if stat != null and stat.has_method("heal"):
			stat.heal(DEVOUR_HEAL)
		var cc: Node = u.get_node_or_null("CombatComponent")
		if cc != null:
			cc.set("attack_cooldown", float(cc.get("attack_cooldown")) / DEVOUR_ATK_MULT)
			combats.append(cc)
	await get_tree().create_timer(DEVOUR_DURATION).timeout
	for cc in combats:
		if is_instance_valid(cc):
			cc.set("attack_cooldown", float(cc.get("attack_cooldown")) * DEVOUR_ATK_MULT)
	_busy["devour"] = false

# ── Ix ─────────────────────────────────────────────────
func _cast_armor_buff(amount: float, duration: float) -> void:
	if _busy.get("armor", false):
		return
	_busy["armor"] = true
	var buffed: Array[StatComponent] = []
	for u in get_tree().get_nodes_in_group("player_units"):
		if not is_instance_valid(u):
			continue
		var stat: StatComponent = u.get_node_or_null("StatComponent") as StatComponent
		if stat != null:
			stat.armor += amount
			buffed.append(stat)
	await get_tree().create_timer(duration).timeout
	for stat in buffed:
		if is_instance_valid(stat):
			stat.armor -= amount
	_busy["armor"] = false

func _cast_aegis() -> void:
	for b in get_tree().get_nodes_in_group("player_buildings"):
		if is_instance_valid(b) and b.has_method("apply_shield"):
			b.apply_shield(AEGIS_REDUCTION, AEGIS_DURATION)
			if b is Node2D:
				Particles.spawn((b as Node2D).get_parent(), "selection_pulse", (b as Node2D).global_position)

func _cast_energize() -> void:
	var pf: int = GameSettings.player_faction_id
	ResourceManager.add_resource("madera", 150, pf)
	ResourceManager.add_resource("oro", 120, pf)
	ResourceManager.add_resource("comida", 90, pf)

func _find_player_tc() -> Node2D:
	for b in get_tree().get_nodes_in_group("player_buildings"):
		if is_instance_valid(b) and b is Node2D and String(b.get("building_name")) == "Town Center":
			return b as Node2D
	return null
