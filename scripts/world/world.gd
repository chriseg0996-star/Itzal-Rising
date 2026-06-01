class_name World
extends Node2D

@export var soldier_scene: PackedScene

func _ready() -> void:
	$BuildingPanel.set_world(self)

func _on_unit_spawn_requested(unit_type: StringName, spawn_position: Vector2) -> void:
	if unit_type == &"soldier":
		if soldier_scene == null:
			push_error("World: soldier_scene is not assigned")
			return
		var soldier: CharacterBody2D = soldier_scene.instantiate() as CharacterBody2D
		soldier.global_position = spawn_position
		add_child(soldier)
