extends Control

## Settings — volume sliders + fullscreen toggle over a dimmed background.
## UI is built in code (project convention); SettingsMenu.tscn holds the root
## Control + the BGImage TextureRect. Values live-apply through GameSettings
## and persist to user://settings.cfg on BACK.

const MAIN_MENU_SCENE: String = "res://scenes/ui/MainMenu.tscn"
const BG_IMAGE: String = "res://assets/ui/skirmish_bg.png"

const ACCENT: Color = Color(0.0, 0.90, 0.78, 1.0)
const PANEL_BG: Color = Color(0.04, 0.07, 0.11, 0.82)
const PANEL_BORDER: Color = Color(0.0, 0.90, 0.78, 0.35)
const TEXT_MUTED: Color = Color(0.7, 0.75, 0.8, 1.0)
const WHITE: Color = Color(0.95, 0.97, 0.98, 1.0)

var _master_value: Label = null
var _sfx_value: Label = null
var _music_value: Label = null

@onready var _bg: TextureRect = $BGImage

func _ready() -> void:
	if _bg != null and ResourceLoader.exists(BG_IMAGE):
		_bg.texture = load(BG_IMAGE)
	_build_title()
	_build_panel()
	_build_bottom_bar()

func _build_title() -> void:
	var title := Label.new()
	title.text = "SETTINGS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", ACCENT)
	title.add_theme_font_size_override("font_size", 52)
	title.add_theme_font_override("font", _spaced_font(8))
	add_child(title)
	title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 16
	title.offset_bottom = 84

func _build_panel() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL_BG
	sb.set_corner_radius_all(4)
	sb.set_border_width_all(1)
	sb.border_color = PANEL_BORDER
	sb.set_content_margin_all(24)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", sb)
	panel.custom_minimum_size = Vector2(480, 0)
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	panel.add_child(v)

	v.add_child(_header("AUDIO"))
	var master_row := _slider_row("Master Volume", GameSettings.master_volume, _on_master_changed)
	_master_value = master_row.get_meta("value_label") as Label
	v.add_child(master_row)
	var sfx_row := _slider_row("SFX Volume", GameSettings.sfx_volume, _on_sfx_changed)
	_sfx_value = sfx_row.get_meta("value_label") as Label
	var sfx_slider := sfx_row.get_meta("slider") as HSlider
	sfx_slider.drag_ended.connect(_on_sfx_drag_ended)
	v.add_child(sfx_row)
	var music_row := _slider_row("Music Volume", GameSettings.music_volume, _on_music_changed)
	_music_value = music_row.get_meta("value_label") as Label
	v.add_child(music_row)

	v.add_child(_header("DISPLAY"))
	var fs := CheckButton.new()
	fs.text = "Fullscreen"
	fs.button_pressed = GameSettings.fullscreen
	fs.add_theme_color_override("font_color", WHITE)
	fs.add_theme_font_size_override("font_size", 14)
	fs.toggled.connect(_on_fullscreen_toggled)
	v.add_child(fs)

func _slider_row(label_text: String, value: float, handler: Callable) -> VBoxContainer:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 4)

	var top := HBoxContainer.new()
	var l := Label.new()
	l.text = label_text
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.add_theme_color_override("font_color", WHITE)
	l.add_theme_font_size_override("font_size", 14)
	top.add_child(l)
	var val := Label.new()
	val.text = "%d%%" % int(round(value * 100.0))
	val.add_theme_color_override("font_color", TEXT_MUTED)
	val.add_theme_font_size_override("font_size", 14)
	top.add_child(val)
	row.add_child(top)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = value
	slider.custom_minimum_size = Vector2(0, 24)
	slider.value_changed.connect(handler)
	row.add_child(slider)

	row.set_meta("value_label", val)
	row.set_meta("slider", slider)
	return row

func _on_master_changed(value: float) -> void:
	GameSettings.master_volume = value
	GameSettings.apply_settings()
	if _master_value != null:
		_master_value.text = "%d%%" % int(round(value * 100.0))

func _on_sfx_changed(value: float) -> void:
	GameSettings.sfx_volume = value
	GameSettings.apply_settings()
	if _sfx_value != null:
		_sfx_value.text = "%d%%" % int(round(value * 100.0))

func _on_sfx_drag_ended(_changed: bool) -> void:
	SoundManager.play("unit_select")

func _on_music_changed(value: float) -> void:
	GameSettings.music_volume = value
	GameSettings.apply_settings()
	if _music_value != null:
		_music_value.text = "%d%%" % int(round(value * 100.0))

func _on_fullscreen_toggled(pressed: bool) -> void:
	GameSettings.fullscreen = pressed
	GameSettings.apply_settings()

func _build_bottom_bar() -> void:
	var back := Button.new()
	back.text = "BACK"
	back.custom_minimum_size = Vector2(140, 44)
	back.add_theme_color_override("font_color", TEXT_MUTED)
	back.add_theme_color_override("font_hover_color", ACCENT)
	back.add_theme_font_size_override("font_size", 16)
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL_BG
	sb.set_corner_radius_all(4)
	sb.set_border_width_all(1)
	sb.border_color = PANEL_BORDER
	back.add_theme_stylebox_override("normal", sb)
	back.pressed.connect(_on_back_pressed)
	add_child(back)
	back.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	back.offset_top = -76.0
	back.offset_bottom = -32.0
	back.offset_left = -70.0
	back.offset_right = 70.0

func _on_back_pressed() -> void:
	GameSettings.save_settings()
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)

func _header(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", ACCENT)
	l.add_theme_font_size_override("font_size", 11)
	l.add_theme_font_override("font", _spaced_font(3))
	return l

func _spaced_font(spacing: int) -> FontVariation:
	var fv := FontVariation.new()
	fv.spacing_glyph = spacing
	return fv
