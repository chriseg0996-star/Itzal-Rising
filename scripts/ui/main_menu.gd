extends Control

## Main menu, rebuilt from zero in code — no baked art. Pure "Basalt & Neon":
## deep slate gradient, a faint teal aurora behind the title, neon-ruled title
## block and a clean column of plate buttons in the same visual language as the
## Campaign screen (one identity across every menu).

const ACCENT: Color = Color(0.0, 0.90, 0.78, 1.0)
const BG_TOP: Color = Color(0.043, 0.055, 0.078, 1.0)
const BG_BOTTOM: Color = Color(0.075, 0.095, 0.13, 1.0)
const ROW_BG: Color = Color(0.10, 0.13, 0.17, 0.92)
const ROW_BORDER: Color = Color(0.0, 0.90, 0.78, 0.35)
const WHITE: Color = Color(0.92, 0.95, 0.98, 1.0)
const MUTED: Color = Color(0.55, 0.62, 0.68, 1.0)
const BTN_SIZE: Vector2 = Vector2(340, 52)

func _ready() -> void:
	_build_background()
	_build_title()
	_build_buttons()
	_build_version_label()
	SoundManager.start_menu_music()
	_maybe_offer_tutorial()

# ── Background: slate gradient + teal aurora + grid rule ──
func _build_background() -> void:
	var grad := TextureRect.new()
	var img := Image.create(8, 256, false, Image.FORMAT_RGBA8)
	for y in 256:
		var c: Color = BG_TOP.lerp(BG_BOTTOM, float(y) / 255.0)
		for x in 8:
			img.set_pixel(x, y, c)
	grad.texture = ImageTexture.create_from_image(img)
	grad.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	grad.stretch_mode = TextureRect.STRETCH_SCALE
	grad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(grad)
	grad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Faint teal aurora glow behind the title block.
	var glow := TextureRect.new()
	glow.texture = TextureGenerator.get_texture("soft_blob")
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.stretch_mode = TextureRect.STRETCH_SCALE
	glow.modulate = Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.07)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(glow)
	glow.anchor_left = 0.15
	glow.anchor_right = 0.85
	glow.anchor_top = -0.15
	glow.anchor_bottom = 0.55

func _build_title() -> void:
	var title := Label.new()
	title.text = "ITZAL RISING"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", ACCENT)
	title.add_theme_font_size_override("font_size", 78)
	title.add_theme_constant_override("shadow_offset_y", 4)
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	add_child(title)
	title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 96.0
	title.offset_bottom = 192.0

	var sub := Label.new()
	sub.text = "M E S O A M E R I C A N   S C I - F I   R T S"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_color_override("font_color", MUTED)
	sub.add_theme_font_size_override("font_size", 16)
	add_child(sub)
	sub.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	sub.offset_top = 196.0
	sub.offset_bottom = 224.0

	# Thin neon rule under the title block.
	var rule := ColorRect.new()
	rule.color = Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.5)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rule)
	rule.anchor_left = 0.36
	rule.anchor_right = 0.64
	rule.anchor_top = 0.0
	rule.anchor_bottom = 0.0
	rule.offset_top = 238.0
	rule.offset_bottom = 240.0

# ── Button column ──────────────────────────────────────────
func _build_buttons() -> void:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(v)
	v.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	v.grow_horizontal = Control.GROW_DIRECTION_BOTH
	v.grow_vertical = Control.GROW_DIRECTION_BOTH
	v.offset_top = 130.0
	v.offset_bottom = 130.0

	if SaveManager.has_save():
		v.add_child(_menu_button("CONTINUE", ACCENT, func() -> void: SaveManager.request_load()))
	v.add_child(_menu_button("START CAMPAIGN", WHITE, _on_campaign))
	v.add_child(_menu_button("SKIRMISH", WHITE, _on_skirmish))
	v.add_child(_mp_button())
	v.add_child(_menu_button("SETTINGS", WHITE, _on_settings))
	v.add_child(_menu_button("QUIT", Color(0.85, 0.45, 0.42, 1.0), _on_quit))

func _menu_button(text: String, font_col: Color, on_press: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = BTN_SIZE
	btn.add_theme_color_override("font_color", font_col)
	btn.add_theme_color_override("font_hover_color", ACCENT)
	btn.add_theme_font_size_override("font_size", 19)
	var sb := StyleBoxFlat.new()
	sb.bg_color = ROW_BG
	sb.set_corner_radius_all(4)
	sb.set_border_width_all(1)
	sb.border_color = ROW_BORDER
	var hb: StyleBoxFlat = sb.duplicate()
	hb.bg_color = Color(0.13, 0.17, 0.22, 0.95)
	hb.border_color = ACCENT
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", hb)
	btn.add_theme_stylebox_override("pressed", hb)
	btn.add_theme_stylebox_override("focus", hb)
	btn.pressed.connect(on_press)
	return btn

## Multiplayer is honest about not existing yet: dimmed row, muted tag, and the
## same explanatory popup on click.
func _mp_button() -> Button:
	var btn := _menu_button("MULTIPLAYER  ·  coming soon", Color(0.42, 0.47, 0.52, 1.0), _on_multiplayer)
	btn.add_theme_color_override("font_hover_color", Color(0.6, 0.65, 0.7, 1.0))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.09, 0.12, 0.85)
	sb.set_corner_radius_all(4)
	sb.set_border_width_all(1)
	sb.border_color = Color(0.25, 0.30, 0.35, 0.5)
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb)
	btn.add_theme_stylebox_override("pressed", sb)
	return btn

## Version string sourced from project.godot so it never drifts from the build.
func _build_version_label() -> void:
	var ver: String = String(ProjectSettings.get_setting("application/config/version", "1.0.0"))
	var lbl := Label.new()
	lbl.text = "v%s" % ver
	lbl.add_theme_color_override("font_color", Color(0.45, 0.55, 0.6, 0.8))
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(lbl)
	lbl.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	lbl.offset_left = -140.0
	lbl.offset_top = -34.0
	lbl.offset_right = -16.0
	lbl.offset_bottom = -12.0

## On a brand-new profile, offer the guided tutorial once.
func _maybe_offer_tutorial() -> void:
	if not ProfileManager.get_first_run():
		return
	var dialog := ConfirmationDialog.new()
	dialog.title = "Welcome to Itzal Rising"
	dialog.dialog_text = "New here? Play the guided tutorial to learn the basics."
	dialog.ok_button_text = "Play Tutorial"
	dialog.cancel_button_text = "Skip"
	add_child(dialog)
	dialog.confirmed.connect(func() -> void: MissionLoader.start_tutorial())
	dialog.canceled.connect(func() -> void: ProfileManager.clear_first_run())
	dialog.popup_centered()

func _on_campaign() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/CampaignMenu.tscn")

func _on_skirmish() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/SkirmishSetup.tscn")

func _on_multiplayer() -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "Multiplayer"
	dialog.dialog_text = "Online multiplayer is coming in a future update."
	add_child(dialog)
	dialog.popup_centered()

func _on_settings() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/SettingsMenu.tscn")

func _on_quit() -> void:
	get_tree().quit()
