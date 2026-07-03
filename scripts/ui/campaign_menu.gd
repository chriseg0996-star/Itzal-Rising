extends Control

## Campaign mission select — minimalist left column on the shared MenuKit
## language. Missions unlock in order (ProfileManager); picking one hands off
## to MissionLoader.

const MAIN_MENU_SCENE: String = "res://scenes/ui/MainMenu.tscn"

func _ready() -> void:
	MenuKit.build_background(self)
	MenuKit.build_header(self, "CAMPAIGN")
	_build_list()
	MenuKit.build_back(self, func() -> void: get_tree().change_scene_to_file(MAIN_MENU_SCENE))
	MenuKit.build_version(self)
	SoundManager.start_menu_music()

func _build_list() -> void:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	add_child(v)
	v.anchor_left = MenuKit.MENU_X
	v.anchor_right = 0.55
	v.anchor_top = 0.24
	v.anchor_bottom = 0.86

	var tut := MenuKit.item("TUTORIAL  —  learn the basics", MenuKit.ACCENT,
		func() -> void: MissionLoader.start_tutorial(), 17)
	v.add_child(tut)

	v.add_child(_spacer(10))
	v.add_child(MenuKit.section("M I S S I O N S"))
	v.add_child(_spacer(2))

	var prev_cleared: bool = true
	var idx: int = 0
	for m in MissionConfig.MISSIONS:
		idx += 1
		var mid: String = String(m.get("id", ""))
		var cleared: bool = ProfileManager.is_mission_cleared(mid)
		var unlocked: bool = prev_cleared
		v.add_child(_mission_item(idx, m, unlocked, cleared))
		prev_cleared = cleared

func _mission_item(idx: int, m: Dictionary, unlocked: bool, cleared: bool) -> Button:
	var name_str: String = String(m.get("name", ""))
	var map_str: String = String(m.get("map", ""))
	var text: String = "%02d   %s  ·  %s" % [idx, name_str.to_upper(), map_str]
	if cleared:
		text += "   ✓"
	elif not unlocked:
		text += "   ⋯"
	var col: Color = MenuKit.WHITE
	if cleared:
		col = MenuKit.ACCENT
	elif not unlocked:
		col = MenuKit.DISABLED
	var mid: String = String(m.get("id", ""))
	var cb: Callable = func() -> void: pass
	if unlocked:
		cb = func() -> void: MissionLoader.start(mid)
	var btn := MenuKit.item(text, col, cb, 18)
	btn.tooltip_text = String(m.get("intro", ""))
	if not unlocked:
		btn.add_theme_color_override("font_hover_color", MenuKit.DISABLED)
	return btn

func _spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c
