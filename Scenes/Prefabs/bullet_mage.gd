class_name BulletMage
extends RigidBody2D

const VoidPoolScript = preload("res://Scenes/Prefabs/void_pool.gd")

@export var damage: float = 35.0
@export var aoe_radius: float = 65.0
@export var element_type: int = 0 # 0 = Cosmic Arcane, 1 = Aurora Lightning, 2 = Abyssal Void
@export var pierce_count: int = 0

@export var is_giant_orb: bool = false

@onready var sprite: Sprite2D = get_node_or_null("Sprite2D")
@onready var trail_particles: CPUParticles2D = get_node_or_null("TrailParticles")

var hit_targets: Array = []
var is_exploded: bool = false
var base_scale: Vector2 = Vector2(0.42, 0.42)
var flight_time: float = 0.0
var fly_dir: Vector2 = Vector2.RIGHT

func _ready() -> void:
	if not is_giant_orb:
		update_element_appearance()

func configure_giant_orb(elem: int = -1) -> void:
	is_giant_orb = true
	if elem >= 0:
		element_type = elem
	update_element_appearance()
	
	damage = 110.0
	aoe_radius = 180.0
	pierce_count = 2
	gravity_scale = 0.0
	base_scale = Vector2(1.25, 1.25)
	
	if sprite:
		sprite.scale = base_scale
	
	if has_node("CollisionShape2D"):
		var col_shape = get_node("CollisionShape2D")
		var new_shape := CircleShape2D.new()
		new_shape.radius = 32.0
		col_shape.shape = new_shape
		
	if trail_particles:
		trail_particles.amount = 60
		trail_particles.scale_amount_min = 6.0
		trail_particles.scale_amount_max = 15.0
		trail_particles.lifetime = 0.45

func _process(delta: float) -> void:
	if not sprite or is_exploded: return
	flight_time += delta
	
	if is_giant_orb:
		var pulse = sin(Time.get_ticks_msec() * 0.016) * 0.16
		sprite.rotation += 9.0 * delta
		sprite.scale = base_scale * (1.0 + pulse)
		return
		
	var pulse = sin(Time.get_ticks_msec() * 0.02) * 0.14
	match element_type:
		0: # 🌌 Tinh Vân: Nhịp đập hố đen vũ trụ phập phồng
			sprite.scale = base_scale * (1.0 + pulse)
			sprite.rotation += 6.0 * delta
		1: # ⚡ Lôi Vân: Nhấp nháy điện quang cực nhanh
			sprite.scale = base_scale * (1.0 + pulse * 0.5)
			sprite.rotation = linear_velocity.angle()
		2: # 🌑 Hư Không: Bay lượn uốn khúc hình sóng sin
			sprite.rotation += 10.0 * delta
			sprite.scale = base_scale * (1.0 + pulse * 0.8)

func set_element(elem: int) -> void:
	element_type = elem
	update_element_appearance()

func update_element_appearance() -> void:
	match element_type:
		0: # 🌌 Tinh Vân Ma Pháo (Cosmic Arcane - Hút quái & nổ diện rộng)
			damage = 38.0
			aoe_radius = 85.0
			pierce_count = 0
			gravity_scale = 0.0
			base_scale = Vector2(0.45, 0.45)
			if sprite:
				sprite.modulate = Color(2.4, 0.7, 3.4, 1.0) # Tím vũ trụ sáng rực
				sprite.scale = base_scale
			if trail_particles:
				trail_particles.local_coords = false
				trail_particles.color = Color(2.0, 0.6, 3.0, 0.85)
				trail_particles.gravity = Vector2.ZERO
				trail_particles.amount = 28
				trail_particles.scale_amount_min = 3.0
				trail_particles.scale_amount_max = 7.0
		1: # ⚡ Lôi Vân Cực Quang (Aurora Chain Lightning - Sét chuỗi giật lan)
			damage = 34.0
			aoe_radius = 65.0
			pierce_count = 0
			gravity_scale = 0.0
			base_scale = Vector2(0.55, 0.26)
			if sprite:
				sprite.modulate = Color(0.6, 2.8, 1.6, 1.0) # Xanh cực quang ngọc bích
				sprite.scale = base_scale
			if trail_particles:
				trail_particles.local_coords = false
				trail_particles.color = Color(0.4, 2.6, 1.4, 0.9)
				trail_particles.gravity = Vector2.ZERO
				trail_particles.amount = 26
				trail_particles.scale_amount_min = 2.5
				trail_particles.scale_amount_max = 6.0
		2: # 🌑 Hư Không Hắc Ma (Abyssal Void - Bẫy nguyền rủa suy nhược)
			damage = 30.0
			aoe_radius = 80.0
			pierce_count = 0
			gravity_scale = 0.02
			base_scale = Vector2(0.48, 0.48)
			if sprite:
				sprite.modulate = Color(1.3, 0.3, 2.2, 1.0) # Tím đen hắc ám
				sprite.scale = base_scale
			if trail_particles:
				trail_particles.local_coords = false
				trail_particles.color = Color(1.1, 0.2, 1.8, 0.9)
				trail_particles.gravity = Vector2(0, -40.0)
				trail_particles.amount = 32
				trail_particles.scale_amount_min = 3.5
				trail_particles.scale_amount_max = 8.0

