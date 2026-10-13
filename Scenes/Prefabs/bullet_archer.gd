class_name BulletArcher
extends RigidBody2D

@export var damage: int = 24
@export var pierce_count: int = 2

@onready var sprite: Sprite2D = $Sprite2D if has_node("Sprite2D") else null

var trail: CPUParticles2D = null

func _ready() -> void:
	if sprite:
		sprite.modulate = Color(0.4, 2.2, 0.9, 1.0) # Forest Swift Green
		sprite.scale = Vector2(0.24, 0.12) # Kéo dài thành mũi tên nhọn xé gió
	
	# Tạo vệt gió/hạt phát sáng kéo dài theo mũi tên
	trail = CPUParticles2D.new()
	trail.amount = 22
	trail.lifetime = 0.22
	trail.local_coords = false
	trail.gravity = Vector2.ZERO
	trail.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	trail.emission_sphere_radius = 2.0
	trail.scale_amount_min = 2.0
	trail.scale_amount_max = 4.5
	trail.color = Color(0.5, 2.4, 1.0, 0.75)
	add_child(trail)

func shoot(direction: Vector2, speed: float, lifetime: float) -> void:
	rotation = direction.angle()
	apply_impulse(direction * speed * 1.35)
	if is_inside_tree() and get_tree():
		get_tree().create_timer(lifetime).timeout.connect(func():
			if is_instance_valid(self):
				queue_free()
		)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("Player") or body.is_in_group("Bullet"):
		return
		
	if body.is_in_group("Enemy") or body.name.to_lower().contains("enemy") or body.name.to_lower().contains("boss"):
		spawn_hit_spark(global_position)
		var kdir = Vector2(cos(rotation), sin(rotation))
		if body.has_method("take_damage"):
			body.take_damage(damage, kdir)
		elif body.has_method("hit"):
			body.hit(damage, kdir)
		elif body.has_method("take_hit"):
			body.take_hit(kdir)
		
		pierce_count -= 1
		if pierce_count <= 0:
			queue_free()
	else:
		spawn_hit_spark(global_position)
		queue_free()

func spawn_hit_spark(pos: Vector2) -> void:
	if not is_inside_tree() or not get_parent(): return
	var p = CPUParticles2D.new()
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 0.92
	p.amount = 14
	p.lifetime = 0.25
	p.spread = 180.0
	p.gravity = Vector2(0, 30.0)
	p.initial_velocity_min = 60.0
	p.initial_velocity_max = 130.0
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.5
	p.color = Color(0.6, 2.5, 1.2, 1.0)
	p.global_position = pos
	get_parent().add_child(p)
	p.emitting = true
	if is_inside_tree() and get_tree():
		get_tree().create_timer(0.3).timeout.connect(p.queue_free)
