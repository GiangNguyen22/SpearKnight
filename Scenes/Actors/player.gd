class_name Player
extends CharacterBody2D

signal hit_enemy
signal hit_trap 


# --------- VARIABLES ---------- #

@export_category("Player Properties")
@export var move_speed : float = 300
@export var jump_force : float = 680
@export var gravity : float = 30
@export var max_jump_count : int = 2

@export_category("Combat Properties")
@export var melee_cooldown_time : float = 0.35
@export var lunge_force : float = 120.0
@export var player_recoil_force : float = 70.0

@export_category("Dash & Mobility")
@export var dash_speed : float = 800.0
@export var dash_duration : float = 0.2
@export var dash_cooldown : float = 1.0
@export var wall_slide_speed : float = 60.0
@export var wall_jump_force : Vector2 = Vector2(450.0, -650.0)

var jump_count : int = 2

@export_category("Toggle Functions")
@export var double_jump : bool = true

var is_grounded : bool = false
var movement_enabled : bool = true
var spawn_point = Vector2(0,0)
var is_attacking = false
var attack_cooldown_timer = 0.0
var can_damage = true
var is_slash_active = false
var facing_direction : int = 1 # 1 = Phải, -1 = Trái

var is_dashing : bool = false
var dash_timer : float = 0.0
var dash_cooldown_timer : float = 0.0
var dash_direction : float = 1.0
var ghost_timer : float = 0.0
var is_wall_sliding : bool = false

var current_element : int = 0 # 0 = NORMAL, 1 = FIRE, 2 = ICE
@export var bullet_scene : PackedScene
@export var bullet_lifetime : float = 1.5

# --- Nodes ---
@onready var player_sprite : AnimatedSprite2D = $student/AnimatedSprite2D
@onready var player_node = $student
@onready var particle_trails = $ParticleTrails
@onready var death_particles = $DeathParticles
@onready var melee_area : Area2D = $student/MeleeArea if has_node("student/MeleeArea") else null
@onready var slash_vfx : Sprite2D = $student/SlashVFX if has_node("student/SlashVFX") else null
@onready var hit_spark : Sprite2D = $student/HitSpark if has_node("student/HitSpark") else null
@onready var swing_sfx : AudioStreamPlayer2D = $student/SwingSfx if has_node("student/SwingSfx") else null
@onready var hit_sfx : AudioStreamPlayer2D = $student/HitSfx if has_node("student/HitSfx") else null
@onready var camera_node : Camera2D = $Camera2D if has_node("Camera2D") else null

# --------- BUILT-IN FUNCTIONS ---------- #
var _default_knight_frames: SpriteFrames = null

func _ready() -> void:
	spawn_point = global_position
	var gm = get_node_or_null("/root/GameManager")
	if gm and "save_player_position" in gm and gm.save_player_position.x != 0:
		global_position = gm.save_player_position
		gm.save_player_position = Vector2.ZERO
	if player_sprite:
		if _default_knight_frames == null:
			_default_knight_frames = player_sprite.sprite_frames
		player_sprite.animation_finished.connect(_on_animation_finished)
	if melee_area:
		melee_area.body_entered.connect(_on_melee_body_entered)
		melee_area.area_entered.connect(_on_melee_area_entered)
	apply_class_config()


var _class_frames_cache: Dictionary = {}

