extends Control

## Skirmish setup screen. All UI is built in code (no external theme files).
## Start writes the player's choices to GameSettings, runs the standard match
## reset sequence (so EnemyAI.reset() applies the chosen difficulty), then loads
## the World. Back returns to the main menu.

const WORLD_SCENE: String = "res://scenes/world/World.tscn"
const MAIN_MENU_SCENE: String = "res://scenes/ui/MainMenu.tscn"

const BG_COLOR: Color = Color(0.08, 0.1, 0.12, 1.0)
const ACCENT_COLOR: Color = Color(0.0, 0.85, 0.85, 1.0)
const PANEL_COLOR: Color = Color(0.12, 0.15, 0.18, 1.0)
const TEXT_COLOR: Color = Color(0.92, 0.95, 0.98, 1.0)

# Index -> data string. Order must match the OptionButton item order below.
const DIFFICULTY_KEYS: Array[String] = ["easy", "normal", "hard"]
const FACTION_KEYS: Array[String] = ["itzal", "ix"]
const FACTION_PLAYER_IDS: Array[int] = [0, 2]  # player_faction_id per faction option
const MAP_KEY: String = "jungle_basin"

const DIFFICULTY_DEFAULT: int = 1  # "normal"

var _map_option: OptionButton = null
var _difficulty_option: OptionButton = null
var _faction_option: OptionButton = null

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = BG_COLOR
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_preset(Control.PRESET_FULL_RECT)

	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(360, 0)
	vbox.add_theme_constant_override("separation", 16)
	center.add_child(vbox)

	var title := Label.new()
	title.text = "SKIRMISH"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", TEXT_COLOR)
	title.add_theme_font_size_override("font_size", 48)
	vbox.add_child(title)

	vbox.add_child(_make_caption("MAP"))
	_map_option = _make_option()
	_map_option.add_item("Jungle Basin")
	_map_option.add_item("Highland Ruins")
	_map_option.add_item("Ash Delta")
	_map_option.set_item_disabled(1, true)
	_map_option.set_item_disabled(2, true)
	_map_option.select(0)
	vbox.add_child(_map_option)

	vbox.add_child(_make_caption("DIFFICULTY"))
	_difficulty_option = _make_option()
	_difficulty_option.add_item("Easy")
	_difficulty_option.add_item("Normal")
	_difficulty_option.add_item("Hard")
	_difficulty_option.select(DIFFICULTY_DEFAULT)
	vbox.add_child(_difficulty_option)

	vbox.add_child(_make_caption("FACTION"))
	_faction_option = _make_option()
	_faction_option.add_item("Itzal")
	_faction_option.add_item("Ix Architects")
	_faction_option.select(0)
	vbox.add_child(_faction_option)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 12)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(spacer)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 12)
	vbox.add_child(buttons)

	var start_btn := _make_button("START")
	start_btn.pressed.connect(_on_start)
	buttons.add_child(start_btn)

	var back_btn := _make_button("BACK")
	back_btn.pressed.connect(_on_back)
	buttons.add_child(back_btn)

func _make_caption(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", TEXT_COLOR)
	label.add_theme_font_size_override("font_size", 13)
	return label

func _make_option() -> OptionButton:
	var opt := OptionButton.new()
	opt.custom_minimum_size = Vector2(0, 36)
	opt.add_theme_color_override("font_color", TEXT_COLOR)
	opt.add_theme_color_override("font_hover_color", ACCENT_COLOR)
	opt.add_theme_color_override("font_focus_color", TEXT_COLOR)
	opt.add_theme_stylebox_override("normal", _panel_style(false))
	opt.add_theme_stylebox_override("hover", _panel_style(true))
	opt.add_theme_stylebox_override("pressed", _panel_style(true))
	opt.add_theme_stylebox_override("focus", _panel_style(true))
	return opt

func _make_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(120, 40)
	btn.add_theme_color_override("font_color", TEXT_COLOR)
	btn.add_theme_color_override("font_hover_color", ACCENT_COLOR)
	btn.add_theme_color_override("font_focus_color", ACCENT_COLOR)
	btn.add_theme_color_override("font_pressed_color", ACCENT_COLOR)
	btn.add_theme_stylebox_override("normal", _panel_style(false))
	btn.add_theme_stylebox_override("hover", _panel_style(true))
	btn.add_theme_stylebox_override("pressed", _panel_style(true))
	btn.add_theme_stylebox_override("focus", _panel_style(true))
	return btn

func _panel_style(accent: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL_COLOR
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 14.0
	sb.content_margin_right = 14.0
	sb.content_margin_top = 6.0
	sb.content_margin_bottom = 6.0
	if accent:
		sb.set_border_width_all(1)
		sb.border_color = ACCENT_COLOR
	return sb

func _on_start() -> void:
	GameSettings.difficulty = DIFFICULTY_KEYS[_difficulty_option.selected]
	GameSettings.faction = FACTION_KEYS[_faction_option.selected]
	GameSettings.player_faction_id = FACTION_PLAYER_IDS[_faction_option.selected]
	GameSettings.map = MAP_KEY
	ResourceManager.reset()
	SelectionManager.clear()
	SelectionManager.deselect_building()
	BuildingPlacer.cancel_placement()
	EnemyAI.reset()
	GameStats.reset()
	get_tree().change_scene_to_file(WORLD_SCENE)

func _on_back() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
