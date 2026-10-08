class_name BulletMage
extends RigidBody2D

@export var damage: float = 35.0
@export var aoe_radius: float = 55.0
@export var element_type: int = 0 # 0 = Arcane, 1 = Fire, 2 = Ice
@export var pierce_count: int = 0

@onready var sprite: Sprite2D = get_node_or_null("Sprite2D")
@onready var trail_particles: CPUParticles2D = get_node_or_null("TrailParticles")

var hit_targets: Array = []
var is_exploded: bool = false
var base_scale: Vector2 = Vector2(0.38, 0.38)

func _ready() -> void:
	update_element_appearance()

func _process(delta: float) -> void:
	if not sprite or is_exploded: return
	
	# Hiệu ứng lõi năng lượng phập phồng (Energy Pulsing)
	var pulse = sin(Time.get_ticks_msec() * 0.02) * 0.12
	match element_type:
		0: # Arcane: nhịp đập năng lượng ma pháp rung động
			sprite.scale = base_scale * (1.0 + pulse)
		1: # Fire: quả cầu lửa cuộn xoáy tròn liên tục
			sprite.rotation += 9.0 * delta
			sprite.scale = base_scale * (1.0 + pulse * 0.8)
		2: # Ice: mũi tên băng lấp lánh ánh kim
			sprite.scale.y = base_scale.y * (1.0 + pulse * 0.6)

func set_element(elem: int) -> void:
	element_type = elem
	update_element_appearance()

func update_element_appearance() -> void:
	match element_type:
		0: # Quang Ma Pháp / Arcane
			damage = 38.0
			aoe_radius = 65.0
			pierce_count = 0
			gravity_scale = 0.0 # Bay thẳng tuyệt đối
			base_scale = Vector2(0.38, 0.38)
			if sprite:
				sprite.modulate = Color(2.0, 0.6, 3.0, 1.0) # Tím Arcane phát sáng
				sprite.scale = base_scale
			if trail_particles:
				trail_particles.local_coords = false
				trail_particles.color = Color(1.8, 0.6, 2.8, 0.85)
				trail_particles.gravity = Vector2.ZERO
				trail_particles.amount = 26
				trail_particles.scale_amount_min = 3.0
				trail_particles.scale_amount_max = 6.5
		1: # Hỏa Phép / Fireball
			damage = 30.0
			aoe_radius = 88.0 # AoE vụ nổ rộng nhất
			pierce_count = 0
			gravity_scale = 0.06 # Hơi trĩu nhẹ tự nhiên
			base_scale = Vector2(0.46, 0.46)
			if sprite:
				sprite.modulate = Color(3.2, 0.8, 0.1, 1.0) # Đỏ Cam Rực Lửa
				sprite.scale = base_scale
			if trail_particles:
				trail_particles.local_coords = false
				trail_particles.color = Color(3.0, 0.7, 0.1, 0.9)
				trail_particles.gravity = Vector2(0, -90.0) # Tàn lửa bốc ngược lên trên
				trail_particles.amount = 32
				trail_particles.scale_amount_min = 3.5
				trail_particles.scale_amount_max = 8.0
		2: # Băng Phép / Frost Shard
			damage = 26.0
			aoe_radius = 60.0
			pierce_count = 1 # Có thể xuyên qua 1 kẻ địch
			gravity_scale = 0.0 # Xé gió bay thẳng
			base_scale = Vector2(0.55, 0.22)
			if sprite:
				sprite.modulate = Color(0.6, 2.2, 3.0, 1.0) # Băng Lam Tuyết Sắc
				sprite.scale = base_scale
			if trail_particles:
				trail_particles.local_coords = false
				trail_particles.color = Color(0.7, 2.2, 3.0, 0.85)
				trail_particles.gravity = Vector2(0, 20.0) # Bụi tuyết rơi nhẹ
				trail_particles.amount = 22
				trail_particles.scale_amount_min = 2.0
				trail_particles.scale_amount_max = 5.0

func shoot(direction: Vector2, speed: float, lifetime: float) -> void:
	rotation = direction.angle()
	apply_impulse(direction * speed)
	if is_inside_tree() and get_tree():
		get_tree().create_timer(lifetime).timeout.connect(func():
			if is_instance_valid(self) and not is_exploded:
				explode_aoe()
				queue_free()
		)

func _on_body_entered(body: Node) -> void:
	if is_exploded:
		return
		
	# Bỏ qua va chạm với người chơi hoặc chính đạn khác
	if body.is_in_group("Player") or body.is_in_group("Bullet"):
		return
		
	var is_enemy = body.is_in_group("Enemy") or body is Enemy or body.is_in_group("Boss")
	
	# Xử lý hiệu ứng xuyên thấu cho Băng Phép (Pierce)
	if is_enemy and pierce_count > 0:
		pierce_count -= 1
		hit_targets.append(body)
		apply_single_target_damage(body)
		spawn_pierce_spark(global_position)
		return # Không nổ, tiếp tục bay xuyên qua mục tiêu!
		
	explode_aoe()
	queue_free()