func _get_class_sprite_frames(cid: String) -> SpriteFrames:
	if _class_frames_cache.has(cid):
		return _class_frames_cache[cid]
		
	var sf := SpriteFrames.new()
	match cid:
		"mage":
			sf.add_animation("Idle")
			sf.set_animation_loop("Idle", true)
			sf.set_animation_speed("Idle", 10.0)
			for i in range(10):
				var tex = load("res://Assets/Spritesheet/fairy/Fairy_03__IDLE_%03d.png" % i)
				if tex: sf.add_frame("Idle", tex)
				
			sf.add_animation("Walk")
			sf.set_animation_loop("Walk", true)
			sf.set_animation_speed("Walk", 15.0)
			for i in range(10):
				var tex = load("res://Assets/Spritesheet/fairy/Fairy_03__WALK_%03d.png" % i)
				if tex: sf.add_frame("Walk", tex)
				
			sf.add_animation("Jump")
			sf.set_animation_loop("Jump", true)
			sf.set_animation_speed("Jump", 12.0)
			for i in range(10):
				var tex = load("res://Assets/Spritesheet/fairy/Fairy_03__JUMP_%03d.png" % i)
				if tex: sf.add_frame("Jump", tex)
				
			sf.add_animation("Attack")
			sf.set_animation_loop("Attack", false)
			sf.set_animation_speed("Attack", 20.0)
			for i in range(10):
				var tex = load("res://Assets/Spritesheet/fairy/Fairy_03__ATTACK_%03d.png" % i)
				if tex: sf.add_frame("Attack", tex)
				
		"archer":
			var tex_girl = load("res://Assets/Spritesheet/archer/girl_archer.png")
			if tex_girl:
				sf.add_animation("Idle")
				sf.add_frame("Idle", tex_girl)
				sf.add_animation("Walk")
				sf.add_frame("Walk", tex_girl)
				sf.add_animation("Jump")
				sf.add_frame("Jump", tex_girl)
				sf.add_animation("Attack")
				sf.set_animation_loop("Attack", false)
				sf.add_frame("Attack", tex_girl)

	_class_frames_cache[cid] = sf
	return sf


func apply_class_config() -> void:
	var gm = get_node_or_null("/root/GameManager")
	var cid: String = gm.selected_character_id if gm and "selected_character_id" in gm else "knight"
	
	var weapon_spear = get_node_or_null("student/WeaponSpear")
	var weapon_staff = get_node_or_null("student/WeaponStaff")
	var weapon_bow = get_node_or_null("student/WeaponBow")
	var skeleton_node = get_node_or_null("student/Skeleton2D")
	var anim_player = get_node_or_null("student/AnimationPlayer")
	var light_w = get_node_or_null("LightW")
	
	if skeleton_node:
		skeleton_node.visible = (cid == "knight")
	if anim_player:
		if cid != "knight":
			anim_player.stop()
		else:
			anim_player.play("Idle")
	if light_w:
		light_w.visible = false
	
	match cid:
		"knight":
			move_speed = 300.0
			var b_tscn = load("res://Scenes/Prefabs/bullet.tscn")
			if b_tscn: bullet_scene = b_tscn
			if player_sprite:
				if _default_knight_frames:
					player_sprite.sprite_frames = _default_knight_frames
				player_sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
				player_sprite.scale = Vector2(0.2, 0.2)
				player_sprite.position = Vector2(-34, -36)
			if weapon_spear: weapon_spear.visible = false
			if weapon_staff: weapon_staff.visible = false
			if weapon_bow: weapon_bow.visible = false
			if slash_vfx: slash_vfx.modulate = Color(1.8, 1.4, 0.4, 1.0)
		"mage":
			move_speed = 280.0
			var b_tscn = load("res://Scenes/Prefabs/bullet_mage.tscn") if ResourceLoader.exists("res://Scenes/Prefabs/bullet_mage.tscn") else load("res://Scenes/Prefabs/bullet.tscn")
			if b_tscn: bullet_scene = b_tscn
			if player_sprite:
				var m_frames = _get_class_sprite_frames("mage")
				if m_frames and m_frames.has_animation("Idle"):
					player_sprite.sprite_frames = m_frames
				player_sprite.modulate = Color(1.2, 0.8, 1.8, 1.0)
				player_sprite.scale = Vector2(0.2, 0.2)
				player_sprite.position = Vector2(5, -56)
			if weapon_spear: weapon_spear.visible = false
			if weapon_staff: weapon_staff.visible = false
			if weapon_bow: weapon_bow.visible = false
			if slash_vfx: slash_vfx.modulate = Color(2.0, 0.5, 2.2, 1.0)
		"archer":
			move_speed = 345.0
			var b_tscn = load("res://Scenes/Prefabs/bullet_archer.tscn") if ResourceLoader.exists("res://Scenes/Prefabs/bullet_archer.tscn") else load("res://Scenes/Prefabs/bullet.tscn")
			if b_tscn: bullet_scene = b_tscn
			if player_sprite:
				var a_frames = _get_class_sprite_frames("archer")
				if a_frames and a_frames.has_animation("Idle"):
					player_sprite.sprite_frames = a_frames
				player_sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
				player_sprite.scale = Vector2(0.12, 0.12)
				player_sprite.position = Vector2(0, -42)
			if weapon_spear: weapon_spear.visible = false
			if weapon_staff: weapon_staff.visible = false
			if weapon_bow: weapon_bow.visible = false
			if slash_vfx: slash_vfx.modulate = Color(0.4, 2.0, 0.8, 1.0)

