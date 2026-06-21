extends Control

## Campaign mission select. Missions unlock in order (each playable once the
## previous is cleared, per ProfileManager). UI built in code over the dimmed
## skirmish backdrop. Picking a mission hands off to MissionLoader.

const MAIN_MENU_SCENE: String = "res://scenes/ui/MainMenu.tscn"
const BG_IMAGE: String = "res://assets/ui/menu_bg.png"

const ACCENT: Color = Color(0.0, 0.90, 0.78, 1.0)
const PANEL_BG: Color = Color(0.04, 0.07, 0.11, 0.82)
const PANEL_BORDER: Color = Color(0.0, 0.90, 0.78, 0.35)
const WHITE: Color = Color(0.95, 0.97, 0.98, 1.0)
const MUTED: Color = Color(0.55, 0.62, 0.68, 1.0)
const LOCKED: Color = Color(0.4, 0.43, 0.47, 1.0)

@onready var _bg: TextureRect = $BGImage

func _ready() -> void:
	if _bg != null and ResourceLoader.exists(BG_IMAGE):
		_bg.texture = load(BG_IMAGE)
	_build_title()
	_build_list()
	_build_back()
	SoundManager.start_menu_music()

func _build_title() -> void:
	var title := Label.new()
	title.text = "CAMPAIGN"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", ACCENT)
	title.add_theme_font_size_override("font_size", 52)
	add_child(title)
	title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 24
	title.offset_bottom = 92

func _build_list() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL_BG
	sb.set_corner_radius_all(4)
	sb.set_border_width_all(1)
	sb.border_color = PANEL_BORDER
	sb.set_content_margin_all(20)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", sb)
	panel.custom_minimum_size = Vector2(560, 0)
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)

	# Always-available tutorial entry at the top.
	v.add_child(_tutorial_row())

	var prev_cleared: bool = true  # first mission is always available
	for m in MissionConfig.MISSIONS:
		var mid: String = String(m.get("id", ""))
		var cleared: bool = ProfileManager.is_mission_cleared(mid)
		var unlocked: bool = prev_cleared
		v.add_child(_mission_row(m, unlocked, cleared))
		prev_cleared = cleared

func _mission_row(m: Dictionary, unlocked: bool, cleared: bool) -> Button:
	var btn := Button.new()
	var tag: String = "  ✓" if cleared else ("" if unlocked else "  (locked)")
	btn.text = "%s — %s%s" % [String(m.get("name", "")), _short(String(m.get("map", ""))), tag]
	btn.tooltip_text = String(m.get("intro", ""))
	btn.custom_minimum_size = Vector2(0, 44)
	btn.disabled = not unlocked
	btn.add_theme_color_override("font_color", WHITE if unlocked else LOCKED)
	btn.add_theme_color_override("font_hover_color", ACCENT)
	btn.add_theme_color_override("font_disabled_color", LOCKED)
	var nb := StyleBoxFlat.new()
	nb.bg_color = Color(0.10, 0.13, 0.17, 0.9)
	nb.set_corner_radius_all(3)
	nb.set_border_width_all(1)
	nb.border_color = PANEL_BORDER if unlocked else Color(0.25, 0.28, 0.32, 0.5)
	nb.set_content_margin_all(8)
	btn.add_theme_stylebox_override("normal", nb)
	btn.add_theme_stylebox_override("hover", nb)
	btn.add_theme_stylebox_override("disabled", nb)
	if unlocked:
		var mid: String = String(m.get("id", ""))
		btn.pressed.connect(func() -> void: MissionLoader.start(mid))
	return btn

func _tutorial_row() -> Button:
	var btn := Button.new()
	btn.text = "▶  Tutorial — learn the basics"
	btn.custom_minimum_size = Vector2(0, 44)
	btn.add_theme_color_override("font_color", ACCENT)
	btn.add_theme_color_override("font_hover_color", WHITE)
	var nb := StyleBoxFlat.new()
	nb.bg_color = Color(0.10, 0.13, 0.17, 0.9)
	nb.set_corner_radius_all(3)
	nb.set_border_width_all(1)
	nb.border_color = PANEL_BORDER
	nb.set_content_margin_all(8)
	btn.add_theme_stylebox_override("normal", nb)
	btn.add_theme_stylebox_override("hover", nb)
	btn.pressed.connect(func() -> void: MissionLoader.start_tutorial())
	return btn

func _short(map_name: String) -> String:
	return map_name

func _build_back() -> void:
	var back := Button.new()
	back.text = "BACK"
	back.custom_minimum_size = Vector2(140, 44)
	back.add_theme_color_override("font_color", MUTED)
	back.add_theme_color_override("font_hover_color", ACCENT)
	back.add_theme_font_size_override("font_size", 16)
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL_BG
	sb.set_corner_radius_all(4)
	sb.set_border_width_all(1)
	sb.border_color = PANEL_BORDER
	back.add_theme_stylebox_override("normal", sb)
	back.pressed.connect(func() -> void: get_tree().change_scene_to_file(MAIN_MENU_SCENE))
	add_child(back)
	back.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	back.offset_top = -76.0
	back.offset_bottom = -32.0
	back.offset_left = -70.0
	back.offset_right = 70.0
