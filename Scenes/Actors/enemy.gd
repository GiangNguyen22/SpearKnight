class_name Enemy
extends CharacterBody2D

@export var speed: float = 100.0
@export var direction: int = 1
@export var flip: bool = false
@export var hp: float = 100.0
@export var max_hp: float = 100.0

var alive: bool = true
var attack_cooldown_timer: float = 0.0
var last_hit_element: int = -1
var is_attacking: bool = false
var turn_cooldown: float = 0.0

@onready var wall_ray: RayCast2D = $Sprite/Ray/wallRay if has_node("Sprite/Ray/wallRay") else null
@onready var player_ray: RayCast2D = $Sprite/Ray/playerRay if has_node("Sprite/Ray/playerRay") else null
@onready var floor_ray: RayCast2D = $Sprite/Ray/floorRay if has_node("Sprite/Ray/floorRay") else null

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if has_node("DeathParticles"):
		$DeathParticles.one_shot = true
	if direction > 0: direction = 1
	if direction < 0: direction = -1
	if has_node("HitArea"):
		if not $HitArea.area_entered.is_connected(_on_hit_area_area_entered):
			$HitArea.area_entered.connect(_on_hit_area_area_entered)
		if not $HitArea.body_entered.is_connected(_on_hit_area_body_entered):
			$HitArea.body_entered.connect(_on_hit_area_body_entered)

func _process(_delta: float) -> void:
	if is_attacking:
		return
	if flip:
		if has_node("Sprite"): $Sprite.scale.x = -1
	else:
		if has_node("Sprite"): $Sprite.scale.x = 1

func _physics_process(delta: float) -> void:
	if not is_on_floor() or not alive:
		velocity += get_gravity() * delta

	if attack_cooldown_timer > 0:
		attack_cooldown_timer -= delta

	if turn_cooldown > 0:
		turn_cooldown -= delta

	if is_attacking:
		velocity.x = move_toward(velocity.x, 0, 450.0 * delta)
		move_and_slide()
		return

	if alive and is_on_floor():
		var player = get_player_node()
		var player_detected = false
		if player_ray and player_ray.is_colliding():
			var col = player_ray.get_collider()
			if col and (col.is_in_group("Player") or col is Player):
				player_detected = true
		
		# Nếu gặp bẫy phía trước khi tuần tra -> thông minh quay đầu lại, không tự sát!
		if is_trap_ahead() and turn_cooldown <= 0:
			direction = -direction
			turn_cooldown = 0.4
		# Nếu phát hiện người chơi ở tầm mắt, tự động quay hướng về người chơi
		elif player_detected and player:
			found_player(player.global_position)
			if global_position.distance_to(player.global_position) <= 50.0 and attack_cooldown_timer <= 0:
				perform_attack_on_player(player)
		# Nếu va tường, gặp raycast tường hoặc hết sàn -> lập tức quay đầu mượt mà
		elif turn_cooldown <= 0 and (is_on_wall() or (wall_ray and wall_ray.is_colliding()) or (floor_ray and !floor_ray.is_colliding())):
			direction = -direction
			turn_cooldown = 0.4
			
		velocity.x = speed * direction
	elif not alive:
		velocity.x = move_toward(velocity.x, 0, 350.0 * delta)
	else:
		velocity.x = 0
	
	if direction < 0: flip = false
	if direction > 0: flip = true
	
	move_and_slide()

func is_trap_ahead() -> bool:
	if has_node("HitArea"):
		var bodies = $HitArea.get_overlapping_bodies()
		for b in bodies:
			if b.is_in_group("Traps"):
				return true
	return false

func get_player_node() -> Node2D:
	var gm = get_node_or_null("/root/GameManager")
	if gm and "player" in gm and gm.player and is_instance_valid(gm.player):
		return gm.player
	return null

func found_player(target_pos: Vector2) -> void:
	if position.x > target_pos.x: direction = -1
	if position.x < target_pos.x: direction = 1

