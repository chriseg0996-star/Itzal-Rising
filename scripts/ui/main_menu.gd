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
	SoundManager.start_menu_music()
	_maybe_offer_tutorial()

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

## CONTINUE is code-built bottom-left so it never collides with the painted
## center-stack buttons (anchors .398-.601 x .381-.735). Only shown when a
## quicksave exists.
func _build_continue_button() -> void:
	if not SaveManager.has_save():
		return
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.07, 0.11, 0.82)
	sb.set_corner_radius_all(4)
	sb.set_border_width_all(1)
	sb.border_color = Color(0.0, 0.90, 0.78, 0.35)
	var sb_hover: StyleBoxFlat = sb.duplicate()
	sb_hover.border_color = Color(0.0, 0.90, 0.78, 1.0)
	var btn := Button.new()
	btn.text = "CONTINUE"
	btn.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8, 1.0))
	btn.add_theme_color_override("font_hover_color", Color(0.0, 0.90, 0.78, 1.0))
	btn.add_theme_font_size_override("font_size", 16)
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb_hover)
	btn.add_theme_stylebox_override("pressed", sb_hover)
	btn.pressed.connect(func() -> void: SaveManager.request_load())
	add_child(btn)
	btn.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	btn.offset_left = 24.0
	btn.offset_top = -76.0
	btn.offset_right = 220.0
	btn.offset_bottom = -28.0

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