func _physics_process(delta):
	is_grounded = is_on_floor()
	if is_dashing:
		process_dash(delta)
		return
	
	if dash_cooldown_timer > 0:
		dash_cooldown_timer -= delta
		
	handle_dash_input()
	movement(delta)
	check_enemy_collisions()

func _process(_delta):
	player_animations()
	flip_player()
	handle_element_switch()
	handle_attack()
	if attack_cooldown_timer > 0:
		attack_cooldown_timer -= _delta

func handle_element_switch():
	if Input.is_action_just_pressed("SwitchElement"):
		current_element = (current_element + 1) % 3
		var elem_names = ["Hoàng Kim", "Hỏa Phép (Lửa)", "Băng Phép (Băng)"]
		var ui = get_tree().current_scene.get_node_or_null("UserInterface")
		if ui and ui.has_method("alert"):
			ui.alert("Sóng Thương: " + elem_names[current_element])

# --------- CUSTOM FUNCTIONS ---------- #

func handle_dash_input():
	if Input.is_action_just_pressed("Dash") and movement_enabled and not is_dashing and dash_cooldown_timer <= 0:
		start_dash()

func start_dash():
	is_dashing = true
	dash_timer = dash_duration
	dash_cooldown_timer = dash_cooldown
	can_damage = false
	dash_direction = float(facing_direction)
	if dash_direction == 0:
		dash_direction = 1.0
	velocity.x = dash_direction * dash_speed
	velocity.y = 0.0
	ghost_timer = 0.0
	spawn_ghost_trail()

func process_dash(delta: float):
	dash_timer -= delta
	velocity.x = dash_direction * dash_speed
	velocity.y = 0.0
	
	ghost_timer += delta
	if ghost_timer >= 0.04:
		ghost_timer = 0.0
		spawn_ghost_trail()
		
	if dash_timer <= 0:
		is_dashing = false
		can_damage = true
		velocity.x = move_toward(velocity.x, 0, 400.0)
	move_and_slide()

func spawn_ghost_trail():
	var ghost := Sprite2D.new()
	if player_sprite and player_sprite.sprite_frames:
		var anim_name = player_sprite.animation
		var frame_num = player_sprite.frame
		var tex = player_sprite.sprite_frames.get_frame_texture(anim_name, frame_num)
		if tex:
			ghost.texture = tex
			ghost.global_position = player_sprite.global_position
			ghost.scale = player_node.scale * player_sprite.scale
			ghost.modulate = Color(0.3, 0.75, 1.0, 0.6)
			ghost.z_index = z_index - 1
			get_parent().add_child(ghost)
			
			var tween = create_tween()
			tween.parallel().tween_property(ghost, "modulate:a", 0.0, 0.22)
			tween.parallel().tween_property(ghost, "scale", ghost.scale * 1.08, 0.22)
			tween.finished.connect(func(): if is_instance_valid(ghost): ghost.queue_free())