func _on_hit_area_body_entered(body: Node2D) -> void:
	if not alive: return
	
	# Chỉ chết vì bẫy nếu bị người chơi đánh bật lùi / bắn ngã vào bẫy
	if body.is_in_group("Traps") and (not is_on_floor() or abs(velocity.x) > 120.0):
		death_tween()
		return
		
	if body.is_in_group("Bullet"):
		if body.has_method("apply_single_target_damage") and "pierce_count" in body and body.pierce_count > 0:
			body.pierce_count -= 1
			body.apply_single_target_damage(self)
			if body.has_method("spawn_pierce_spark"):
				body.spawn_pierce_spark(global_position)
			return
		elif body.has_method("explode_aoe"):
			body.explode_aoe()
			body.queue_free()
			return
			
		var kdir = Vector2.RIGHT
		if "linear_velocity" in body:
			kdir = Vector2.RIGHT if body.linear_velocity.x >= 0 else Vector2.LEFT
		elif "velocity" in body:
			kdir = Vector2.RIGHT if body.velocity.x >= 0 else Vector2.LEFT
		
		if "element_type" in body:
			last_hit_element = body.element_type
			apply_element_effect(body.element_type)
		take_hit(kdir)
		body.queue_free()
		return
		
	if body.is_in_group("Player") or body is Player:
		perform_attack_on_player(body)

func perform_attack_on_player(player_node: Node2D) -> void:
	if not alive or attack_cooldown_timer > 0 or is_attacking:
		return
	is_attacking = true
	attack_cooldown_timer = 1.1 # Thời gian giãn cách giữa các đòn đánh của quái
	
	var dir_to_player = 1 if player_node.global_position.x >= global_position.x else -1
	direction = dir_to_player
	flip = (direction > 0)
	if has_node("Sprite"):
		$Sprite.scale.x = -1 if flip else 1
		
	# Đứng vững trên sàn, chỉ lướt nhẹ một nhịp tới trước (KHÔNG nhảy lên trời)
	velocity.x = dir_to_player * 140.0
	velocity.y = 0.0
	
	# Phát hoạt ảnh vung vũ khí / cào cắn thực sự của quái
	if has_method("play_attack_animation"):
		play_attack_animation()
	elif has_node("Sprite"):
		var tw = create_tween()
		tw.tween_property($Sprite, "scale:x", ($Sprite.scale.x * 1.3), 0.1)
		tw.tween_property($Sprite, "scale:x", ($Sprite.scale.x), 0.15)
		
	# Phát âm thanh quái vung đòn
	if has_node("DeathSfx"):
		$DeathSfx.pitch_scale = randf_range(1.35, 1.55)
		$DeathSfx.play()
		
	# Chờ 0.12s vung vũ khí chạm tới đích
	if is_inside_tree() and get_tree():
		await get_tree().create_timer(0.12).timeout
		
	if is_instance_valid(self) and alive:
		# Sinh hiệu ứng vết chém / móng vuốt đỏ rực to rõ nét
		spawn_attack_claw_vfx(player_node.global_position + Vector2(0, -32), float(dir_to_player))
		
		# Gây sát thương và giật lùi người chơi
		if is_instance_valid(player_node) and player_node.has_method("on_hit_by_enemy"):
			player_node.on_hit_by_enemy(self)
			
	# Kết thúc trạng thái vung đòn sau 0.4s
	if is_inside_tree() and get_tree():
		await get_tree().create_timer(0.35).timeout
	is_attacking = false

func spawn_attack_claw_vfx(hit_pos: Vector2, dir_x: float) -> void:
	if not is_inside_tree() or not get_parent():
		return
		
	# 1. Vệt chém bán nguyệt quái vật hung hãn
	var slash = Sprite2D.new()
	var slash_tex = load("res://Assets/Spritesheet/spear_slash_fx.png") if ResourceLoader.exists("res://Assets/Spritesheet/spear_slash_fx.png") else load("res://Assets/Spritesheet/melee_hit_spark.png")
	slash.texture = slash_tex
	slash.global_position = hit_pos
	slash.scale = Vector2(0.12 * dir_x, 0.12)
	slash.modulate = Color(3.2, 0.35, 0.15, 1.0) # Vệt chém đỏ lửa hung hãn
	slash.rotation = randf_range(-0.3, 0.3)
	get_parent().add_child(slash)
	
	var tw = slash.create_tween()
	tw.tween_property(slash, "scale", Vector2(0.24 * dir_x, 0.24), 0.15).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(slash, "modulate:a", 0.0, 0.20)
	tw.tween_callback(slash.queue_free)
	
	# 2. Hạt tia lửa va chạm đỏ rực
	var p = CPUParticles2D.new()
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 0.95
	p.local_coords = false
	p.amount = 16
	p.lifetime = 0.28
	p.spread = 180.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 70.0
	p.initial_velocity_max = 160.0
	p.scale_amount_min = 2.5
	p.scale_amount_max = 5.0
	p.color = Color(3.0, 0.3, 0.15, 1.0)
	p.global_position = hit_pos
	get_parent().add_child(p)
	p.emitting = true
	if is_inside_tree() and get_tree():
		get_tree().create_timer(0.35).timeout.connect(p.queue_free)

