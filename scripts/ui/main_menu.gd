extends Control

const BG_IMAGE: String = "res://assets/sprites/mainmenu_reference.png"

@onready var bg_image: TextureRect = $BGImage
@onready var play_btn: Button = $PlayBtn
@onready var skirmish_btn: Button = $SkirmishBtn
@onready var settings_btn: Button = $SettingsBtn
@onready var quit_btn: Button = $QuitBtn

func _ready() -> void:
	# The menu art (title + buttons) is the whole visual. These buttons are
	# transparent hit-targets anchored exactly over the baked buttons; the bg
	# is stretched to fill the viewport so the anchors stay aligned.
	if ResourceLoader.exists(BG_IMAGE):
		bg_image.texture = load(BG_IMAGE)
	play_btn.pressed.connect(_on_play)
	skirmish_btn.pressed.connect(_on_skirmish)
	settings_btn.pressed.connect(_on_settings)
	quit_btn.pressed.connect(_on_quit)

func _on_play() -> void:
	# Play opens Skirmish setup (faction/difficulty chosen there before launch).
	get_tree().change_scene_to_file("res://scenes/ui/SkirmishSetup.tscn")

func _on_skirmish() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/SkirmishSetup.tscn")

func _on_settings() -> void:
	var dialog: AcceptDialog = AcceptDialog.new()
	dialog.title = "Settings"
	dialog.dialog_text = "Settings coming soon.\n\nPlanned: Volume sliders, difficulty, key bindings."
	dialog.confirmed.connect(func() -> void: dialog.queue_free())
	dialog.canceled.connect(func() -> void: dialog.queue_free())
	add_child(dialog)
	dialog.popup_centered()

func _on_quit() -> void:
	get_tree().quit()
