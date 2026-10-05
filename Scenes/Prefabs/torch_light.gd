class_name TorchLight
extends PointLight2D

@export var flicker_speed: float = 10.0
@export var min_energy: float = 0.85
@export var max_energy: float = 1.35
@export var min_scale: float = 0.9
@export var max_scale: float = 1.1

var time_passed: float = 0.0
var base_energy: float = 1.0
var base_scale: Vector2 = Vector2.ONE

func _ready() -> void:
	time_passed = randf_range(0.0, 100.0)
	base_energy = energy
	base_scale = texture_scale * Vector2.ONE

func _process(delta: float) -> void:
	time_passed += delta * flicker_speed
	# Sinusoidal noise simulation for realistic flame flicker
	var noise_val = sin(time_passed) * 0.5 + sin(time_passed * 2.3) * 0.3 + sin(time_passed * 4.7) * 0.2
	var normalized = (noise_val + 1.0) / 2.0
	
	energy = lerp(min_energy, max_energy, normalized)
	texture_scale = lerp(min_scale, max_scale, normalized)
