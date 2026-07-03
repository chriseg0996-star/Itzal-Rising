class_name MenuKit
extends RefCounted

## Shared minimalist menu language (single source of truth for every screen):
## slate background + teal breath, left-column typography, text-only items with
## a sliding neon hover/selected bar, and a bottom-left back item. Matches the
## main menu exactly so all screens read as one product.

const ACCENT: Color = Color(0.0, 0.90, 0.78, 1.0)
const BG: Color = Color(0.043, 0.055, 0.075, 1.0)
const WHITE: Color = Color(0.92, 0.95, 0.98, 1.0)
const MUTED: Color = Color(0.48, 0.55, 0.62, 1.0)
const DISABLED: Color = Color(0.33, 0.38, 0.43, 1.0)
const MENU_X: float = 0.115

## HUD plate tiers (nine-patch frames from tools/make_ui_frames.py). Console =
## heavy bottom plates (chamfered, gradient, lit rim); chip = light secondary.
static func console_box(pad: float = 14.0) -> StyleBoxTexture:
	return _tex_box("res://assets/ui/frame_console.png", 44.0, pad)

static func chip_box(pad: float = 10.0) -> StyleBoxTexture:
	return _tex_box("res://assets/ui/frame_chip.png", 14.0, pad)

## THE master HUD plate — every panel (objectives, resources, bottom console)
## wears this exact frame so the whole HUD reads as one family: dark outer
## bevel, teal hairline, gold corner ticks, faint engraved greca in the band.
static func family_box(pad: float = 10.0) -> StyleBoxTexture:
	return _tex_box("res://assets/ui/plate_frame.png", 12.0, pad)

## Premium progress-bar pair: dark track with a thin gold border + beveled
## (rounded) ends; fill in the given colour. Shared by HP, queue and
## objective bars so every bar in the HUD is the same object.
const GOLD: Color = Color(0.784, 0.663, 0.29, 1.0)

static func bar_track() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.04, 0.055, 1.0)
	sb.set_border_width_all(1)
	sb.border_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.30)
	sb.set_corner_radius_all(2)
	return sb

static func bar_fill(color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(2)
	return sb

## Bottom-dock section style: obsidian fill + hairline separator instead of the
## heavy neon plate. Sections placed flush read as one continuous console.
static func flat_box(pad: float = 10.0, border_alpha: float = 0.11, sep_only: bool = false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	# Sections are translucent so the console Frame's textured obsidian plate
	# shows through — one continuous material across the whole band.
	sb.bg_color = Color(0.02, 0.03, 0.04, 0.35 if sep_only else 0.97)
	if sep_only:
		# Console sections: hairline only on top and left — adjacent flush
		# sections share a single separator, no boxed-in look.
		sb.border_width_top = 1
		sb.border_width_left = 1
	else:
		sb.set_border_width_all(1)
	sb.border_color = Color(ACCENT.r, ACCENT.g, ACCENT.b, border_alpha)
	# Square corners: flush sections join seamlessly into one console.
	sb.set_content_margin_all(pad)
	return sb

static func _tex_box(path: String, margin: float, pad: float) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = load(path)
	sb.texture_margin_left = margin
	sb.texture_margin_top = margin
	sb.texture_margin_right = margin
	sb.texture_margin_bottom = margin
	sb.content_margin_left = pad
	sb.content_margin_top = pad
	sb.content_margin_right = pad
	sb.content_margin_bottom = pad
	return sb

static func build_background(root: Control) -> void:
	var bg := ColorRect.new()
	bg.color = BG
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var breath := TextureRect.new()
	breath.texture = TextureGenerator.get_texture("soft_blob")
	breath.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	breath.stretch_mode = TextureRect.STRETCH_SCALE
	breath.modulate = Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.045)
	breath.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(breath)
	breath.anchor_left = -0.25
	breath.anchor_right = 0.55
	breath.anchor_top = 0.45
	breath.anchor_bottom = 1.45

## Screen header: big white title + short neon rule, left column.
static func build_header(root: Control, text: String) -> void:
	var title := Label.new()
	title.text = text
	title.add_theme_color_override("font_color", WHITE)
	title.add_theme_font_size_override("font_size", 44)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(title)
	title.anchor_left = MENU_X
	title.anchor_right = 0.9
	title.anchor_top = 0.09
	title.anchor_bottom = 0.09
	title.offset_bottom = 58.0
	var rule := ColorRect.new()
	rule.color = Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.6)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(rule)
	rule.anchor_left = MENU_X
	rule.anchor_right = MENU_X
	rule.anchor_top = 0.09
	rule.anchor_bottom = 0.09
	rule.offset_top = 66.0
	rule.offset_bottom = 68.0
	rule.offset_right = 56.0

