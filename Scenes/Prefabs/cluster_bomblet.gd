class_name ClusterBomblet
extends Sprite2D

var target_position: Vector2 = Vector2.ZERO
var bomblet_damage: float = 20.0
var bomblet_radius: float = 55.0

func launch(start_pos: Vector2, target_pos: Vector2) -> void:
	global_position = start_pos
	target_position = target_pos
	texture = preload("res://Assets/Spritesheet/laser_bullet.png")
	modulate = Color(3.8, 0.9, 0.2, 1.0)
	scale = Vector2(0.08, 0.08)
	
	var tw = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "global_position", target_position, 0.14)
	tw.tween_callback(_explode)

func _explode() -> void:
	if not is_inside_tree():
		queue_free()
		return
	_spawn_vfx(global_position)
	var targets = get_tree().get_nodes_in_group("Enemy") + get_tree().get_nodes_in_group("Boss")
	for en in targets:
		if is_instance_valid(en) and en is Node2D:
			if global_position.distance_to(en.global_position) <= bomblet_radius:
				if en.has_method("take_damage"):
					var kdir = (en.global_position - global_position).normalized()
					en.take_damage(bomblet_damage, kdir)
	queue_free()

func _spawn_vfx(pos: Vector2) -> void:
	if not get_parent(): return
	var p := CPUParticles2D.new()
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = 16
	p.lifetime = 0.32
	p.spread = 180.0
	p.gravity = Vector2(0, -50.0)
	p.initial_velocity_min = 80.0
	p.initial_velocity_max = 180.0
	p.scale_amount_min = 3.0
	p.scale_amount_max = 6.5
	p.color = Color(3.5, 0.7, 0.1, 1.0)
	p.global_position = pos
	get_parent().add_child(p)
	p.emitting = true
	var tw = p.create_tween()
	tw.tween_interval(0.4)
	tw.tween_callback(p.queue_free)
