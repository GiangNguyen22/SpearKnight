class_name FloatingPlatform
extends AnimatableBody2D

@export var is_moving: bool = false
@export var move_offset: Vector2 = Vector2(0, -60)
@export var move_duration: float = 2.0
@export var hover_bob: bool = false
@export var hover_amplitude: float = 2.0
@export var hover_frequency: float = 2.0

var _start_pos: Vector2
var _time: float = 0.0


func _ready() -> void:
	_start_pos = position
	if is_moving:
		_start_moving_tween()


func _physics_process(delta: float) -> void:
	if not is_moving and hover_bob:
		_time += delta * hover_frequency
		position.y = _start_pos.y + sin(_time) * hover_amplitude


func _start_moving_tween() -> void:
	var tween = create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "position", _start_pos + move_offset, move_duration)
	tween.tween_property(self, "position", _start_pos, move_duration)
