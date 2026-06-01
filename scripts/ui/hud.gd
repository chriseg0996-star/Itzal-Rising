extends CanvasLayer

@onready var wood_label: Label = $TopBar/Margin/HBox/Wood/Label
@onready var food_label: Label = $TopBar/Margin/HBox/Food/Label
@onready var gold_label: Label = $TopBar/Margin/HBox/Gold/Label

func _ready() -> void:
	ResourceManager.resources_changed.connect(_refresh)
	_refresh()

func _refresh() -> void:
	wood_label.text = str(ResourceManager.wood)
	food_label.text = str(ResourceManager.food)
	gold_label.text = str(ResourceManager.gold)