func apply_single_target_damage(target: Node) -> void:
	var kdir = (target.global_position - global_position).normalized()
	if kdir.length() == 0: kdir = Vector2.RIGHT
	
	if target.has_method("apply_element_effect"):
		target.apply_element_effect(element_type)
	if target.has_method("take_damage"):
		target.take_damage(damage, kdir)
	elif target.has_method("take_hit"):
		target.take_hit(kdir)

func explode_aoe() -> void:
	if is_exploded:
		return
	is_exploded = true
	
	var gm = get_node_or_null("/root/GameManager")
	var burst_color: Color = Color.WHITE
	var shake_power: float = 5.0
	
	match element_type:
		0: # Arcane
			burst_color = Color(2.0, 0.6, 3.0, 1.0)
			shake_power = 5.5
		1: # Fire
			burst_color = Color(3.2, 0.8, 0.1, 1.0)
			shake_power = 8.0
		2: # Ice
			burst_color = Color(0.7, 2.2, 3.0, 1.0)
			shake_power = 4.5
			
	if gm and gm.has_method("shake_camera"):
		gm.shake_camera(shake_power, 0.18)
		
	# Sóng xung kích phát quang bùng nổ (Shockwave ring)
	spawn_impact_shockwave(global_position, burst_color, aoe_radius)
	# Tia hạt phát nổ
	spawn_burst_vfx(global_position, burst_color)
	
	# Quét quái vật và Boss trong bán kính vụ nổ AoE
	if is_inside_tree() and get_tree():
		var enemy_list = get_tree().get_nodes_in_group("Enemy") + get_tree().get_nodes_in_group("Boss")
		for enemy in enemy_list:
			if is_instance_valid(enemy) and enemy is Node2D:
				var enemy_center = enemy.global_position
				if enemy.has_node("CollisionShape2D"):
					enemy_center = enemy.get_node("CollisionShape2D").global_position
				elif enemy.has_node("HitArea"):
					enemy_center = enemy.get_node("HitArea").global_position
				else:
					enemy_center += Vector2(0, -22.0)
					
				var dist = global_position.distance_to(enemy_center)
				if dist <= aoe_radius:
					var kdir = (enemy_center - global_position).normalized()
					if kdir.length() == 0: kdir = Vector2.RIGHT
					
					# Áp dụng hiệu ứng nguyên tố
					if enemy.has_method("apply_element_effect"):
						enemy.apply_element_effect(element_type)
						
					# Áp dụng sát thương
					if enemy.has_method("take_damage"):
						enemy.take_damage(damage, kdir)
					elif enemy.has_method("take_hit"):
						enemy.take_hit(kdir)
					elif enemy.has_method("hit"):
						enemy.hit(int(damage), kdir)

func spawn_impact_shockwave(pos: Vector2, color: Color, max_r: float) -> void:
	if not is_inside_tree() or not get_parent(): return
	var ring = Sprite2D.new()
	ring.texture = load("res://Assets/Spritesheet/laser_bullet.png")
	ring.modulate = color
	ring.global_position = pos
	ring.scale = Vector2(0.1, 0.1)
	get_parent().add_child(ring)
	
	var tw = ring.create_tween()
	var target_scale = max_r * 0.022
	tw.tween_property(ring, "scale", Vector2(target_scale, target_scale), 0.18).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(ring, "modulate:a", 0.0, 0.18)
	tw.tween_callback(ring.queue_free)

func spawn_burst_vfx(burst_pos: Vector2, color: Color) -> void:
	if not is_inside_tree() or not get_parent():
		return
	var p = CPUParticles2D.new()
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 0.95
	p.local_coords = false
	p.amount = 28 if element_type == 1 else 20
	p.lifetime = 0.35
	p.spread = 180.0
	p.gravity = Vector2(0, 60.0) if element_type != 1 else Vector2(0, -60.0)
	p.initial_velocity_min = 70.0
	p.initial_velocity_max = 160.0
	p.scale_amount_min = 2.5
	p.scale_amount_max = 6.0
	p.color = color
	p.global_position = burst_pos
	
	get_parent().add_child(p)
	p.emitting = true
	if is_inside_tree() and get_tree():
		get_tree().create_timer(0.4).timeout.connect(p.queue_free)

func spawn_pierce_spark(spark_pos: Vector2) -> void:
	if not is_inside_tree() or not get_parent():
		return
	var p = CPUParticles2D.new()
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 0.88
	p.local_coords = false
	p.amount = 10
	p.lifetime = 0.22
	p.spread = 180.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 40.0
	p.initial_velocity_max = 90.0
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.0
	p.color = Color(0.8, 2.4, 3.0, 1.0)
	p.global_position = spark_pos
	
	get_parent().add_child(p)
	p.emitting = true
	if is_inside_tree() and get_tree():
		get_tree().create_timer(0.25).timeout.connect(p.queue_free)
