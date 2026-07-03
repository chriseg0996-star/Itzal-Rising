extends CanvasLayer

## The single AoE4-style bottom console: one fixed frame, bottom-right, holding
## [Selection][Commands][Abilities+Minimap] as physically-joined sections. The
## sections are laid out by the HBox — no floating panels, no gaps.

func _ready() -> void:
	($Frame as PanelContainer).add_theme_stylebox_override("panel", MenuKit.flat_box(0.0, 0.11))
