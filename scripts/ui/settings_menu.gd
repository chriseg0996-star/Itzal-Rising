extends Control

## Settings — minimalist left column on the shared MenuKit language. Values
## live-apply through GameSettings and persist to user://settings.cfg on BACK.

const MAIN_MENU_SCENE: String = "res://scenes/ui/MainMenu.tscn"

var _master_value: Label = null
var _sfx_value: Label = null
var _music_value: Label = null

func _ready() -> void:
	MenuKit.build_background(self)
	MenuKit.build_header(self, "SETTINGS")
	_build_column()
	MenuKit.build_back(self, _on_back_pressed)
	MenuKit.build_version(self)
	SoundManager.start_menu_music()

func _build_column() -> void:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	add_child(v)
	v.anchor_left = MenuKit.MENU_X
	v.anchor_right = 0.44
	v.anchor_top = 0.24
	v.anchor_bottom = 0.86

	v.add_child(MenuKit.section("A U D I O"))
	var master_row := _slider_row("Master Volume", GameSettings.master_volume, _on_master_changed)
	_master_value = master_row.get_meta("value_label") as Label
	v.add_child(master_row)
	var sfx_row := _slider_row("SFX Volume", GameSettings.sfx_volume, _on_sfx_changed)
	_sfx_value = sfx_row.get_meta("value_label") as Label
	(sfx_row.get_meta("slider") as HSlider).drag_ended.connect(_on_sfx_drag_ended)
	v.add_child(sfx_row)
	var music_row := _slider_row("Music Volume", GameSettings.music_volume, _on_music_changed)
	_music_value = music_row.get_meta("value_label") as Label
	v.add_child(music_row)

	v.add_child(_spacer(14))
	v.add_child(MenuKit.section("D I S P L A Y"))
	var fs := CheckButton.new()
	fs.text = "Fullscreen"
	fs.button_pressed = GameSettings.fullscreen
	fs.add_theme_color_override("font_color", MenuKit.WHITE)
	fs.add_theme_color_override("font_hover_color", MenuKit.ACCENT)
	fs.add_theme_font_size_override("font_size", 16)
	fs.toggled.connect(_on_fullscreen_toggled)
	v.add_child(fs)

## Label + % on one line, slim neon slider below.
func _slider_row(label_text: String, value: float, handler: Callable) -> VBoxContainer:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 4)

	var top := HBoxContainer.new()
	var l := Label.new()
	l.text = label_text
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.add_theme_color_override("font_color", MenuKit.WHITE)
	l.add_theme_font_size_override("font_size", 16)
	top.add_child(l)
	var val := Label.new()
	val.text = "%d%%" % int(round(value * 100.0))
	val.add_theme_color_override("font_color", MenuKit.MUTED)
	val.add_theme_font_size_override("font_size", 15)
	top.add_child(val)
	row.add_child(top)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = value
	slider.custom_minimum_size = Vector2(0, 22)
	# Slim neon styling: dark track, teal fill, small round grabber.
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.10, 0.13, 0.17, 1.0)
	track.set_corner_radius_all(2)
	track.content_margin_top = 3.0
	track.content_margin_bottom = 3.0
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(MenuKit.ACCENT.r, MenuKit.ACCENT.g, MenuKit.ACCENT.b, 0.85)
	fill.set_corner_radius_all(2)
	fill.content_margin_top = 3.0
	fill.content_margin_bottom = 3.0
	slider.add_theme_stylebox_override("slider", track)
	slider.add_theme_stylebox_override("grabber_area", fill)
	slider.add_theme_stylebox_override("grabber_area_highlight", fill)
	slider.value_changed.connect(handler)
	row.add_child(slider)

	row.set_meta("value_label", val)
	row.set_meta("slider", slider)
	return row

func _spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c

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

func _on_back_pressed() -> void:
	GameSettings.save_settings()
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
