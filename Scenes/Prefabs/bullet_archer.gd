class_name BulletArcher
extends RigidBody2D

const ClusterBombletScript = preload("res://Scenes/Prefabs/cluster_bomblet.gd")
const SerpentEntangleScript = preload("res://Scenes/Prefabs/serpent_entangle.gd")

@export var damage: int = 30
@export var pierce_count: int = 1
@export var element_type: int = 0 # 0 = Wind Gale, 1 = Cluster Bomb, 2 = Serpent Entangle

@onready var sprite: Sprite2D = $Sprite2D if has_node("Sprite2D") else null

var trail: CPUParticles2D = null

func _ready() -> void:
	if sprite:
		sprite.scale = Vector2(0.26, 0.12)
	
	trail = CPUParticles2D.new()
	trail.amount = 24
	trail.lifetime = 0.24
	trail.local_coords = false
	trail.gravity = Vector2.ZERO
	trail.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	trail.emission_sphere_radius = 2.0
	trail.scale_amount_min = 2.0
	trail.scale_amount_max = 5.0
	add_child(trail)
	
	apply_element_visuals()

func set_element(elem: int) -> void:
	element_type = elem
	apply_element_visuals()

func apply_element_visuals() -> void:
	match element_type:
		0: # 🍃 Phong Linh Tiễn: Xanh ngọc lục xé gió bão táp, tốc độ cực nhanh, xuyên 3 quái
			damage = 32
			pierce_count = 3
			if sprite:
				sprite.modulate = Color(0.6, 2.6, 1.2, 1.0)
			if trail:
				trail.color = Color(0.5, 2.4, 1.0, 0.85)
		1: # 💥 Pháo Kích Tiễn: Đỏ cam rực lửa, đầu đạn nổ chùm Cluster Bomblets
			damage = 35
			pierce_count = 1
			if sprite:
				sprite.modulate = Color(3.6, 0.8, 0.15, 1.0)
			if trail:
				trail.color = Color(3.2, 0.7, 0.1, 0.9)
		2: # 🌿 Độc Xà Trói Chân: Xanh lục bảo độc dược, bung dây leo trói chân 1.5s
			damage = 28
			pierce_count = 1
			if sprite:
				sprite.modulate = Color(0.3, 2.8, 0.6, 1.0)
			if trail:
				trail.color = Color(0.3, 2.4, 0.5, 0.85)

func shoot(direction: Vector2, speed: float, lifetime: float) -> void:
	rotation = direction.angle()
	var speed_mult := 1.35
	if element_type == 0:
		speed_mult = 1.70 # Phong Linh Tiễn bay xé gió siêu tốc
	apply_impulse(direction * speed * speed_mult)
	var life_tw := create_tween()
	life_tw.tween_interval(lifetime)
	life_tw.tween_callback(queue_free)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("Player") or body.is_in_group("Bullet"):
		return
		
	var is_enemy = body.is_in_group("Enemy") or body.name.to_lower().contains("enemy") or body.name.to_lower().contains("boss")
	spawn_hit_spark(global_position)
	var kdir = Vector2(cos(rotation), sin(rotation))
	
	if is_enemy:
		# Áp dụng cơ chế độc quyền theo hệ của Archer
		match element_type:
			0: # Phong Linh: Xuyên quái kèm đẩy lùi gió lốc
				if body.has_method("take_damage"): body.take_damage(damage, kdir * 1.2)
				elif body.has_method("take_hit"): body.take_hit(kdir * 1.2)
			1: # Pháo Kích: Nổ chùm bom văng miểng Cluster
				if body.has_method("take_damage"): body.take_damage(damage, kdir)
				_trigger_cluster_bomblets(global_position)
			2: # Độc Xà: Trói chân tại chỗ 1.5s & phun độc
				if body.has_method("take_damage"): body.take_damage(damage, Vector2.ZERO)
				_trigger_serpent_entangle(body)
				
		pierce_count -= 1
		if pierce_count <= 0:
			queue_free()
	else:
		if element_type == 1:
			_trigger_cluster_bomblets(global_position)
		queue_free()

# --------- CƠ CHẾ 1: BOM CHÙM NỔ LIÊN HOÀN (CLUSTER BOMBLETS) ---------- #
func _trigger_cluster_bomblets(center_pos: Vector2) -> void:
	if not is_inside_tree() or not get_parent(): return
	
	# Vụ nổ chính
	_spawn_explosion_vfx(center_pos, Color(3.6, 0.8, 0.15, 1.0), 24)
	
	# Bắn văng 3 quả mìn nhỏ tỏa ra xung quanh nổ tiếp nối sau 0.15s
	for i in range(3):
		var angle = randf_range(-PI, PI)
		var offset = Vector2(cos(angle), sin(angle)) * randf_range(35.0, 75.0)
		var sub_pos = center_pos + offset
		
		var frag = ClusterBombletScript.new()
		get_parent().add_child(frag)
		frag.launch(center_pos, sub_pos)

func _spawn_explosion_vfx(pos: Vector2, col: Color, particle_count: int) -> void:
	if not get_parent(): return
	var p := CPUParticles2D.new()
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = particle_count
	p.lifetime = 0.32
	p.spread = 180.0
	p.gravity = Vector2(0, -50.0)
	p.initial_velocity_min = 80.0
	p.initial_velocity_max = 180.0
	p.scale_amount_min = 3.0
	p.scale_amount_max = 6.5
	p.color = col
	p.global_position = pos
	get_parent().add_child(p)
	p.emitting = true
	var tw = p.create_tween()
	tw.tween_interval(0.4)
	tw.tween_callback(p.queue_free)

# --------- CƠ CHẾ 2: DÂY LEO ĐỘC XÀ TRÓI CHÂN 1.5S (SERPENT ENTANGLE) ---------- #
func _trigger_serpent_entangle(target: Node) -> void:
	if not is_instance_valid(target) or not (target is Node2D): return
	var entangle = SerpentEntangleScript.new()
	target.add_child(entangle)
	entangle.setup(target)

func spawn_hit_spark(pos: Vector2) -> void:
	if not is_inside_tree() or not get_parent(): return
	var sp := Sprite2D.new()
	sp.texture = load("res://Assets/Spritesheet/laser_bullet.png")
	sp.modulate = Color.WHITE
	sp.scale = Vector2(0.12, 0.12)
	sp.global_position = pos
	get_parent().add_child(sp)
	var tw = sp.create_tween()
	tw.tween_property(sp, "scale", Vector2(0.24, 0.24), 0.08)
	tw.tween_property(sp, "modulate:a", 0.0, 0.08)
	tw.tween_callback(sp.queue_free)
