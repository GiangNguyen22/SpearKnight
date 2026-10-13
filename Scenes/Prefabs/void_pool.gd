class_name VoidPool
extends CPUParticles2D

var pool_radius: float = 75.0
var tick_damage: float = 12.0

func setup(pos: Vector2) -> void:
	global_position = pos
	emitting = true
	amount = 26
	lifetime = 0.45
	spread = 180.0
	gravity = Vector2(0, -35.0)
	initial_velocity_min = 20.0
	initial_velocity_max = 60.0
	scale_amount_min = 3.5
	scale_amount_max = 7.5
	color = Color(1.3, 0.3, 2.2, 0.85)
	
	var tw = create_tween()
	for i in range(4):
		tw.tween_interval(0.35)
		tw.tween_callback(_tick_damage)
	tw.tween_interval(0.1)
	tw.tween_callback(_finish)

func _tick_damage() -> void:
	if not is_inside_tree(): return
	var targets = get_tree().get_nodes_in_group("Enemy") + get_tree().get_nodes_in_group("Boss")
	for t in targets:
		if is_instance_valid(t) and t is Node2D:
			if global_position.distance_to(t.global_position) <= pool_radius:
				if "speed" in t: t.speed = max(30.0, t.speed * 0.7)
				if t.has_method("take_damage"): t.take_damage(tick_damage, Vector2.ZERO)

func _finish() -> void:
	emitting = false
	var tw = create_tween()
	tw.tween_interval(0.4)
	tw.tween_callback(queue_free)
