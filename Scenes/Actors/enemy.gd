class_name Enemy
extends CharacterBody2D

enum EnemyRank { NORMAL, ELITE }
enum SmartAIType { NONE, BOMBER, ROCK_THROWER }

@export var speed: float = 100.0
@export var direction: int = 1
@export var flip: bool = false
@export var hp: float = 100.0
@export var max_hp: float = 100.0

@export_category("Enemy Rank")
@export var rank: EnemyRank = EnemyRank.NORMAL
@export_range(1.0, 10.0, 0.25) var elite_hp_multiplier: float = 3.0
@export_range(0.0, 1.0, 0.01) var duplicate_hit_protection: float = 0.18

@export_category("Smart AI")
@export var smart_type: SmartAIType = SmartAIType.NONE

var alive: bool = true
var attack_cooldown_timer: float = 0.0
var last_hit_element: int = -1
var is_attacking: bool = false
var is_frozen: bool = false
var turn_cooldown: float = 0.0
var _duplicate_hit_timer: float = 0.0

# --- Biến điều khiển Smart AI ---
var is_fusing: bool = false
var fuse_timer: float = 0.0
var throw_cooldown_timer: float = 0.0
var is_throwing: bool = false
var is_smart_initialized: bool = false
var smart_badge: Node2D = null
var base_speed: float = 100.0
var active_burn_particles: CPUParticles2D = null
var active_ice_crystal: Sprite2D = null
var dot_tween: Tween = null
var freeze_tween: Tween = null


@onready var wall_ray: RayCast2D = $Sprite/Ray/wallRay if has_node("Sprite/Ray/wallRay") else null
@onready var player_ray: RayCast2D = $Sprite/Ray/playerRay if has_node("Sprite/Ray/playerRay") else null
@onready var floor_ray: RayCast2D = $Sprite/Ray/floorRay if has_node("Sprite/Ray/floorRay") else null

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	base_speed = speed
	apply_rank_stats()
	if smart_type != SmartAIType.NONE:
		setup_smart_ai(smart_type)
	if has_node("DeathParticles"):
		$DeathParticles.one_shot = true
	if direction > 0: direction = 1
	if direction < 0: direction = -1
	if has_node("HitArea"):
		if not $HitArea.area_entered.is_connected(_on_hit_area_area_entered):
			$HitArea.area_entered.connect(_on_hit_area_area_entered)
		if not $HitArea.body_entered.is_connected(_on_hit_area_body_entered):
			$HitArea.body_entered.connect(_on_hit_area_body_entered)

func apply_rank_stats() -> void:
	if rank == EnemyRank.ELITE:
		# Elite giữ nguyên sprite gốc, nhưng có lượng máu cao hơn quái thường.
		max_hp *= elite_hp_multiplier
		hp = max_hp
		add_to_group("Elite")
	elif hp <= 0.0 or hp > max_hp:
		hp = max_hp

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
	if _duplicate_hit_timer > 0.0:
		_duplicate_hit_timer -= delta

	if is_frozen:
		velocity.x = move_toward(velocity.x, 0, 450.0 * delta)
		move_and_slide()
		return

	if is_attacking:
		velocity.x = move_toward(velocity.x, 0, 450.0 * delta)
		move_and_slide()
		return


	if alive and is_on_floor():
		var player = get_player_node()
		
		# --- XỬ LÝ AI THÔNG MINH (SMART AI) ---
		if smart_type != SmartAIType.NONE and player and is_instance_valid(player):
			if _process_smart_ai(delta, player):
				move_and_slide()
				return
		
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
	var p_tw = p.create_tween()
	p_tw.tween_interval(0.35)
	p_tw.tween_callback(p.queue_free)

func play_attack_animation() -> void:
	pass

