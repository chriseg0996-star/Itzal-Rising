extends Control

const BG_IMAGE: String = "res://assets/sprites/mainmenu_reference.png"

@onready var bg_image: TextureRect = $BGImage
@onready var play_btn: Button = $PlayBtn
@onready var skirmish_btn: Button = $SkirmishBtn
@onready var multiplayer_btn: Button = $MultiplayerBtn
@onready var settings_btn: Button = $SettingsBtn
@onready var quit_btn: Button = $QuitBtn

func _ready() -> void:
	# The menu art (title + buttons) is the whole visual. These buttons are
	# transparent hit-targets anchored exactly over the baked buttons; the bg
	# is stretched to fill the viewport so the anchors stay aligned.
	if ResourceLoader.exists(BG_IMAGE):
		bg_image.texture = load(BG_IMAGE)
	# Stack order matches the painted buttons: Campaign / Skirmish / Multiplayer
	# / Settings / Quit.
	play_btn.pressed.connect(_on_campaign)
	skirmish_btn.pressed.connect(_on_skirmish)
	multiplayer_btn.pressed.connect(_on_multiplayer)
	settings_btn.pressed.connect(_on_settings)
	quit_btn.pressed.connect(_on_quit)
	_build_continue_button()
	_dim_multiplayer()
	_build_version_label()
	SoundManager.start_menu_music()
	_maybe_offer_tutorial()

## Version string sourced from project.godot (config/version) so it never drifts
## from the actual build. Bottom-right, unobtrusive.
func _build_version_label() -> void:
	var ver: String = String(ProjectSettings.get_setting("application/config/version", "1.0.0"))
	var lbl := Label.new()
	lbl.text = "v%s" % ver
	lbl.add_theme_color_override("font_color", Color(0.55, 0.62, 0.68, 0.8))
	lbl.add_theme_font_size_override("font_size", 14)
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

## CONTINUE joins the painted button column (right under QUIT), styled to match
## the baked buttons: dark bevelled plate, light stone border, spaced caps.
## Only shown when a quicksave exists.
func _build_continue_button() -> void:
	if not SaveManager.has_save():
		return
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.075, 0.145, 0.155, 0.96)
	sb.set_corner_radius_all(6)
	sb.set_border_width_all(2)
	sb.border_color = Color(0.55, 0.72, 0.70, 0.85)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 4
	var sb_hover: StyleBoxFlat = sb.duplicate()
	sb_hover.bg_color = Color(0.10, 0.20, 0.21, 0.96)
	sb_hover.border_color = Color(0.0, 0.90, 0.78, 1.0)
	var btn := Button.new()
	btn.text = "C O N T I N U E"
	btn.add_theme_color_override("font_color", Color(0.85, 0.93, 0.92, 1.0))
	btn.add_theme_color_override("font_hover_color", Color(0.0, 0.90, 0.78, 1.0))
	btn.add_theme_font_size_override("font_size", 17)
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb_hover)
	btn.add_theme_stylebox_override("pressed", sb_hover)
	btn.pressed.connect(func() -> void: SaveManager.request_load())
	add_child(btn)
	# Same column as the painted stack (x .412-.588), one row below QUIT (.740-.800).
	btn.anchor_left = 0.412
	btn.anchor_right = 0.588
	btn.anchor_top = 0.822
	btn.anchor_bottom = 0.882
	btn.offset_left = 0.0
	btn.offset_top = 0.0
	btn.offset_right = 0.0
	btn.offset_bottom = 0.0

## The baked MULTIPLAYER button stays clickable (honest popup) but reads as
## not-yet-available: dimmed plate + a small COMING SOON tag.
func _dim_multiplayer() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.04, 0.55)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	dim.anchor_left = 0.412
	dim.anchor_right = 0.588
	dim.anchor_top = 0.579
	dim.anchor_bottom = 0.639
	var tag := Label.new()
	tag.text = "COMING SOON"
	tag.add_theme_font_size_override("font_size", 10)
	tag.add_theme_color_override("font_color", Color(0.75, 0.80, 0.82, 0.85))
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tag)
	tag.anchor_left = 0.591
	tag.anchor_right = 0.68
	tag.anchor_top = 0.596
	tag.anchor_bottom = 0.625

func _on_campaign() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/CampaignMenu.tscn")

func _on_skirmish() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/SkirmishSetup.tscn")

func _on_multiplayer() -> void:
	# No online play yet — let the painted button give honest feedback.
	var dialog := AcceptDialog.new()
	dialog.title = "Multiplayer"
	dialog.dialog_text = "Online multiplayer is coming in a future update."
	add_child(dialog)
	dialog.popup_centered()

func _on_settings() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/SettingsMenu.tscn")

func _on_quit() -> void:
	get_tree().quit()
