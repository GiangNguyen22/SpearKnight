class_name FireColumn
extends CPUParticles2D

var strike_radius: float = 75.0
var tick_damage: float = 15.0
var push_direction: Vector2 = Vector2.RIGHT

func setup(pos: Vector2, dmg: float, pdir: Vector2) -> void:
	global_position = pos
	tick_damage = dmg
	push_direction = pdir
	emitting = true
	amount = 40
	lifetime = 0.4
	spread = 15.0
	direction = Vector2(0, -1)
	gravity = Vector2(0, -180.0)
	initial_velocity_min = 60.0
	initial_velocity_max = 130.0
	emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	emission_rect_extents = Vector2(40.0, 4.0)
	scale_amount_min = 3.5
	scale_amount_max = 7.0
	color = Color(3.6, 0.8, 0.1, 0.95)
	
	var tw = create_tween()
	for i in range(4):
		tw.tween_interval(0.3)
		tw.tween_callback(_tick_damage)
	tw.tween_interval(0.1)
	tw.tween_callback(_finish)

func _tick_damage() -> void:
	if not is_inside_tree(): return
	var targets = get_tree().get_nodes_in_group("Enemy") + get_tree().get_nodes_in_group("Boss")
	for t in targets:
		if is_instance_valid(t) and t is Node2D:
			if global_position.distance_to(t.global_position) <= strike_radius:
				if t.has_method("take_damage"):
					t.take_damage(tick_damage, push_direction)

func _finish() -> void:
	emitting = false
	var tw = create_tween()
	tw.tween_interval(0.45)
	tw.tween_callback(queue_free)
