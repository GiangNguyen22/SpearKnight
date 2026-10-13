class_name SerpentEntangle
extends Node2D

var target_node: Node2D = null
var orig_speed: float = 100.0
var entangle_damage: float = 14.0
var vines: Sprite2D = null
var spore: CPUParticles2D = null

func setup(target: Node2D) -> void:
	target_node = target
	if "is_frozen" in target_node:
		target_node.is_frozen = true
	if "speed" in target_node:
		orig_speed = target_node.speed
		target_node.speed = 0.0
	
	vines = Sprite2D.new()
	vines.texture = preload("res://Assets/Spritesheet/laser_bullet.png")
	vines.modulate = Color(0.3, 2.8, 0.7, 0.9)
	vines.scale = Vector2(0.35, 0.18)
	vines.rotation = randf_range(-0.3, 0.3)
	vines.position = Vector2(0, 5)
	add_child(vines)
	
	spore = CPUParticles2D.new()
	spore.amount = 16
	spore.lifetime = 0.4
	spore.spread = 180.0
	spore.gravity = Vector2(0, -25)
	spore.initial_velocity_min = 20.0
	spore.initial_velocity_max = 50.0
	spore.scale_amount_min = 2.5
	spore.scale_amount_max = 5.0
	spore.color = Color(0.3, 2.6, 0.6, 0.9)
	add_child(spore)
	
	var tw = create_tween()
	tw.tween_interval(0.5)
	tw.tween_callback(_tick_damage)
	tw.tween_interval(0.5)
	tw.tween_callback(_tick_damage)
	tw.tween_interval(0.5)
	tw.tween_callback(_finish)

func _tick_damage() -> void:
	if is_instance_valid(target_node) and target_node.has_method("take_damage"):
		target_node.take_damage(entangle_damage, Vector2.ZERO)

func _finish() -> void:
	if is_instance_valid(target_node):
		if target_node.has_method("take_damage"):
			target_node.take_damage(entangle_damage, Vector2.ZERO)
		if "speed" in target_node:
			target_node.speed = orig_speed
		if "is_frozen" in target_node:
			target_node.is_frozen = false
	queue_free()