func movement(delta: float):
	# Wall Slide logic
	is_wall_sliding = false
	if is_on_wall() and not is_on_floor() and velocity.y > 0 and movement_enabled:
		is_wall_sliding = true
		velocity.y = min(velocity.y, wall_slide_speed)
		jump_count = max_jump_count

	if !is_wall_sliding:
		if !is_on_floor():
			velocity.y += gravity
		elif is_on_floor():
			jump_count = max_jump_count
			if !Input.is_action_pressed("Left") and !Input.is_action_pressed("Right"):
				if is_attacking:
					velocity.x = move_toward(velocity.x, 0, 700.0 * delta)
				else:
					velocity.x = 0

	handle_jumping()

	if movement_enabled and not is_dashing:
		if Input.is_action_pressed("Left"):
			velocity.x = -move_speed
		elif Input.is_action_pressed("Right"):
			velocity.x = move_speed
	if velocity.y > 5000:
		hit_trap.emit()
	move_and_slide()

func handle_jumping():
	if Input.is_action_just_pressed("Jump") and movement_enabled:
		if is_on_wall() and not is_on_floor():
			wall_jump()
		elif is_on_floor() and !double_jump:
			jump()
		elif double_jump and jump_count > 0:
			if not is_on_floor() and jump_count < max_jump_count:
				spawn_ghost_trail()
			jump()
			jump_count -= 1

func play_sfx(sfx_name: String) -> void:
	var am = get_node_or_null("/root/AudioManager")
	if am and sfx_name in am and am.get(sfx_name):
		am.get(sfx_name).play()

func wall_jump():
	var wall_normal = get_wall_normal()
	var jump_dir_x = wall_normal.x if wall_normal.x != 0 else -float(facing_direction)
	velocity.x = jump_dir_x * wall_jump_force.x
	velocity.y = wall_jump_force.y
	
	facing_direction = 1 if jump_dir_x > 0 else -1
	player_node.scale.x = facing_direction
	
	jump_tween()
	play_sfx("jump_sfx")

func jump():
	jump_tween()
	play_sfx("jump_sfx")
	velocity.y = -jump_force

# --- Phần thay đổi nhiều nhất: phát animation ---
func player_animations():
	particle_trails.emitting = false
	var gm = get_node_or_null("/root/GameManager")
	var cid: String = gm.selected_character_id if gm and "selected_character_id" in gm else "knight"

	if is_attacking:
		return

	var target_anim := ""
	if is_on_floor():
		if abs(velocity.x) > 0:
			particle_trails.emitting = true
			target_anim = "Walk"
		else:
			target_anim = "Idle"
	else:
		target_anim = "Jump"

	# Tránh để .play() khởi động lại animation mỗi khung hình
	if player_sprite.animation != target_anim:
		player_sprite.play(target_anim)

	# Nâng cấp hoạt ảnh nhún nhẩy (Procedural Animation) cho Phù Thủy & Cung Thủ
	if cid != "knight" and player_sprite:
		var base_y: float = -42.0 if cid == "archer" else -56.0
		var t = Time.get_ticks_msec() * 0.001
		if target_anim == "Walk":
			player_sprite.position.y = base_y + abs(sin(t * 14.0)) * -5.0
		elif target_anim == "Idle":
			player_sprite.position.y = base_y + sin(t * 3.5) * 2.0
		elif target_anim == "Jump":
			player_sprite.position.y = base_y - 3.0

# Flip player sprite based on input or velocity, never flip during attack
func flip_player():
	if is_attacking:
		return
	
	var dir := 0
	if Input.is_action_pressed("Left"):
		dir = -1
	elif Input.is_action_pressed("Right"):
		dir = 1
	elif abs(velocity.x) > 10.0:
		dir = -1 if velocity.x < 0 else 1
		
	if dir != 0:
		facing_direction = dir
		var gm = get_node_or_null("/root/GameManager")
		var cid: String = gm.selected_character_id if gm and "selected_character_id" in gm else "knight"
		
		if cid == "knight":
			player_node.scale.x = facing_direction
		else:
			player_node.scale.x = 1.0
			if player_sprite:
				player_sprite.flip_h = (facing_direction == -1)
			var bullet_marker = get_node_or_null("student/BulletMarker")
			if bullet_marker:
				bullet_marker.position.x = 76.0 * facing_direction

