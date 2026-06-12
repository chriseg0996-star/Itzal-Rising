extends CanvasLayer

@onready var resume_btn: Button = $Center/Panel/Margin/VBox/ResumeBtn
@onready var controls_btn: Button = $Center/Panel/Margin/VBox/ControlsBtn
@onready var save_btn: Button = $Center/Panel/Margin/VBox/SaveBtn
@onready var exit_btn: Button = $Center/Panel/Margin/VBox/ExitBtn
@onready var quit_btn: Button = $Center/Panel/Margin/VBox/QuitBtn

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	resume_btn.pressed.connect(_on_resume)
	controls_btn.pressed.connect(_on_controls)
	save_btn.pressed.connect(_on_save)
	exit_btn.pressed.connect(_on_exit_to_menu)
	quit_btn.pressed.connect(_on_quit_game)
	_setup_hover(resume_btn)
	_setup_hover(controls_btn)
	_setup_hover(save_btn)
	_setup_hover(exit_btn)
	_setup_hover(quit_btn)

func _setup_hover(btn: Button) -> void:
	btn.mouse_entered.connect(func() -> void: btn.modulate = Color(0.6, 1.0, 0.7))
	btn.mouse_exited.connect(func() -> void: btn.modulate = Color.WHITE)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if visible:
			_on_resume()
		else:
			_pause()
		get_viewport().set_input_as_handled()

func _pause() -> void:
	get_tree().paused = true
	visible = true

func _on_resume() -> void:
	get_tree().paused = false
	visible = false

func _on_controls() -> void:
	var panel: Node = get_tree().current_scene.get_node_or_null("ControlsPanel")
	if panel != null and panel.has_method("open"):
		panel.open()

func _on_save() -> void:
	if SaveManager.save_game():
		AlertManager.push("Game saved", "info")
	else:
		AlertManager.push("Save failed", "error")

func _on_exit_to_menu() -> void:
	get_tree().paused = false
	visible = false
	ResourceManager.reset()
	SelectionManager.clear()
	SelectionManager.deselect_building()
	BuildingPlacer.cancel_placement()
	EnemyAI.reset()
	GameStats.reset()
	ObjectiveManager.reset()
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")

func _on_quit_game() -> void:
	get_tree().paused = false
	get_tree().quit()
