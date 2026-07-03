extends CanvasLayer

const POLL_INTERVAL: float = 1.0
const ALERT_SLOTS: int = 5
const PULSE_COOLDOWN: float = 2.0
const PULSE_COLOR: Color = Color(0.85, 0.2, 0.15, 1.0)

@onready var wood_label: Label = $ResBlock/VBox/Wood/Label
@onready var food_label: Label = $ResBlock/VBox/Food/Label
@onready var gold_label: Label = $ResBlock/VBox/Gold/Label
@onready var wood_workers: Label = $ResBlock/VBox/Wood/Workers
@onready var food_workers: Label = $ResBlock/VBox/Food/Workers
@onready var gold_workers: Label = $ResBlock/VBox/Gold/Workers
@onready var pop_label: Label = $ResBlock/VBox/PopRow/Label
@onready var era_label: Label = $EraCenter
@onready var clock_label: Label = $Clock
@onready var idle_btn: Button = $ResBlock/VBox/PopRow/IdleBtn
@onready var _alert_box: VBoxContainer = $AlertPanel/VBox

const ERA_ROMAN: Array[String] = ["I", "II", "III"]

var _poll_timer: float = 0.0
var _alert_labels: Array[Label] = []
var _pulse_overlay: ColorRect = null
var _pulse_cooldown: float = 0.0

func _ready() -> void:
	($ResBlock as PanelContainer).add_theme_stylebox_override("panel", MenuKit.family_box(8.0))
	($ResBlock/VBox as VBoxContainer).add_theme_constant_override("separation", 2)
	for l: Label in [pop_label, food_label, wood_label, gold_label]:
		l.add_theme_font_size_override("font_size", 14)
	# Painted resource icons (art pack 2).
	for pair in [["PopRow", "res_pop"], ["Food", "res_food"], ["Wood", "res_wood"], ["Gold", "res_gold"]]:
		var tr: TextureRect = get_node_or_null("ResBlock/VBox/%s/Icon" % pair[0]) as TextureRect
		var p: String = "res://assets/ui/icons/%s.png" % pair[1]
		if tr != null and ResourceLoader.exists(p):
			tr.texture = load(p)
			tr.custom_minimum_size = Vector2(24, 24)
	# Hug the ledger's content — no dead plate under the gold row.
	($ResBlock as Control).offset_top = -136.0
	# Right-align the numbers so the column reads as a ledger; hairline
	# separator between population and the resource rows.
	for l: Label in [pop_label, food_label, wood_label, gold_label]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var vbox: VBoxContainer = $ResBlock/VBox
	var sepline := ColorRect.new()
	sepline.color = Color(0.0, 0.85, 0.85, 0.12)
	sepline.custom_minimum_size = Vector2(0, 1)
	vbox.add_child(sepline)
	vbox.move_child(sepline, 1)
	# Era numeral: gold, spaced — a small ceremonial marker, not a system label.
	if era_label != null:
		era_label.add_theme_color_override("font_color", Color(0.784, 0.663, 0.29, 0.95))
		var efv := FontVariation.new()
		efv.spacing_glyph = 3
		era_label.add_theme_font_override("font", efv)
	ResourceManager.resource_changed.connect(_on_resource_changed)
	SelectionManager.selection_changed.connect(_on_selection_changed)
	AlertManager.alert_pushed.connect(_on_alert_pushed)
	AlertManager.alert_cleared.connect(_on_alert_cleared)
	ResourceManager.supply_changed.connect(func(_fid: int, _u: int, _c: int) -> void: _update_population())
	idle_btn.pressed.connect(func() -> void: SelectionManager.cycle_idle_villager())
	_build_ticker()
	_build_deal_modal()
	_build_beacon_panel()
	AlertManager.ticker_updated.connect(_on_ticker)
	AlertManager.alert_pushed.connect(func(text: String, _lvl: String) -> void: _on_ticker(text))
	AlertManager.deal_offered.connect(_on_deal_offered)
	AlertManager.deal_resolved.connect(func(_id: StringName, _ok: bool) -> void: _deal_modal.visible = false)
	_build_pulse_overlay()
	for i in range(ALERT_SLOTS):
		var lbl: Label = _alert_box.get_node_or_null("Alert%d" % i) as Label
		if lbl != null:
			_alert_labels.append(lbl)
	_refresh()
	_update_population()
	_update_era()
	_refresh_alerts()

