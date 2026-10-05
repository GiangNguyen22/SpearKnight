extends Node2D

const LAYOUT := {
	"SkyFar": {"mode": "cover", "offset": Vector2(0.0, -0.012)},
	"SkyNear": {"mode": "cover", "offset": Vector2(0.0, 0.016)},
	"HillsFar": {"mode": "band", "bottom": 0.95, "height": 0.44},
	"HillsNear": {"mode": "band", "bottom": 1.0, "height": 0.5},
}


func _ready() -> void:
	_layout()
	get_viewport().size_changed.connect(_layout)


func _layout() -> void:
	$UI.size = get_viewport_rect().size
	BgLayout.apply($Background, LAYOUT)