# Tween Animations (không cần sửa, dùng scale/position của node cha)
func death_tween():
	play_sfx("death_sfx")
	death_particles.emitting = true
	movement_enabled = false
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2.ZERO, 0.15)
	tween.parallel().tween_property(self, "position", Vector2(position.x,position.y-100), 0.15)
	await tween.finished
	global_position = spawn_point
	await get_tree().create_timer(0.3).timeout
	movement_enabled = true
	play_sfx("respawn_sfx")
	respawn_tween()

func respawn_tween():
	var tween = create_tween()
	tween.stop(); tween.play()
	tween.tween_property(self, "scale", Vector2.ONE, 0.15) 
	tween.parallel().tween_property(self, "position", spawn_point, 0.15)

func jump_tween():
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(0.7, 1.4), 0.1)
	tween.tween_property(self, "scale", Vector2(1.0,1.0), 0.1)

func damage_tween():
	shake(8.0, 0.25)
	var tween = create_tween() 
	tween.stop(); tween.play()
	can_damage = false
	for i in range(1,10):
		tween.tween_property(player_node , "modulate", Color.RED, 0.1)
		tween.tween_property(player_node , "modulate", Color.WHITE, 0.1)
	await tween.finished
	can_damage = true

# --------- SIGNALS ---------- #
func _on_collision_body_entered(body):
	if body.is_in_group("Traps"):
		shake(10.0, 0.3)
		hit_trap.emit()
	if !can_damage: return
	if body.is_in_group("Enemy") or body is Enemy or body.is_in_group("Boss"):
		on_hit_by_enemy(body)

func check_enemy_collisions():
	if not can_damage or not movement_enabled or is_dashing:
		return
	if has_node("Collision"):
		var bodies = $Collision.get_overlapping_bodies()
		for body in bodies:
			if body != self and (body.is_in_group("Enemy") or body is Enemy or body.is_in_group("Boss")):
				on_hit_by_enemy(body)
				break

func on_hit_by_enemy(enemy_node: Node2D):
	if not can_damage or is_dashing:
		return
	var dx = enemy_node.global_position.x - global_position.x
	velocity.y = -350.0
	if dx > 0:
		velocity.x = -300.0
	else:
		velocity.x = 300.0
	damage_tween()
	hit_enemy.emit()

func handle_attack():
	if Input.is_action_just_pressed("Shoot") and movement_enabled and attack_cooldown_timer <= 0:
		melee_attack()

func melee_attack():
	is_attacking = true
	attack_cooldown_timer = melee_cooldown_time
	player_sprite.play("Attack")
	
	if swing_sfx:
		swing_sfx.pitch_scale = randf_range(0.95, 1.08)
		swing_sfx.play()
	
	var face_dir = float(facing_direction)
	# Nhẹ nhàng lướt tới phía trước theo hướng đánh (không bị giật lùi!)
	if is_on_floor():
		velocity.x = face_dir * lunge_force
	
	play_slash_vfx()
	is_slash_active = true
	
	# Kiểm tra trúng quái lập tức
	check_melee_hits(face_dir)
	
	# Giữ hitbox active trong khoảng 0.16s của cú đâm
	await get_tree().create_timer(0.16).timeout
	is_slash_active = false
	await get_tree().create_timer(0.09).timeout
	is_attacking = false

func play_slash_vfx():
	if not slash_vfx:
		return
	slash_vfx.visible = true
	slash_vfx.position = Vector2(50, -45)
	slash_vfx.scale = Vector2(0.04, 0.04)
	
	match current_element:
		0: slash_vfx.modulate = Color(1.8, 1.5, 0.4, 1.0)
		1: slash_vfx.modulate = Color(2.2, 0.4, 0.2, 1.0)
		2: slash_vfx.modulate = Color(0.4, 1.4, 2.2, 1.0)
	
	var tween = create_tween()
	tween.parallel().tween_property(slash_vfx, "position", Vector2(85, -45), 0.16).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(slash_vfx, "scale", Vector2(0.13, 0.13), 0.16)
	tween.parallel().tween_property(slash_vfx, "modulate:a", 0.0, 0.16)
	
	shoot_spear_wave()
	await tween.finished
	slash_vfx.visible = false