func _process(delta: float) -> void:
	_poll_timer += delta
	if _poll_timer >= POLL_INTERVAL:
		_poll_timer = 0.0
		_update_population()
		_update_era()
		_update_workers()
		_update_beacon_panel()
		if clock_label != null:
			clock_label.text = GameStats.format_time()
	if _pulse_cooldown > 0.0:
		_pulse_cooldown -= delta
	_tick_ticker(delta)

## Full-screen red tint that blinks when the base is threatened. Sits behind
## the rest of the HUD and ignores mouse input.
func _build_pulse_overlay() -> void:
	_pulse_overlay = ColorRect.new()
	_pulse_overlay.color = Color(PULSE_COLOR.r, PULSE_COLOR.g, PULSE_COLOR.b, 0.0)
	_pulse_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_pulse_overlay)
	move_child(_pulse_overlay, 0)
	_pulse_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _pulse_screen() -> void:
	if _pulse_overlay == null or _pulse_cooldown > 0.0:
		return
	_pulse_cooldown = PULSE_COOLDOWN
	var tween := create_tween()
	tween.tween_property(_pulse_overlay, "color:a", 0.16, 0.2)
	tween.tween_property(_pulse_overlay, "color:a", 0.0, 0.4)

func _on_resource_changed(_type: StringName, _new_amount: int) -> void:
	_refresh()

func _on_selection_changed(_units: Array) -> void:
	_update_population()

func _refresh() -> void:
	var pf: int = GameSettings.player_faction_id
	wood_label.text = str(ResourceManager.get_resource(ResourceManager.WOOD, pf))
	food_label.text = str(ResourceManager.get_resource(ResourceManager.FOOD, pf))
	gold_label.text = str(ResourceManager.get_resource(ResourceManager.GOLD, pf))

func _update_era() -> void:
	if era_label == null:
		return
	var e: int = clampi(GameStats.era, 1, ERA_ROMAN.size())
	era_label.text = ERA_ROMAN[e - 1]   # AoE4-style big numeral, top-centre

## AoE4-signature economy readout: workers currently gathering each resource
## plus the idle-worker count on the cycle button.
func _update_workers() -> void:
	var counts: Dictionary = {&"wood": 0, &"food": 0, &"gold": 0}
	var idle: int = 0
	for u in get_tree().get_nodes_in_group("villagers"):
		if not (is_instance_valid(u) and u.is_in_group("player_units")):
			continue
		var t: StringName = &""
		if u.has_method("current_resource_type"):
			t = u.current_resource_type()
		if t == &"":
			idle += 1
		elif counts.has(t):
			counts[t] = int(counts[t]) + 1
	wood_workers.text = str(counts[&"wood"]) if int(counts[&"wood"]) > 0 else ""
	food_workers.text = str(counts[&"food"]) if int(counts[&"food"]) > 0 else ""
	gold_workers.text = str(counts[&"gold"]) if int(counts[&"gold"]) > 0 else ""
	idle_btn.text = "◉ %d" % idle

func _update_population() -> void:
	var fid: int = GameSettings.player_faction_id
	var used: int = ResourceManager.get_supply_used(fid)
	var cap: int = ResourceManager.get_supply_cap(fid)
	# The Pop icon already carries the meaning — no emoji duplication.
	pop_label.text = "%d/%d" % [used, cap]
	var col: Color = Color(1, 1, 1, 1)
	if used >= cap:
		col = Color(1.0, 0.33, 0.22, 1)  # capped — build an Obsidian Pylon
	pop_label.add_theme_color_override("font_color", col)