## Small spaced-caps section label (MAP / AUDIO / ...).
static func section(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.85))
	l.add_theme_font_size_override("font_size", 12)
	var fv := FontVariation.new()
	fv.spacing_glyph = 4
	l.add_theme_font_override("font", fv)
	return l

## Text-only item; hover slides in a neon bar. `set_meta("selected", true)` via
## mark_selected() keeps the bar + accent on (used by pickers).
static func item(text: String, col: Color, on_press: Callable, font_size: int = 19) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.custom_minimum_size = Vector2(0, 42)
	btn.add_theme_color_override("font_color", col)
	btn.add_theme_color_override("font_hover_color", ACCENT)
	btn.add_theme_color_override("font_pressed_color", ACCENT)
	btn.add_theme_color_override("font_focus_color", col)
	btn.add_theme_font_size_override("font_size", font_size)
	btn.add_theme_stylebox_override("normal", _sb_normal())
	btn.add_theme_stylebox_override("focus", _sb_normal())
	btn.add_theme_stylebox_override("hover", _sb_bar(0.035))
	btn.add_theme_stylebox_override("pressed", _sb_bar(0.035))
	btn.pressed.connect(on_press)
	return btn

## Toggle an item's persistent selected look (neon bar + accent text).
static func mark_selected(btn: Button, selected: bool, base_col: Color = WHITE) -> void:
	if selected:
		btn.add_theme_stylebox_override("normal", _sb_bar(0.05))
		btn.add_theme_stylebox_override("focus", _sb_bar(0.05))
		btn.add_theme_color_override("font_color", ACCENT)
	else:
		btn.add_theme_stylebox_override("normal", _sb_normal())
		btn.add_theme_stylebox_override("focus", _sb_normal())
		btn.add_theme_color_override("font_color", base_col)

static func _sb_normal() -> StyleBoxEmpty:
	var sb := StyleBoxEmpty.new()
	sb.content_margin_left = 18.0
	return sb

static func _sb_bar(bg_alpha: float) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, bg_alpha)
	sb.border_color = ACCENT
	sb.border_width_left = 3
	sb.content_margin_left = 26.0
	return sb

## Bottom-left back item.
static func build_back(root: Control, on_press: Callable) -> void:
	var btn := item("←  BACK", MUTED, on_press, 16)
	root.add_child(btn)
	btn.anchor_left = MENU_X
	btn.anchor_right = MENU_X + 0.15
	btn.anchor_top = 0.90
	btn.anchor_bottom = 0.90
	btn.offset_bottom = 42.0

## Version tag bottom-right (same as the main menu).
static func build_version(root: Control) -> void:
	var ver: String = String(ProjectSettings.get_setting("application/config/version", "1.0.0"))
	var lbl := Label.new()
	lbl.text = "v%s" % ver
	lbl.add_theme_color_override("font_color", Color(0.40, 0.47, 0.53, 0.7))
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(lbl)
	lbl.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	lbl.offset_left = -120.0
	lbl.offset_top = -30.0
	lbl.offset_right = -18.0
	lbl.offset_bottom = -12.0
