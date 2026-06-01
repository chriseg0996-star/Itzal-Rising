extends Control

@onready var play_btn: Button = $Center/VBox/PlayBtn
@onready var settings_btn: Button = $Center/VBox/SettingsBtn
@onready var quit_btn: Button = $Center/VBox/QuitBtn
@onready var version_label: Label = $VersionLabel

func _ready() -> void:
	play_btn.pressed.connect(_on_play)
	settings_btn.pressed.connect(_on_settings)
	quit_btn.pressed.connect(_on_quit)
	_setup_hover(play_btn)
	_setup_hover(settings_btn)
	_setup_hover(quit_btn)
	version_label.text = "v" + str(ProjectSettings.get_setting("application/config/version", "1.0.0"))

func _setup_hover(btn: Button) -> void:
	btn.mouse_entered.connect(func() -> void: btn.modulate = Color(1, 1, 1, 1))
	btn.mouse_exited.connect(func() -> void: btn.modulate = Color.WHITE)

func _on_play() -> void:
	ResourceManager.reset()
	SelectionManager.clear()
	SelectionManager.deselect_building()
	BuildingPlacer.cancel_placement()
	EnemyAI.reset()
	GameStats.reset()
	get_tree().change_scene_to_file("res://scenes/world/World.tscn")

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