func _on_alert_pushed(_text: String, level: String) -> void:
	_refresh_alerts()
	if level == "warning" or level == "error":
		_pulse_screen()

func _on_alert_cleared(_index: int) -> void:
	_refresh_alerts()

func _refresh_alerts() -> void:
	var alerts: Array = AlertManager.get_alerts()
	for i in range(_alert_labels.size()):
		var lbl: Label = _alert_labels[i]
		if i < alerts.size():
			var a: Dictionary = alerts[i]
			lbl.text = String(a.get("text", ""))
			lbl.add_theme_color_override("font_color", _alert_color(String(a.get("level", "info"))))
			lbl.show()
		else:
			lbl.hide()

func _alert_color(level: String) -> Color:
	match level:
		"error":
			return Color(1.0, 0.33, 0.22, 1)
		"warning":
			return Color(0.94, 0.75, 0.1, 1)
		_:
			return Color(0.7, 0.9, 0.7, 1)

# ── Event ticker + Deals UI (data from AlertManager) ───────
const TICKER_BG: Color = Color(0.106, 0.129, 0.188, 0.92)   # panel basalt
const TICKER_TEXT: Color = Color(0.0, 0.85, 0.85, 1.0)      # accent cyan
const TICKER_LIFETIME: float = 8.0

var _ticker_label: Label = null
var _ticker_left: float = 0.0
var _deal_modal: PanelContainer = null
var _deal_text: Label = null
var _deal_countdown: Label = null

## Slim strip across the bottom, just above the build bar.
func _build_ticker() -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", MenuKit.chip_box(4.0))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	# Top-centre, under the era numeral (AoE4 events position).
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	panel.offset_left = 560.0
	panel.offset_right = -560.0
	panel.offset_top = 44.0
	panel.offset_bottom = 68.0
	_ticker_label = Label.new()
	_ticker_label.add_theme_color_override("font_color", TICKER_TEXT)
	_ticker_label.add_theme_font_size_override("font_size", 13)
	_ticker_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ticker_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	panel.add_child(_ticker_label)
	panel.visible = false

func _on_ticker(text: String) -> void:
	if _ticker_label == null:
		return
	_ticker_label.text = text
	_ticker_left = TICKER_LIFETIME
	(_ticker_label.get_parent() as Control).visible = true

## Centered offer card with Accept / Decline and a live countdown.
func _build_deal_modal() -> void:
	_deal_modal = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.08, 0.12, 0.97)
	sb.set_corner_radius_all(6)
	sb.set_border_width_all(1)
	sb.border_color = Color(0.0, 0.85, 0.85, 0.55)
	sb.set_content_margin_all(18)
	_deal_modal.add_theme_stylebox_override("panel", sb)
	add_child(_deal_modal)
	_deal_modal.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_deal_modal.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_deal_modal.grow_vertical = Control.GROW_DIRECTION_BOTH
	_deal_modal.custom_minimum_size = Vector2(420, 0)
	_deal_modal.visible = false

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	_deal_modal.add_child(v)

	var title := Label.new()
	title.text = "INCOMING DEAL"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", TICKER_TEXT)
	title.add_theme_font_size_override("font_size", 16)
	v.add_child(title)

	_deal_text = Label.new()
	_deal_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_deal_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_deal_text.add_theme_color_override("font_color", Color(0.92, 0.95, 0.98, 1))
	_deal_text.add_theme_font_size_override("font_size", 14)
	v.add_child(_deal_text)

	_deal_countdown = Label.new()
	_deal_countdown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_deal_countdown.add_theme_color_override("font_color", Color(0.55, 0.62, 0.68, 1))
	_deal_countdown.add_theme_font_size_override("font_size", 12)
	v.add_child(_deal_countdown)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	v.add_child(row)
	row.add_child(_deal_button("Accept", Color(0.2, 0.85, 0.5), func() -> void: AlertManager.resolve_deal(true)))
	row.add_child(_deal_button("Decline", Color(0.9, 0.35, 0.3), func() -> void: AlertManager.resolve_deal(false)))