func take_damage(amount: float, knockback_dir: Vector2 = Vector2.RIGHT) -> void:
	if not alive or _duplicate_hit_timer > 0.0:
		return
	_duplicate_hit_timer = duplicate_hit_protection
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
		
	if element_val == 0: # GOLD / LIGHTNING STUN
		# Giật sét vàng và khựng đòn
		var spark := CPUParticles2D.new()
		spark.emitting = false
		spark.one_shot = true
		spark.explosiveness = 0.95
		spark.amount = 18
		spark.lifetime = 0.3
		spark.spread = 180.0
		spark.gravity = Vector2.ZERO
		spark.initial_velocity_min = 80.0
		spark.initial_velocity_max = 160.0
		spark.scale_amount_min = 2.5
		spark.scale_amount_max = 5.0
		spark.color = Color(2.5, 2.0, 0.4, 1.0)
		spark.global_position = global_position + Vector2(0, -20)
		if get_parent(): get_parent().add_child(spark)
		spark.emitting = true
		var spark_tw = spark.create_tween()
		spark_tw.tween_interval(0.4)
		spark_tw.tween_callback(spark.queue_free)
		
		if has_node("Sprite"):
			var tw = create_tween()
			tw.tween_property($Sprite, "modulate", Color(2.5, 2.2, 0.5, 1.0), 0.08)
			tw.tween_property($Sprite, "modulate", Color.WHITE, 0.12)
		velocity.x = -direction * 160.0
		
	elif element_val == 1: # FIRE BURN DOT
		if has_node("Sprite"):
			$Sprite.modulate = Color(3.2, 0.7, 0.15, 1.0)
		
		if is_instance_valid(active_burn_particles):
			active_burn_particles.queue_free()
		if dot_tween and dot_tween.is_valid():
			dot_tween.kill()
		
		active_burn_particles = CPUParticles2D.new()
		active_burn_particles.amount = 16
		active_burn_particles.lifetime = 0.35
		active_burn_particles.direction = Vector2(0, -1)
		active_burn_particles.spread = 35.0
		active_burn_particles.gravity = Vector2(0, -70)
		active_burn_particles.initial_velocity_min = 40.0
		active_burn_particles.initial_velocity_max = 90.0
		active_burn_particles.scale_amount_min = 3.0
		active_burn_particles.scale_amount_max = 6.0
		active_burn_particles.color = Color(3.5, 0.8, 0.1, 1.0)
		active_burn_particles.position = Vector2(0, -15)
		add_child(active_burn_particles)
		
		dot_tween = create_tween()
		dot_tween.tween_interval(0.5)
		dot_tween.tween_callback(_on_burn_tick)
		dot_tween.tween_interval(0.5)
		dot_tween.tween_callback(_on_burn_tick)
		dot_tween.tween_interval(0.5)
		dot_tween.tween_callback(_on_burn_end)
		
	elif element_val == 2: # ICE FREEZE SOLID (Đóng băng cứng đờ)
		is_frozen = true
		speed = 0.0
		if has_node("Sprite"):
			$Sprite.modulate = Color(0.4, 2.2, 3.5, 1.0)
		
		if is_instance_valid(active_ice_crystal):
			active_ice_crystal.queue_free()
		if freeze_tween and freeze_tween.is_valid():
			freeze_tween.kill()
		
		active_ice_crystal = Sprite2D.new()
		active_ice_crystal.texture = load("res://Assets/Spritesheet/laser_bullet.png")
		active_ice_crystal.modulate = Color(0.5, 2.2, 3.5, 0.85)
		active_ice_crystal.scale = Vector2(0.22, 0.45)
		active_ice_crystal.position = Vector2(0, -20)
		add_child(active_ice_crystal)
		
		freeze_tween = create_tween()
		freeze_tween.tween_interval(1.5)
		freeze_tween.tween_callback(_on_freeze_end)

func _on_burn_tick() -> void:
	if not alive: return
	hp -= 15.0
	if has_node("Sprite"):
		var tw = create_tween()
		tw.tween_property($Sprite, "modulate", Color(3.5, 1.2, 0.3, 1.0), 0.06)
		tw.tween_property($Sprite, "modulate", Color(2.8, 0.5, 0.1, 1.0), 0.1)
	if hp <= 0:
		take_hit()

func _on_burn_end() -> void:
	if is_instance_valid(active_burn_particles):
		active_burn_particles.queue_free()
		active_burn_particles = null
	if alive and has_node("Sprite"):
		$Sprite.modulate = Color.WHITE

func _on_freeze_end() -> void:
	if is_instance_valid(active_ice_crystal):
		active_ice_crystal.queue_free()
		active_ice_crystal = null
	if alive:
		_spawn_ice_shatter_fx()
		speed = base_speed
		is_frozen = false
		if has_node("Sprite"):
			$Sprite.modulate = Color.WHITE