func play_attack_animation() -> void:
	pass

func take_damage(amount: float, knockback_dir: Vector2 = Vector2.RIGHT) -> void:
	if not alive:
		return
	hp -= amount
	if hp <= 0:
		take_hit(knockback_dir)
	else:
		velocity = knockback_dir * 180.0 + Vector2(0, -100.0)
		if has_node("Sprite"):
			var tw = create_tween()
			tw.tween_property($Sprite, "modulate", Color(2.5, 0.4, 0.4, 1.0), 0.08)
			tw.tween_property($Sprite, "modulate", Color.WHITE, 0.08)

func apply_element_effect(element_val: int) -> void:
	if not alive:
		return
	last_hit_element = element_val
	hp -= 35.0
	if hp <= 0:
		take_hit(Vector2.RIGHT if direction < 0 else Vector2.LEFT)
		return
		
	if element_val == 1: # FIRE
		if has_node("Sprite"):
			$Sprite.modulate = Color(2.5, 0.5, 0.2)
	elif element_val == 2: # ICE
		speed = speed * 0.4
		if has_node("Sprite"):
			$Sprite.modulate = Color(0.4, 1.2, 2.0)
		get_tree().create_timer(2.0).timeout.connect(func():
			if is_instance_valid(self) and alive:
				speed = 100.0
				if has_node("Sprite"):
					$Sprite.modulate = Color.WHITE
		)

func _on_hit_area_area_entered(area: Area2D) -> void:
	if not alive:
		return
	if area.is_in_group("MeleeAttack"):
		var p_node = area.owner if area.owner else area.get_parent()
		# Chỉ nhận sát thương khi người chơi ĐANG THỰC SỰ VUNG VŨ KHÍ
		if p_node and "is_slash_active" in p_node and not p_node.is_slash_active:
			return
		last_hit_element = -1
		var kdir = Vector2.RIGHT if area.global_position.x <= global_position.x else Vector2.LEFT
		take_damage(40.0, kdir)

func take_hit(knockback_dir: Vector2 = Vector2.RIGHT) -> void:
	if not alive:
		return
	alive = false
	collision_layer = 0
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.has_method("add_score"):
		gm.add_score()
		
	# Gia tốc văng chân thực xuôi theo hướng đòn đánh
	velocity = knockback_dir * 320.0 + Vector2(0, -180.0)
	
	# Spawn hiệu ứng văng hạt chân thực theo hướng đòn đánh và nguyên tố
	spawn_death_fx(knockback_dir)
	
	if has_node("Sprite"):
		var tween = create_tween()
		tween.tween_property($Sprite, "modulate", Color(2.0, 0.3, 0.3, 1.0), 0.08)
		tween.parallel().tween_property($Sprite, "scale", Vector2.ZERO, 0.35).set_ease(Tween.EASE_IN)
		tween.parallel().tween_property($Sprite, "rotation", knockback_dir.x * 1.5, 0.35)
	
	if has_node("DeathSfx"):
		$DeathSfx.pitch_scale = randf_range(0.95, 1.15)
		$DeathSfx.play()
		
	await get_tree().create_timer(0.4).timeout
	queue_free()

func death_tween() -> void:
	take_hit(Vector2.UP)

func spawn_death_fx(kdir: Vector2) -> void:
	if not is_inside_tree() or not get_parent():
		return
	var p = CPUParticles2D.new()
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 0.95
	p.local_coords = false
	p.amount = 22
	p.lifetime = 0.55
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 10.0
	
	# Hướng văng tự nhiên theo lực đòn đánh
	p.direction = (kdir + Vector2(0, -0.45)).normalized()
	p.spread = 55.0
	p.gravity = Vector2(0, 380.0)
	p.initial_velocity_min = 120.0
	p.initial_velocity_max = 260.0
	p.scale_amount_min = 2.5
	p.scale_amount_max = 5.0
	
	# Giữ nguyên màu đỏ gốc như ban đầu
	p.color = Color(0.671534, 0.004919853, 0, 1)
			
	p.global_position = global_position + Vector2(0, -20)
	get_parent().add_child(p)
	p.emitting = true
	if is_inside_tree() and get_tree():
		get_tree().create_timer(0.6).timeout.connect(p.queue_free)