func shoot(direction: Vector2, speed: float, lifetime: float) -> void:
	fly_dir = direction
	rotation = direction.angle()
	var spd_mult := 1.0
	if element_type == 1:
		spd_mult = 1.35 # Lôi Vân bay siêu tốc
	apply_impulse(direction * speed * spd_mult)
	var life_tw := create_tween()
	life_tw.tween_interval(lifetime)
	life_tw.tween_callback(_on_lifetime_expired)

func _on_lifetime_expired() -> void:
	if not is_exploded:
		explode_aoe()
		queue_free()

func _on_body_entered(body: Node) -> void:
	if is_exploded: return
	if body.is_in_group("Player") or body.is_in_group("Bullet"): return
	
	var is_enemy = body.is_in_group("Enemy") or body is Enemy or body.is_in_group("Boss")
	
	if is_enemy and pierce_count > 0:
		pierce_count -= 1
		hit_targets.append(body)
		apply_single_target_damage(body)
		spawn_pierce_spark(global_position)
		return
		
	explode_aoe(body if is_enemy else null)
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

func explode_aoe(hit_body: Node = null) -> void:
	if is_exploded: return
	is_exploded = true
	
	var gm = get_node_or_null("/root/GameManager")
	var burst_color: Color = Color.WHITE
	var shake_power: float = 5.0
	
	match element_type:
		0: # 🌌 Tinh Vân: Tím vũ trụ
			burst_color = Color(2.4, 0.7, 3.4, 1.0)
			shake_power = 6.0
			_trigger_cosmic_pull(global_position)
		1: # ⚡ Lôi Vân: Xanh ngọc cực quang
			burst_color = Color(0.6, 2.8, 1.6, 1.0)
			shake_power = 5.5
			_trigger_chain_lightning(hit_body, global_position)
		2: # 🌑 Hư Không: Tím đen hắc ám
			burst_color = Color(1.3, 0.3, 2.2, 1.0)
			shake_power = 6.5
			_spawn_void_mire_pool(global_position)
			
	if is_giant_orb:
		shake_power = 12.0
		if is_inside_tree() and get_parent():
			var exp_sfx := AudioStreamPlayer2D.new()
			var stream_res = load("res://Assets/Sound/FX/explosion.wav")
			if stream_res:
				exp_sfx.stream = stream_res
				exp_sfx.bus = "sfx"
				exp_sfx.volume_db = 6.0
				exp_sfx.global_position = global_position
				get_parent().add_child(exp_sfx)
				exp_sfx.play()
				exp_sfx.finished.connect(exp_sfx.queue_free)
	
	if gm and gm.has_method("shake_camera"):
		gm.shake_camera(shake_power, 0.25 if is_giant_orb else 0.16)
		
	spawn_impact_shockwave(global_position, burst_color, aoe_radius)
	spawn_burst_vfx(global_position, burst_color)
	
	# Sát thương vụ nổ AoE
	if is_inside_tree() and get_tree():
		var enemies = get_tree().get_nodes_in_group("Enemy") + get_tree().get_nodes_in_group("Boss")
		for enemy in enemies:
			if is_instance_valid(enemy) and enemy is Node2D:
				var dist = global_position.distance_to(enemy.global_position)
				if dist <= aoe_radius:
					var kdir = (enemy.global_position - global_position).normalized()
					if kdir.length() == 0: kdir = Vector2.RIGHT
					if enemy.has_method("apply_element_effect"):
						enemy.apply_element_effect(element_type)
					if enemy.has_method("take_damage"):
						enemy.take_damage(damage, kdir)
					elif enemy.has_method("take_hit"):
						enemy.take_hit(kdir)