func _spawn_ice_shatter_fx() -> void:
	if not is_inside_tree() or not get_parent(): return
	var shatter := CPUParticles2D.new()
	shatter.emitting = false
	shatter.one_shot = true
	shatter.explosiveness = 0.95
	shatter.amount = 18
	shatter.lifetime = 0.3
	shatter.spread = 180.0
	shatter.gravity = Vector2(0, 80)
	shatter.initial_velocity_min = 60.0
	shatter.initial_velocity_max = 150.0
	shatter.scale_amount_min = 2.5
	shatter.scale_amount_max = 5.0
	shatter.color = Color(0.6, 2.2, 3.5, 1.0)
	shatter.global_position = global_position + Vector2(0, -20)
	get_parent().add_child(shatter)
	shatter.emitting = true
	var sh_tw = shatter.create_tween()
	sh_tw.tween_interval(0.4)
	sh_tw.tween_callback(shatter.queue_free)


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
	if dot_tween and dot_tween.is_valid():
		dot_tween.kill()
	if freeze_tween and freeze_tween.is_valid():
		freeze_tween.kill()
	if is_instance_valid(active_burn_particles):
		active_burn_particles.queue_free()
		active_burn_particles = null
	if is_instance_valid(active_ice_crystal):
		active_ice_crystal.queue_free()
		active_ice_crystal = null
	if is_fusing:
		is_fusing = false
	if smart_badge and is_instance_valid(smart_badge):
		smart_badge.visible = false
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
	var tw = p.create_tween()
	tw.tween_interval(0.6)
	tw.tween_callback(p.queue_free)


# ========================================================================= #
#          HỆ THỐNG AI THÔNG MINH (SMART AI SYSTEM CHO QUÁI NPC)            #
# ========================================================================= #

func setup_smart_ai(stype: SmartAIType) -> void:
	smart_type = stype
	if smart_type == SmartAIType.NONE:
		return
	is_smart_initialized = true
	add_to_group("SmartEnemy")
	
	match smart_type:
		SmartAIType.BOMBER:
			max_hp *= 1.3
			hp = max_hp
			speed = base_speed * 1.35
			_create_smart_badge("💣", Color(1.0, 0.25, 0.2, 1.0))
			if has_node("Sprite"):
				$Sprite.modulate = Color(1.35, 0.65, 0.65, 1.0)
				
		SmartAIType.ROCK_THROWER:
			max_hp *= 1.25
			hp = max_hp
			speed = base_speed * 0.95
			throw_cooldown_timer = randf_range(1.2, 2.0)
			_create_smart_badge("🪨", Color(1.0, 0.85, 0.35, 1.0))
			if has_node("Sprite"):
				$Sprite.modulate = Color(1.25, 1.05, 0.7, 1.0)

func _create_smart_badge(text_icon: String, badge_color: Color) -> void:
	if smart_badge and is_instance_valid(smart_badge):
		smart_badge.queue_free()
		
	smart_badge = Node2D.new()
	smart_badge.name = "SmartBadge"
	smart_badge.position = Vector2(0, -70.0)
	add_child(smart_badge)
	
	var label := Label.new()
	label.name = "Label"
	label.text = text_icon
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.offset_left = -20
	label.offset_top = -14
	label.offset_right = 20
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", badge_color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	smart_badge.add_child(label)
	
	# Hiệu ứng nảy nhịp nhàng trên đầu quái
	var tw = smart_badge.create_tween().set_loops()
	tw.tween_property(smart_badge, "position:y", -76.0, 0.55).set_trans(Tween.TRANS_SINE)
	tw.tween_property(smart_badge, "position:y", -68.0, 0.55).set_trans(Tween.TRANS_SINE)