func shoot_spear_wave():
	if bullet_scene == null:
		return
	var wave = bullet_scene.instantiate()
	var bullet_marker = $student/BulletMarker if has_node("student/BulletMarker") else null
	var spawn_pos = bullet_marker.global_position if bullet_marker else global_position
	wave.global_position = spawn_pos
	
	if wave.has_method("set_element"):
		wave.set_element(current_element)
		
	var gm = get_node_or_null("/root/GameManager")
	var speed_mult: float = 1.0
	if gm and "spear_wave_speed_mult" in gm:
		speed_mult = gm.spear_wave_speed_mult
	var dir = Vector2(facing_direction, randf_range(-0.04, 0.04)).normalized()
	get_parent().add_child(wave)
	if wave.has_method("shoot"):
		wave.shoot(dir, 750.0 * speed_mult, bullet_lifetime)

func check_melee_hits(face_dir: float):
	if not melee_area:
		return
	var bodies = melee_area.get_overlapping_bodies()
	for body in bodies:
		if body != self and (body.is_in_group("Enemy") or body is Enemy):
			apply_hit_to_enemy(body, face_dir)
	
	var areas = melee_area.get_overlapping_areas()
	for area in areas:
		var parent = area.get_parent()
		if parent and (parent.is_in_group("Enemy") or parent is Enemy):
			apply_hit_to_enemy(parent, face_dir)

func _on_melee_body_entered(body: Node2D) -> void:
	if is_slash_active and body != self and (body.is_in_group("Enemy") or body is Enemy):
		apply_hit_to_enemy(body, float(facing_direction))

func _on_melee_area_entered(area: Area2D) -> void:
	if is_slash_active:
		var parent = area.get_parent()
		if parent and (parent.is_in_group("Enemy") or parent is Enemy):
			apply_hit_to_enemy(parent, float(facing_direction))

func apply_hit_to_enemy(enemy_node: Node2D, face_dir: float):
	if enemy_node.has_method("take_hit"):
		var knockback_dir = Vector2(face_dir, -0.4).normalized()
		enemy_node.take_hit(knockback_dir)
	elif enemy_node.has_method("death_tween"):
		enemy_node.death_tween()
	
	# Âm thanh va chạm
	if hit_sfx:
		hit_sfx.pitch_scale = randf_range(0.95, 1.1)
		hit_sfx.play()
	
	# Hiệu ứng nổ tia lửa (Hit Spark)
	play_hit_spark(enemy_node.global_position)
	
	# Hit-stop: khựng khung hình cực ngắn tạo cảm giác chém trúng chân thực như Dead Cells / Hollow Knight
	hit_stop(0.04)
	
	# Camera Shake nhẹ (Screen Shake micro-feel)
	shake_camera()

func hit_stop(duration: float = 0.04):
	Engine.time_scale = 0.1
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0

func play_hit_spark(hit_pos: Vector2):
	if not hit_spark:
		return
	hit_spark.visible = true
	hit_spark.global_position = hit_pos + Vector2(0, -30)
	hit_spark.scale = Vector2(0.04, 0.04)
	hit_spark.modulate = Color(1.8, 1.6, 1.2, 1.0)
	var tween = create_tween()
	tween.parallel().tween_property(hit_spark, "scale", Vector2(0.12, 0.12), 0.12)
	tween.parallel().tween_property(hit_spark, "modulate:a", 0.0, 0.12)
	await tween.finished
	hit_spark.visible = false

func shake(strength: float = 8.0, duration: float = 0.2) -> void:
	if camera_node and camera_node.has_method("apply_shake"):
		camera_node.apply_shake(strength, duration)

func apply_shake(intensity: float = 8.0, duration: float = 0.2) -> void:
	shake(intensity, duration)

func shake_camera(strength: float = 4.0, duration: float = 0.15) -> void:
	shake(strength, duration)

func _on_animation_finished() -> void:
	if player_sprite.animation == "Attack":
		is_attacking = false

