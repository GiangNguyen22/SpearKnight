class_name PlayerCamera
extends Camera2D

var shake_strength: float = 0.0
var shake_decay_rate: float = 30.0


func _process(delta: float) -> void:
	if shake_strength > 0.01:
		shake_strength = move_toward(shake_strength, 0.0, shake_decay_rate * delta)
		offset = Vector2(
			randf_range(-shake_strength, shake_strength),
			randf_range(-shake_strength, shake_strength)
		)
	else:
		shake_strength = 0.0
		offset = Vector2.ZERO


func apply_shake(intensity: float = 8.0, duration: float = 0.2) -> void:
	shake_strength = max(shake_strength, intensity)
	shake_decay_rate = intensity / max(duration, 0.05)


func shake(strength: float = 8.0, duration: float = 0.2) -> void:
	apply_shake(strength, duration)