func _process_smart_ai(delta: float, player: Node2D) -> bool:
	if not is_instance_valid(player) or not alive or is_frozen or is_attacking:
		return false
		
	var dist: float = global_position.distance_to(player.global_position)
	var dy: float = abs(global_position.y - player.global_position.y)
	var dir_to_player: int = 1 if player.global_position.x >= global_position.x else -1
	
	match smart_type:
		SmartAIType.BOMBER:
			if is_fusing:
				fuse_timer -= delta
				# Toàn thân phình to, co giãn nhấp nháy đỏ rực liên tục
				var pulse = sin((0.8 - fuse_timer) * 35.0) * 0.22
				if has_node("Sprite"):
					$Sprite.scale = Vector2(-1.0 if flip else 1.0, 1.0) * (1.15 + pulse)
					var flash_c = Color(3.8, 0.3, 0.2, 1.0) if int(fuse_timer * 18.0) % 2 == 0 else Color(2.5, 2.5, 2.5, 1.0)
					$Sprite.modulate = flash_c
				velocity.x = move_toward(velocity.x, 0.0, 300.0 * delta)
				
				if fuse_timer <= 0.0:
					trigger_kamikaze_explosion()
				return true
				
			# Nếu phát hiện người chơi trong bán kính 360px
			if dist <= 360.0 and dy <= 160.0:
				direction = dir_to_player
				flip = (direction > 0)
				if has_node("Sprite"): $Sprite.scale.x = -1 if flip else 1
				
				# Quái cảm tử kích hoạt đếm ngược nổ khi tới gần (<= 65px) hoặc máu còn dưới 35%
				if dist <= 65.0 or hp <= max_hp * 0.35:
					start_bomber_fuse()
					return true
					
				# Lao dũng mãnh tới người chơi
				velocity.x = direction * speed * 1.35
				return true
				
		SmartAIType.ROCK_THROWER:
			if throw_cooldown_timer > 0.0:
				throw_cooldown_timer -= delta
				
			if is_throwing:
				velocity.x = 0.0
				return true
				
			# Nếu người chơi áp sát quá gần (< 90px): KITING! Lùi lại để giữ khoảng cách ném đá!
			if dist < 90.0 and dy <= 80.0:
				direction = -dir_to_player # Lùi ngược lại người chơi
				flip = (direction > 0)
				if has_node("Sprite"): $Sprite.scale.x = -1 if flip else 1
				
				# Nếu chạm tường hoặc hết sàn khi lùi -> tấn công cận chiến
				if is_on_wall() or (floor_ray and not floor_ray.is_colliding()):
					direction = dir_to_player
					if attack_cooldown_timer <= 0.0:
						perform_attack_on_player(player)
					velocity.x = 0.0
				else:
					velocity.x = direction * speed * 1.05
				return true
				
			# Nếu người chơi ở cự ly ném đá (100px - 440px)
			if dist <= 440.0 and dy <= 200.0:
				direction = dir_to_player
				flip = (direction > 0)
				if has_node("Sprite"): $Sprite.scale.x = -1 if flip else 1
				velocity.x = 0.0
				
				if throw_cooldown_timer <= 0.0 and not is_attacking:
					perform_rock_throw(player)
				return true
				
	return false

func start_bomber_fuse() -> void:
	if is_fusing or not alive: return
	is_fusing = true
	fuse_timer = 0.80
	
	# Cảnh báo biểu tượng nổ nảy lên
	if smart_badge:
		var lbl = smart_badge.get_node_or_null("Label")
		if lbl: lbl.text = "💥"
		var btw = smart_badge.create_tween()
		btw.tween_property(smart_badge, "scale", Vector2(1.5, 1.5), 0.1)
		
	# Hạt tia lửa xèo xèo ngòi nổ
	var fuse_sparks := CPUParticles2D.new()
	fuse_sparks.name = "FuseSparks"
	fuse_sparks.amount = 18
	fuse_sparks.lifetime = 0.25
	fuse_sparks.spread = 180.0
	fuse_sparks.gravity = Vector2(0, -60)
	fuse_sparks.initial_velocity_min = 30.0
	fuse_sparks.initial_velocity_max = 80.0
	fuse_sparks.scale_amount_min = 2.0
	fuse_sparks.scale_amount_max = 4.0
	fuse_sparks.color = Color(3.5, 1.5, 0.2, 1.0)
	fuse_sparks.position = Vector2(0, -50.0)
	add_child(fuse_sparks)
	
	if has_node("DeathSfx"):
		$DeathSfx.pitch_scale = 1.8
		$DeathSfx.play()