func _deal_button(text: String, color: Color, on_press: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(120, 34)
	btn.add_theme_color_override("font_color", color)
	btn.add_theme_color_override("font_hover_color", Color(0.95, 0.97, 0.98, 1))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.13, 0.17, 0.95)
	sb.set_corner_radius_all(4)
	sb.set_border_width_all(1)
	sb.border_color = Color(color.r, color.g, color.b, 0.6)
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb)
	btn.pressed.connect(on_press)
	return btn

func _on_deal_offered(deal: Dictionary) -> void:
	_deal_text.text = String(deal.get("text", ""))
	_deal_modal.visible = true

func _tick_ticker(delta: float) -> void:
	if _ticker_left > 0.0:
		_ticker_left -= delta
		if _ticker_left <= 0.0 and _ticker_label != null:
			(_ticker_label.get_parent() as Control).visible = false
	if _deal_modal != null and _deal_modal.visible:
		_deal_countdown.text = "Expires in %ds" % int(ceil(AlertManager.get_deal_time_left()))

# ── Ascension Beacon charge panel (right side; hidden until a beacon exists) ──
var _beacon_panel: PanelContainer = null
var _beacon_box: VBoxContainer = null

func _build_beacon_panel() -> void:
	_beacon_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.106, 0.129, 0.188, 0.92)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(10)
	_beacon_panel.add_theme_stylebox_override("panel", sb)
	_beacon_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_beacon_panel)
	_beacon_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	_beacon_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_beacon_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_beacon_panel.offset_right = -10.0
	_beacon_panel.custom_minimum_size = Vector2(190, 0)
	_beacon_box = VBoxContainer.new()
	_beacon_box.add_theme_constant_override("separation", 6)
	_beacon_panel.add_child(_beacon_box)
	_beacon_panel.visible = false

## Rebuilt each tick from the "beacons" group — one bar per beacon, tinted with
## its faction colour; label notes PAUSED while damage is stalling the charge.
func _update_beacon_panel() -> void:
	if _beacon_panel == null:
		return
	var beacons: Array = get_tree().get_nodes_in_group("beacons")
	beacons = beacons.filter(func(b) -> bool:
		return is_instance_valid(b) and not bool(b.get("dying")) and not bool(b.get("under_construction")))
	_beacon_panel.visible = not beacons.is_empty()
	if beacons.is_empty():
		return
	for c in _beacon_box.get_children():
		c.queue_free()
	var title := Label.new()
	title.text = "ASCENSION"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(0.0, 0.85, 0.85, 1.0))
	title.add_theme_font_size_override("font_size", 13)
	_beacon_box.add_child(title)
	for b in beacons:
		var fac: FactionData = FactionManager.get_faction(int(b.get("faction_id")))
		var col: Color = fac.primary_color if fac != null else Color.WHITE
		var row := Label.new()
		var paused: bool = bool(b.is_charge_paused())
		row.text = "%s %d%%%s" % [fac.display_name if fac != null else "?",
			int(b.get_charge_ratio() * 100.0), "  (PAUSED)" if paused else ""]
		row.add_theme_color_override("font_color", col)
		row.add_theme_font_size_override("font_size", 12)
		_beacon_box.add_child(row)
		var bar := ProgressBar.new()
		bar.min_value = 0.0
		bar.max_value = 1.0
		bar.value = b.get_charge_ratio()
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 10)
		var fill := StyleBoxFlat.new()
		fill.bg_color = col
		fill.set_corner_radius_all(2)
		var track := StyleBoxFlat.new()
		track.bg_color = Color(0.05, 0.07, 0.10, 1.0)
		track.set_corner_radius_all(2)
		bar.add_theme_stylebox_override("fill", fill)
		bar.add_theme_stylebox_override("background", track)
		_beacon_box.add_child(bar)