# --------- CƠ CHẾ 0: HỐ ĐEN KÉO HÚT QUÁI (COSMIC PULL) ---------- #
func _trigger_cosmic_pull(center_pos: Vector2) -> void:
	if not is_inside_tree() or not get_tree(): return
	var pull_radius := 115.0
	var enemies = get_tree().get_nodes_in_group("Enemy") + get_tree().get_nodes_in_group("Boss")
	for en in enemies:
		if is_instance_valid(en) and en is Node2D:
			var offset: Vector2 = center_pos - en.global_position
			var dist = offset.length()
			if dist <= pull_radius and dist > 5.0:
				var pull_dir = offset.normalized()
				if "velocity" in en:
					en.velocity += pull_dir * 320.0
				var tw = en.create_tween()
				tw.tween_property(en, "global_position", en.global_position + pull_dir * 35.0, 0.18)

# --------- CƠ CHẾ 1: SÉT CHUỖI GIẬT LAN (CHAIN LIGHTNING) ---------- #
func _trigger_chain_lightning(first_target: Node, origin: Vector2) -> void:
	if not is_inside_tree() or not get_tree(): return
	var enemies = get_tree().get_nodes_in_group("Enemy") + get_tree().get_nodes_in_group("Boss")
	var chained_count: int = 0
	var current_origin = first_target.global_position if (is_instance_valid(first_target) and first_target is Node2D) else origin
	
	for en in enemies:
		if chained_count >= 2: break
		if not is_instance_valid(en) or not (en is Node2D) or en == first_target: continue
		var dist = current_origin.distance_to(en.global_position)
		if dist <= 170.0:
			chained_count += 1
			_draw_lightning_bolt(current_origin, en.global_position)
			if en.has_method("apply_element_effect"):
				en.apply_element_effect(0) # Giật điện Stun
			if en.has_method("take_damage"):
				en.take_damage(damage * 0.75, (en.global_position - current_origin).normalized())

func _draw_lightning_bolt(from_pos: Vector2, to_pos: Vector2) -> void:
	if not get_parent(): return
	var line := Line2D.new()
	line.default_color = Color(0.6, 2.8, 1.8, 1.0)
	line.width = 4.0
	line.add_point(from_pos)
	var mid = (from_pos + to_pos) / 2.0 + Vector2(randf_range(-18, 18), randf_range(-18, 18))
	line.add_point(mid)
	line.add_point(to_pos)
	get_parent().add_child(line)
	var tw = line.create_tween()
	tw.tween_property(line, "modulate:a", 0.0, 0.16)
	tw.tween_callback(line.queue_free)

# --------- CƠ CHẾ 2: VŨNG LẦY HƯ KHÔNG (VOID MIRE POOL) ---------- #
func _spawn_void_mire_pool(center_pos: Vector2) -> void:
	if not get_parent() or not is_inside_tree(): return
	var pool = VoidPoolScript.new()
	get_parent().add_child(pool)
	pool.setup(center_pos)

func spawn_impact_shockwave(pos: Vector2, color: Color, max_r: float) -> void:
	if not is_inside_tree() or not get_parent(): return
	var ring = Sprite2D.new()
	ring.texture = load("res://Assets/Spritesheet/laser_bullet.png")
	ring.modulate = color
	ring.global_position = pos
	ring.scale = Vector2(0.1, 0.1)
	get_parent().add_child(ring)
	
	var tw = ring.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(ring, "scale", Vector2(max_r / 130.0, max_r / 130.0), 0.22)
	tw.parallel().tween_property(ring, "modulate:a", 0.0, 0.22)
	tw.tween_callback(ring.queue_free)

func spawn_burst_vfx(pos: Vector2, color: Color) -> void:
	if not is_inside_tree() or not get_parent(): return
	var p = CPUParticles2D.new()
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = 26 if not is_giant_orb else 50
	p.lifetime = 0.35
	p.spread = 180.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 80.0
	p.initial_velocity_max = 200.0 if not is_giant_orb else 320.0
	p.scale_amount_min = 3.0
	p.scale_amount_max = 7.0 if not is_giant_orb else 12.0
	p.color = color
	p.global_position = pos
	get_parent().add_child(p)
	p.emitting = true
	var tw = p.create_tween()
	tw.tween_interval(0.45)
	tw.tween_callback(p.queue_free)

func spawn_pierce_spark(pos: Vector2) -> void:
	if not is_inside_tree() or not get_parent(): return
	var sp = Sprite2D.new()
	sp.texture = load("res://Assets/Spritesheet/laser_bullet.png")
	sp.modulate = Color(2.5, 2.5, 2.5, 1.0)
	sp.scale = Vector2(0.18, 0.18)
	sp.global_position = pos
	get_parent().add_child(sp)
	var tw = sp.create_tween()
	tw.tween_property(sp, "scale", Vector2(0.35, 0.35), 0.08)
	tw.parallel().tween_property(sp, "modulate:a", 0.0, 0.08)
	tw.tween_callback(sp.queue_free)