func trigger_kamikaze_explosion() -> void:
	if not alive: return
	alive = false
	collision_layer = 0
	
	var origin: Vector2 = global_position + Vector2(0, -25.0)
	var blast_radius: float = 105.0
	var blast_damage: int = 35
	
	# 1. VFX Sóng xung kích nổ
	if get_parent():
		var ring := Sprite2D.new()
		var laser_tex = load("res://Assets/Spritesheet/laser_bullet.png")
		if laser_tex: ring.texture = laser_tex
		ring.global_position = origin
		ring.modulate = Color(3.8, 1.2, 0.2, 1.0)
		ring.scale = Vector2(0.1, 0.1)
		get_parent().add_child(ring)
		var rtw = ring.create_tween()
		rtw.parallel().tween_property(ring, "scale", Vector2(0.65, 0.65), 0.22).set_ease(Tween.EASE_OUT)
		rtw.parallel().tween_property(ring, "modulate:a", 0.0, 0.25)
		rtw.tween_callback(ring.queue_free)
		
		# Hạt lửa bùng nổ tung tóe
		var boom_p := CPUParticles2D.new()
		boom_p.emitting = false
		boom_p.one_shot = true
		boom_p.explosiveness = 0.95
		boom_p.amount = 32
		boom_p.lifetime = 0.45
		boom_p.spread = 180.0
		boom_p.gravity = Vector2(0, 120.0)
		boom_p.initial_velocity_min = 100.0
		boom_p.initial_velocity_max = 240.0
		boom_p.scale_amount_min = 3.5
		boom_p.scale_amount_max = 7.5
		boom_p.color = Color(3.8, 0.9, 0.15, 1.0)
		boom_p.global_position = origin
		get_parent().add_child(boom_p)
		boom_p.emitting = true
		var tw = boom_p.create_tween()
		tw.tween_interval(0.5)
		tw.tween_callback(boom_p.queue_free)
		
	# 2. Rung màn hình chân thực
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.has_method("shake_camera"):
		gm.shake_camera(7.5, 0.22)
		
	# 3. Gây sát thương nổ & knockback cho người chơi
	var player = get_player_node()
	if player and is_instance_valid(player):
		var dist = origin.distance_to(player.global_position)
		if dist <= blast_radius:
			if gm and gm.has_method("damage"):
				gm.damage(blast_damage)
			if player.has_method("damage_tween"):
				player.damage_tween()
			if "velocity" in player:
				var kdir = (player.global_position - origin).normalized()
				if kdir.length() == 0: kdir = Vector2.UP
				player.velocity = kdir * 420.0 + Vector2(0, -180.0)
				
	# 4. Âm thanh nổ
	if has_node("DeathSfx"):
		$DeathSfx.pitch_scale = 0.75
		$DeathSfx.play()
		
	# 5. Xóa quái vật
	if has_node("Sprite"):
		$Sprite.visible = false
	if smart_badge:
		smart_badge.visible = false
	await get_tree().create_timer(0.35).timeout
	queue_free()

func perform_rock_throw(player: Node2D) -> void:
	if is_throwing or not alive or not is_inside_tree(): return
	is_throwing = true
	
	# Nhún người chuẩn bị ném (Wind-up feedback)
	if has_node("Sprite"):
		var tw = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property($Sprite, "scale:y", 0.75, 0.12)
		tw.tween_property($Sprite, "scale:y", 1.25, 0.10)
		tw.tween_property($Sprite, "scale:y", 1.0, 0.08)
		
	await get_tree().create_timer(0.22).timeout
	if not alive or not is_inside_tree():
		is_throwing = false
		return
	
	# Spawn và phóng hòn đá
	var rock_scene = load("res://Scenes/Prefabs/rock_projectile.tscn")
	if rock_scene and get_parent():
		var rock = rock_scene.instantiate()
		var spawn_pos = global_position + Vector2(direction * 18.0, -32.0)
		get_parent().add_child(rock)
		if rock.has_method("launch"):
			var target_pos = player.global_position if is_instance_valid(player) else (spawn_pos + Vector2(direction * 220.0, 0))
			rock.launch(spawn_pos, target_pos)
			
	# Âm thanh ném
	if has_node("DeathSfx"):
		$DeathSfx.pitch_scale = randf_range(1.4, 1.6)
		$DeathSfx.play()
		
	throw_cooldown_timer = randf_range(2.0, 2.7)
	is_throwing = false

