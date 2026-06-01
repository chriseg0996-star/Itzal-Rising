extends CanvasLayer

@onready var wood_label: Label = $TopBar/Margin/HBox/Wood/Label
@onready var food_label: Label = $TopBar/Margin/HBox/Food/Label
@onready var gold_label: Label = $TopBar/Margin/HBox/Gold/Label

func _ready() -> void:
	ResourceManager.resource_changed.connect(_on_resource_changed)
	_refresh()

func _on_resource_changed(_type: StringName, _new_amount: int) -> void:
	_refresh()

func _refresh() -> void:
	wood_label.text = str(ResourceManager.get_resource(ResourceManager.WOOD))
	food_label.text = str(ResourceManager.get_resource(ResourceManager.FOOD))
	gold_label.text = str(ResourceManager.get_resource(ResourceManager.GOLD))
