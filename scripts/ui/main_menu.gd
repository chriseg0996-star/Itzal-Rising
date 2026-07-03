extends Control

## Minimalist main menu — typography-first, no boxed buttons. Left column with
## a two-tone wordmark and text-only menu items whose hover state is a sliding
## neon bar; the right half is negative space (or key art, if present). Two
## OPTIONAL image hooks are picked up automatically when the files exist:
##   assets/ui/menu_emblem.png  — small mark above the title (~256px, transparent)
##   assets/ui/menu_keyart.png  — right-side atmosphere art (fades to black left)

const ACCENT: Color = Color(0.0, 0.90, 0.78, 1.0)
const BG: Color = Color(0.043, 0.055, 0.075, 1.0)
const WHITE: Color = Color(0.92, 0.95, 0.98, 1.0)
const MUTED: Color = Color(0.48, 0.55, 0.62, 1.0)
const DISABLED: Color = Color(0.33, 0.38, 0.43, 1.0)

const EMBLEM_PATH: String = "res://assets/ui/menu_emblem.png"
const KEYART_PATH: String = "res://assets/ui/menu_keyart.png"

const MENU_X: float = 0.115   # left column anchor

func _ready() -> void:
	_build_background()
	_build_keyart()
	_build_title_block()
	_build_menu()
	_build_footer()
	SoundManager.start_menu_music()
	_maybe_offer_tutorial()

# ── Background: near-black slate + one quiet teal breath bottom-left ──
func _build_background() -> void:
	var bg := ColorRect.new()
	bg.color = BG
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var breath := TextureRect.new()
	breath.texture = TextureGenerator.get_texture("soft_blob")
	breath.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	breath.stretch_mode = TextureRect.STRETCH_SCALE
	breath.modulate = Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.045)
	breath.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(breath)
	breath.anchor_left = -0.25
	breath.anchor_right = 0.55
	breath.anchor_top = 0.45
	breath.anchor_bottom = 1.45

## Optional right-side key art (hidden until the asset exists).
func _build_keyart() -> void:
	if not ResourceLoader.exists(KEYART_PATH):
		return
	var art := TextureRect.new()
	art.texture = load(KEYART_PATH)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(art)
	art.anchor_left = 0.46
	art.anchor_right = 1.0
	art.anchor_bottom = 1.0

# ── Title block ────────────────────────────────────────────
func _build_title_block() -> void:
	if ResourceLoader.exists(EMBLEM_PATH):
		var emblem := TextureRect.new()
		emblem.texture = load(EMBLEM_PATH)
		emblem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		emblem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
		emblem.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(emblem)
		emblem.anchor_left = MENU_X
		emblem.anchor_right = MENU_X
		emblem.anchor_top = 0.10
		emblem.anchor_bottom = 0.10
		emblem.offset_right = 88.0
		emblem.offset_bottom = 88.0

	# Two-tone wordmark: ITZAL in white, RISING in neon.
	var title := RichTextLabel.new()
	title.bbcode_enabled = true
	title.fit_content = true
	title.scroll_active = false
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.text = "[font_size=64][color=#ebf2fa]ITZAL[/color] [color=#00e6c7]RISING[/color][/font_size]"
	add_child(title)
	title.anchor_left = MENU_X
	title.anchor_right = 0.9
	title.anchor_top = 0.20
	title.anchor_bottom = 0.20
	title.offset_bottom = 84.0

	var sub := Label.new()
	sub.text = "MESOAMERICAN  SCI-FI  RTS"
	sub.add_theme_color_override("font_color", MUTED)
	sub.add_theme_font_size_override("font_size", 14)
	add_child(sub)
	sub.anchor_left = MENU_X
	sub.anchor_right = 0.9
	sub.anchor_top = 0.20
	sub.anchor_bottom = 0.20
	sub.offset_top = 84.0
	sub.offset_bottom = 108.0

	# Short neon rule anchoring the block.
	var rule := ColorRect.new()
	rule.color = Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.6)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rule)
	rule.anchor_left = MENU_X
	rule.anchor_right = MENU_X
	rule.anchor_top = 0.20
	rule.anchor_bottom = 0.20
	rule.offset_top = 120.0
	rule.offset_bottom = 122.0
	rule.offset_right = 56.0

# ── Menu items: text-only, hover = neon bar + indent ───────
func _build_menu() -> void:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	add_child(v)
	v.anchor_left = MENU_X
	v.anchor_right = 0.42
	v.anchor_top = 0.40
	v.anchor_bottom = 0.86

	if SaveManager.has_save():
		v.add_child(_item("CONTINUE", ACCENT, func() -> void: SaveManager.request_load()))
	v.add_child(_item("CAMPAIGN", WHITE, _on_campaign))
	v.add_child(_item("SKIRMISH", WHITE, _on_skirmish))
	v.add_child(_mp_item())
	v.add_child(_item("SETTINGS", WHITE, _on_settings))
	v.add_child(_item("QUIT", MUTED, _on_quit))

func _item(text: String, col: Color, on_press: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.custom_minimum_size = Vector2(0, 46)
	btn.add_theme_color_override("font_color", col)
	btn.add_theme_color_override("font_hover_color", ACCENT)
	btn.add_theme_color_override("font_pressed_color", ACCENT)
	btn.add_theme_color_override("font_focus_color", col)
	btn.add_theme_font_size_override("font_size", 21)
	var normal := StyleBoxEmpty.new()
	normal.content_margin_left = 18.0
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(1, 1, 1, 0.035)
	hover.border_color = ACCENT
	hover.border_width_left = 3
	hover.content_margin_left = 26.0   # slight indent on hover
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("focus", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	btn.pressed.connect(on_press)
	return btn

func _mp_item() -> Button:
	var btn := _item("MULTIPLAYER", DISABLED, _on_multiplayer)
	btn.add_theme_color_override("font_hover_color", DISABLED)
	btn.text = "MULTIPLAYER"
	# tiny muted tag after the label
	var tag := Label.new()
	tag.text = "SOON"
	tag.add_theme_font_size_override("font_size", 10)
	tag.add_theme_color_override("font_color", Color(DISABLED.r, DISABLED.g, DISABLED.b, 0.8))
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(tag)
	tag.anchor_left = 0.0
	tag.anchor_top = 0.5
	tag.anchor_bottom = 0.5
	tag.offset_left = 208.0
	tag.offset_top = -7.0
	tag.offset_bottom = 7.0
	return btn

# ── Footer ─────────────────────────────────────────────────
func _build_footer() -> void:
	var ver: String = String(ProjectSettings.get_setting("application/config/version", "1.0.0"))
	var lbl := Label.new()
	lbl.text = "v%s" % ver
	lbl.add_theme_color_override("font_color", Color(0.40, 0.47, 0.53, 0.7))
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(lbl)
	lbl.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	lbl.offset_left = -120.0
	lbl.offset_top = -30.0
	lbl.offset_right = -18.0
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
