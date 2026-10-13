class_name Player
extends CharacterBody2D

signal hit_enemy
signal hit_trap

const FireColumnScript = preload("res://Scenes/Prefabs/fire_column.gd")


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
var is_dying : bool = false
var is_slash_active = false
var facing_direction : int = 1 # 1 = Phải, -1 = Trái

var is_dashing : bool = false
var dash_timer : float = 0.0
var dash_cooldown_timer : float = 0.0
var dash_direction : float = 1.0
var ghost_timer : float = 0.0
var is_wall_sliding : bool = false

var current_element : int = 0 # 0 = NORMAL, 1 = FIRE, 2 = ICE
var aura_particles: CPUParticles2D = null
@export var bullet_scene : PackedScene
@export var bullet_lifetime : float = 1.5

# Kỹ năng chủ động duy nhất (1 Skill) cho từng class
var special_cooldown_timer: float = 0.0
var is_special_casting: bool = false

# Cooldown constants cho Signature Skill của mỗi class
const KNIGHT_SPECIAL_COOLDOWN: float = 2.5
const MAGE_SPECIAL_COOLDOWN: float = 3.5
const RANGER_SPECIAL_COOLDOWN: float = 3.0


# --- Knight True Melee Combo & Plunge Attack ---
var combo_step : int = 0 # 0: Thrust, 1: Upward Slash, 2: Heavy Overhead Smash
var combo_timer : float = 0.0
const COMBO_WINDOW : float = 0.55
var is_plunging : bool = false
var plunge_hit_done : bool = false

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
		spawn_point = global_position
		gm.save_player_position = Vector2.ZERO
	if player_sprite:
		if _default_knight_frames == null:
			_default_knight_frames = player_sprite.sprite_frames
		player_sprite.animation_finished.connect(_on_animation_finished)
	if melee_area:
		melee_area.monitoring = false
		melee_area.monitorable = false
		melee_area.body_entered.connect(_on_melee_body_entered)
		melee_area.area_entered.connect(_on_melee_area_entered)
	apply_class_config()
	setup_persistent_element_aura()


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
				
			sf.add_animation("CastGround")
			sf.set_animation_loop("CastGround", false)
			sf.set_animation_speed("CastGround", 20.0)
			for i in range(10):
				var tex = load("res://Assets/Spritesheet/fairy/Fairy_03__ATTACK_%03d.png" % i)
				if tex: sf.add_frame("CastGround", tex)

			sf.add_animation("CastAir")
			sf.set_animation_loop("CastAir", false)
			sf.set_animation_speed("CastAir", 20.0)
			for i in range(10):
				var tex = load("res://Assets/Spritesheet/fairy/Fairy_03__FLY_ATTACK_%03d.png" % i)
				if tex: sf.add_frame("CastAir", tex)
				
		"archer":
			var tex_idle = load("res://Assets/Spritesheet/archer/girl_archer.png")
			var tex_attack = load("res://Assets/Spritesheet/archer/girl_archer_attack.png")
			if tex_idle:
				sf.add_animation("Idle")
				sf.add_frame("Idle", tex_idle)
				sf.add_animation("Walk")
				sf.add_frame("Walk", tex_idle)
				sf.add_animation("Jump")
				sf.add_frame("Jump", tex_idle)
				
				# Hoạt ảnh cử động tay giương cung ngắm bắn
				sf.add_animation("DrawBow")
				sf.set_animation_loop("DrawBow", false)
				sf.set_animation_speed("DrawBow", 10.0)
				if tex_attack:
					sf.add_frame("DrawBow", tex_attack)
				else:
					sf.add_frame("DrawBow", tex_idle)
					
				sf.add_animation("Attack")
				sf.set_animation_loop("Attack", false)
				sf.set_animation_speed("Attack", 10.0)
				if tex_attack:
					sf.add_frame("Attack", tex_attack)
				else:
					sf.add_frame("Attack", tex_idle)

	_class_frames_cache[cid] = sf
	return sf


func apply_class_config(override_cid: String = "") -> void:
	var gm = get_node_or_null("/root/GameManager") if is_inside_tree() else null
	var cid: String = override_cid if override_cid != "" else (gm.selected_character_id if gm and "selected_character_id" in gm else "knight")
	
	var weapon_spear = get_node_or_null("student/WeaponSpear")
	var weapon_staff = get_node_or_null("student/WeaponStaff")
	var weapon_bow = get_node_or_null("student/WeaponBow")
	var skeleton_node = get_node_or_null("student/Skeleton2D")
	var anim_player = get_node_or_null("student/AnimationPlayer")
	var light_w = get_node_or_null("LightW")
	
	if skeleton_node:
		skeleton_node.visible = false
	if anim_player:
		anim_player.stop()
	if light_w:
		light_w.visible = false
	
	match cid:
		"knight":
			move_speed = 300.0
			if gm:
				gm.max_hp = 100
				gm.hp = min(gm.hp, 100)
			bullet_scene = null # Knight is 100% Pure Melee! No ranged projectiles!
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
			if gm:
				gm.max_hp = 80
				gm.hp = min(gm.hp, 80)
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
			if gm:
				gm.max_hp = 90
				gm.hp = min(gm.hp, 90)
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
	
	if is_plunging:
		process_plunge(delta)
		return
	
	if dash_cooldown_timer > 0:
		dash_cooldown_timer -= delta
	if special_cooldown_timer > 0.0:
		special_cooldown_timer = maxf(0.0, special_cooldown_timer - delta)
		
	handle_dash_input()
	movement(delta)
	check_enemy_collisions()

func _process(_delta):
	player_animations()
	flip_player()
	handle_element_switch()
	handle_attack()
	handle_special_skill()
	if attack_cooldown_timer > 0:
		attack_cooldown_timer -= _delta
	if combo_timer > 0:
		combo_timer -= _delta
		if combo_timer <= 0 and not is_attacking:
			combo_step = 0

func handle_element_switch():
	if Input.is_action_just_pressed("SwitchElement"):
		current_element = (current_element + 1) % 3
		spawn_element_switch_vfx()
		update_persistent_element_aura()


# --------- CUSTOM FUNCTIONS ---------- #

func handle_dash_input():
	if Input.is_action_just_pressed("Dash") and movement_enabled and not is_dashing and dash_cooldown_timer <= 0:
		var gm = get_node_or_null("/root/GameManager") if is_inside_tree() else null
		var cid: String = gm.selected_character_id if gm and "selected_character_id" in gm else "knight"
		if cid == "mage":
			start_mage_blink()
		else:
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

# --------- MAGE BLINK (DỊCH CHUYỂN TỨC THỜI) ---------- #
func start_mage_blink() -> void:
	is_dashing = true
	dash_cooldown_timer = 0.85
	can_damage = false
	
	var dir = float(facing_direction)
	if dir == 0: dir = 1.0
	var blink_dist = 190.0
	
	# Raycast kiểm tra địa hình để tránh dịch chuyển kẹt vào trong tường
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(global_position, global_position + Vector2(dir * blink_dist, 0), 1) # Layer 1 = World
	var result = space_state.intersect_ray(query)
	var target_pos = global_position + Vector2(dir * blink_dist, 0)
	if result:
		target_pos = result.position - Vector2(dir * 22.0, 0) # Dừng trước mặt tường 22px
	
	# Hiệu ứng ma pháp tại vị trí ban đầu
	spawn_blink_vfx(global_position)
	
	if swing_sfx:
		swing_sfx.pitch_scale = 1.7
		swing_sfx.play()
	play_sfx("jump_sfx")
	
	# Hiệu ứng tan biến chớp nhoáng
	var tw = create_tween()
	tw.tween_property(player_node, "scale:x", 0.05, 0.05)
	await tw.finished
	
	global_position = target_pos
	velocity = Vector2(dir * 120.0, 0)
	
	# Hiệu ứng ma pháp xuất hiện tại đích
	spawn_blink_vfx(global_position)
	
	var tw_in = create_tween()
	tw_in.tween_property(player_node, "scale:x", 1.0, 0.05)
	await tw_in.finished
	
	is_dashing = false
	can_damage = true

func spawn_blink_vfx(vfx_pos: Vector2) -> void:
	if not is_inside_tree() or not get_parent():
		return
	var p = CPUParticles2D.new()
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = 18
	p.lifetime = 0.28
	p.spread = 180.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 40.0
	p.initial_velocity_max = 95.0
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.5
	
	var blink_col = Color(1.8, 0.6, 2.8, 0.9)
	match current_element:
		0: blink_col = Color(1.8, 0.6, 2.8, 0.9)
		1: blink_col = Color(2.8, 0.7, 0.2, 0.9)
		2: blink_col = Color(0.6, 2.0, 2.8, 0.9)
	p.color = blink_col
	p.global_position = vfx_pos
	
	get_parent().add_child(p)
	p.emitting = true
	if is_inside_tree() and get_tree():
		get_tree().create_timer(0.35).timeout.connect(p.queue_free)

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
			
			var tween = ghost.create_tween()
			tween.parallel().tween_property(ghost, "modulate:a", 0.0, 0.22)
			tween.parallel().tween_property(ghost, "scale", ghost.scale * 1.08, 0.22)
			tween.tween_callback(ghost.queue_free)

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
	if velocity.y > 5000 and not is_dying and can_damage:
		hit_trap.emit()
	move_and_slide()

func handle_jumping():
	if (Input.is_action_just_pressed("Jump") or Input.is_action_just_pressed("Up")) and movement_enabled:
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
				bullet_marker.position.x = 20.0 * facing_direction
				bullet_marker.position.y = -42.0
			var weapon_bow = get_node_or_null("student/WeaponBow")
			if weapon_bow:
				weapon_bow.position.x = 40.0 * facing_direction
				weapon_bow.flip_h = (facing_direction == -1)

# Tween Animations (không cần sửa, dùng scale/position của node cha)
func death_tween():
	if is_dying:
		return
	is_dying = true
	can_damage = false
	movement_enabled = false
	velocity = Vector2.ZERO
	
	# Vô hiệu hóa hitbox va chạm trong suốt thời gian chết
	if has_node("Collision"):
		$Collision.set_deferred("monitoring", false)
		$Collision.set_deferred("monitorable", false)
	collision_layer = 0
	
	play_sfx("death_sfx")
	if death_particles:
		death_particles.emitting = true
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2.ZERO, 0.15)
	tween.parallel().tween_property(self, "position", Vector2(position.x, position.y - 100), 0.15)
	await tween.finished
	
	# Đặt người chơi về điểm hồi sinh an toàn, xóa sạch gia tốc cũ
	global_position = spawn_point
	velocity = Vector2.ZERO
	await get_tree().create_timer(0.3).timeout
	
	# Khôi phục va chạm và di chuyển
	collision_layer = 2
	if has_node("Collision"):
		$Collision.set_deferred("monitoring", true)
		$Collision.set_deferred("monitorable", true)
		
	movement_enabled = true
	play_sfx("respawn_sfx")
	await respawn_tween()
	
	# Thời gian bất tử khi vừa hồi sinh (1.5s i-frames nhấp nháy mờ chạy song song khi bắt đầu di chuyển)
	is_dying = false
	start_respawn_invulnerability(1.5)

func respawn_tween():
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "position", spawn_point, 0.18)
	await tween.finished

func start_respawn_invulnerability(duration: float = 1.5) -> void:
	can_damage = false
	var blink_count: int = int(duration / 0.15)
	var tween = create_tween()
	for i in range(blink_count):
		tween.tween_property(player_node, "modulate:a", 0.35, 0.075)
		tween.tween_property(player_node, "modulate:a", 1.0, 0.075)
	await tween.finished
	if is_instance_valid(player_node):
		player_node.modulate.a = 1.0
	can_damage = true

func jump_tween():
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(0.7, 1.4), 0.1)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1)

func damage_tween():
	shake(8.0, 0.25)
	if not player_node:
		player_node = get_node_or_null("student")
	if not player_node:
		return
	var tween = create_tween() 
	tween.stop(); tween.play()
	can_damage = false
	for i in range(1, 10):
		tween.tween_property(player_node, "modulate", Color.RED, 0.1)
		tween.tween_property(player_node, "modulate", Color.WHITE, 0.1)
	await tween.finished
	if not is_dying:
		can_damage = true

# --------- SIGNALS ---------- #
func _on_collision_body_entered(body):
	if is_dying or not can_damage:
		return
	if body.is_in_group("Traps"):
		shake(10.0, 0.3)
		hit_trap.emit()
		return
	if body.is_in_group("Enemy") or body is Enemy or body.is_in_group("Boss"):
		on_hit_by_enemy(body)

func check_enemy_collisions():
	if is_dying or not can_damage or not movement_enabled or is_dashing:
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
	velocity.y = -180.0 # Giật nảy lùi nhẹ chân thực thay vì bắn vọt lên trời
	if dx > 0:
		velocity.x = -320.0
	else:
		velocity.x = 320.0
	damage_tween()
	hit_enemy.emit()

func handle_attack():
	if Input.is_action_just_pressed("Shoot") and movement_enabled and attack_cooldown_timer <= 0 and not is_plunging:
		var gm = get_node_or_null("/root/GameManager") if is_inside_tree() else null
		var cid: String = gm.selected_character_id if gm and "selected_character_id" in gm else "knight"
		
		if cid == "knight":
			if !is_on_floor():
				start_air_plunge()
			else:
				start_knight_combo()
		elif cid == "mage":
			if !is_on_floor():
				start_mage_air_spell()
			else:
				start_mage_ground_spell()
		else:
			ranged_attack()

func handle_special_skill() -> void:
	if not Input.is_action_just_pressed("Special"):
		return
	if not movement_enabled or is_attacking or is_plunging or is_special_casting or special_cooldown_timer > 0.0:
		return

	var gm = get_node_or_null("/root/GameManager") if is_inside_tree() else null
	var cid: String = gm.selected_character_id if gm and "selected_character_id" in gm else "knight"
	match cid:
		"knight":
			start_knight_spear_cyclone()
		"mage":
			start_mage_arcane_nova()
		"archer":
			start_ranger_triple_volley()



# --------- MAGE MAGIC SPELL COMBAT SYSTEM ---------- #


func spawn_magic_cast_flare(flare_pos: Vector2):
	if not is_inside_tree() or not get_parent():
		return
	var flare = Sprite2D.new()
	flare.texture = load("res://Assets/Spritesheet/laser_bullet.png")
	flare.global_position = flare_pos
	flare.scale = Vector2(0.15, 0.15)
	flare.rotation = randf_range(0.0, TAU)
	
	var col = Color(1.8, 0.6, 2.8, 1.0)
	match current_element:
		0: col = Color(2.0, 0.6, 3.0, 1.0) # Quang Ma Pháp / Arcane Tím
		1: col = Color(3.2, 0.8, 0.1, 1.0) # Hỏa Phép Cam Đỏ
		2: col = Color(0.6, 2.2, 3.0, 1.0) # Băng Phép Xanh Lam
	flare.modulate = col
	get_parent().add_child(flare)
	
	var tw = flare.create_tween()
	tw.tween_property(flare, "scale", Vector2(0.65, 0.65), 0.08).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(flare, "modulate:a", 0.0, 0.12)
	tw.tween_callback(flare.queue_free)

func start_mage_ground_spell():
	is_attacking = true
	attack_cooldown_timer = 0.28
	play_attack_animation("CastGround")
		
	var bullet_marker = get_node_or_null("student/BulletMarker")
	var spawn_pos = bullet_marker.global_position if bullet_marker else global_position
	spawn_magic_cast_flare(spawn_pos)
	
	if swing_sfx:
		match current_element:
			0: swing_sfx.pitch_scale = randf_range(1.3, 1.45) # Arcane chime
			1: swing_sfx.pitch_scale = randf_range(0.9, 1.05) # Fiery blast
			2: swing_sfx.pitch_scale = randf_range(1.5, 1.7) # Crystal ice chime
		swing_sfx.play()
		
	_anim_mage_cast_ground()
	shoot_projectile()
	if is_inside_tree() and get_tree():
		await get_tree().create_timer(0.28).timeout
	is_attacking = false

func start_mage_air_spell():
	is_attacking = true
	attack_cooldown_timer = 0.42
	
	# Hãm tốc độ rơi, tạo cảm giác phù thủy lơ lửng niệm chú giữa không trung
	velocity.y = -60.0
	velocity.x = move_toward(velocity.x, 0, 300.0)
	
	play_attack_animation("CastAir")
		
	var bullet_marker = get_node_or_null("student/BulletMarker")
	var spawn_pos = bullet_marker.global_position if bullet_marker else global_position
	spawn_magic_cast_flare(spawn_pos)
	
	if swing_sfx:
		swing_sfx.pitch_scale = 1.45
		swing_sfx.play()
		
	shake_camera(4.0, 0.15)
	_anim_mage_cast_air()
	
	# Bắn chùm 3 tia phép tỏa hình cánh quạt hướng xuống đất
	var angles = [-0.22, 0.22, 0.65]
	var face_dir = float(facing_direction)
	for ang in angles:
		if bullet_scene == null: break
		var proj = bullet_scene.instantiate()
		proj.global_position = spawn_pos
		if proj.has_method("set_element"):
			proj.set_element(current_element)
		var dir = Vector2(face_dir, ang).normalized()
		get_parent().add_child(proj)
		if proj.has_method("shoot"):
			proj.shoot(dir, 720.0, bullet_lifetime)
			
	if is_inside_tree() and get_tree():
		await get_tree().create_timer(0.42).timeout
	is_attacking = false

# --------- RANGED ATTACK (CUNG THỦ & PHÙ THỦY) ---------- #
func ranged_attack() -> void:
	is_attacking = true
	attack_cooldown_timer = 0.38
	await animate_ranger_draw_and_shoot()
	is_attacking = false

func play_attack_animation(preferred_animation: String) -> void:
	if not player_sprite or not player_sprite.sprite_frames:
		return
	if player_sprite.sprite_frames.has_animation(preferred_animation):
		player_sprite.play(preferred_animation)
	elif player_sprite.sprite_frames.has_animation("Attack"):
		# Knight dùng animation Attack có sẵn từ SpriteFrames trong player.tscn.
		player_sprite.play("Attack")

func animate_ranger_draw_and_shoot() -> void:
	if not player_sprite:
		shoot_projectile()
		return
		
	var base_position := Vector2(0.0, -42.0)
	var base_scale := Vector2(0.12, 0.12)
	player_sprite.position = base_position
	player_sprite.scale = base_scale
	player_sprite.rotation = 0.0
	
	var pull_dir: float = -float(facing_direction)
	
	# Đổi sang tư thế giơ tay kéo cung ngắm bắn
	play_attack_animation("DrawBow")
	
	# Phong Linh Tiễn (Mode 0) kéo cung thần tốc (+40% tốc xạ)
	var draw_duration : float = 0.07 if current_element == 0 else 0.11
	
	# --- GIAI ĐOẠN 1: KÉO CUNG & TỤ KHÍ ---
	var draw_tw := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	draw_tw.tween_property(player_sprite, "position", base_position + Vector2(10.0 * pull_dir, -4.0), draw_duration)
	draw_tw.parallel().tween_property(player_sprite, "scale", Vector2(0.105, 0.138), draw_duration)
	draw_tw.parallel().tween_property(player_sprite, "rotation", 0.12 * pull_dir, draw_duration)
	
	# VFX ánh sáng mũi tên tụ lại trên cánh cung
	spawn_archer_draw_charge_vfx()
	_anim_archer_draw_element()
	
	if is_inside_tree() and get_tree():
		await get_tree().create_timer(0.11).timeout
		
	# --- GIAI ĐOẠN 2: BUÔNG TÊN (RELEASE & SNAP ~0.06s) ---
	# Bắn mũi tên xuất phát ngay đúng thời điểm dây cung buông!
	shoot_projectile()
	
	# Âm thanh dây cung bật đanh thép
	if swing_sfx:
		swing_sfx.pitch_scale = randf_range(1.35, 1.55)
		swing_sfx.play()
		
	# Giật mạnh người về trước theo quán tính lực bắn
	var shoot_tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	shoot_tw.tween_property(player_sprite, "position", base_position + Vector2(14.0 * float(facing_direction), -6.0), 0.06)
	shoot_tw.parallel().tween_property(player_sprite, "scale", Vector2(0.145, 0.105), 0.06)
	shoot_tw.parallel().tween_property(player_sprite, "rotation", -0.06 * pull_dir, 0.06)
	
	# Flash sáng chớp nhoáng trên thân nhân vật
	shoot_tw.tween_property(player_sprite, "modulate", Color(2.2, 2.2, 2.2, 1.0), 0.03)
	shoot_tw.tween_property(player_sprite, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.05)
	
	# VFX tia sáng xé gió & luồng khí nén phía trước mũi cung
	spawn_archer_shot_flash()
	shake_camera(2.5, 0.08)
	
	if is_inside_tree() and get_tree():
		await get_tree().create_timer(0.06).timeout
		
	# --- GIAI ĐOẠN 3: GIẬT LÙI RECOIL & HỒI PHỤC (RECOVERY ~0.14s) ---
	var recover_tw := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	recover_tw.tween_property(player_sprite, "position", base_position + Vector2(3.0 * pull_dir, 1.0), 0.06)
	recover_tw.parallel().tween_property(player_sprite, "scale", Vector2(0.115, 0.125), 0.06)
	recover_tw.parallel().tween_property(player_sprite, "rotation", 0.0, 0.06)
	
	recover_tw.tween_property(player_sprite, "position", base_position, 0.08)
	recover_tw.parallel().tween_property(player_sprite, "scale", base_scale, 0.08)
	
	if is_inside_tree() and get_tree():
		await get_tree().create_timer(0.14).timeout
		
	player_sprite.position = base_position
	player_sprite.scale = base_scale
	player_sprite.rotation = 0.0
	
	# Hạ tay xuống tư thế bình thường
	play_attack_animation("Idle")

func spawn_archer_draw_charge_vfx() -> void:
	if not get_parent() or not is_inside_tree():
		return
	var charge := Sprite2D.new()
	var tex = load("res://Assets/Spritesheet/laser_bullet.png")
	if not tex:
		return
	charge.texture = tex
	var marker = get_node_or_null("student/BulletMarker")
	charge.global_position = marker.global_position if marker else global_position + Vector2(18.0 * facing_direction, -42.0)
	
	var col = Color(2.4, 2.0, 0.5, 0.85)
	match current_element:
		0: col = Color(2.4, 2.0, 0.5, 0.85) # Vàng Thần Tốc
		1: col = Color(3.5, 0.8, 0.15, 0.85) # Đỏ Hỏa Tiễn
		2: col = Color(0.5, 2.2, 3.2, 0.85) # Xanh Băng Tiễn
	charge.modulate = col
	charge.scale = Vector2(0.02, 0.02)
	charge.rotation = (Vector2(float(facing_direction), 0.0)).angle()
	get_parent().add_child(charge)
	
	var tw := charge.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(charge, "scale", Vector2(0.15, 0.06), 0.10)
	tw.parallel().tween_property(charge, "modulate:a", 1.0, 0.05)
	tw.tween_property(charge, "modulate:a", 0.0, 0.05)
	tw.tween_callback(charge.queue_free)

func spawn_archer_shot_flash() -> void:
	if not get_parent() or not is_inside_tree():
		return
	var tex = load("res://Assets/Spritesheet/laser_bullet.png")
	if not tex:
		return
	var marker = get_node_or_null("student/BulletMarker")
	var shoot_pos: Vector2 = marker.global_position if marker else global_position + Vector2(24.0 * facing_direction, -42.0)
	
	var col = Color(2.4, 2.0, 0.5, 1.0)
	match current_element:
		0: col = Color(2.4, 2.0, 0.5, 1.0) # Vàng Thần Tốc
		1: col = Color(3.5, 0.8, 0.15, 1.0) # Đỏ Hỏa Tiễn
		2: col = Color(0.5, 2.2, 3.2, 1.0) # Xanh Băng Tiễn
		
	# Tia sáng xé gió
	var flash := Sprite2D.new()
	flash.texture = tex
	flash.global_position = shoot_pos
	flash.modulate = col
	flash.scale = Vector2(0.05, 0.05)
	flash.rotation = (Vector2(float(facing_direction), 0.0)).angle()
	get_parent().add_child(flash)
	
	# Vòng khí nén xé gió bùng ra
	var ring := Sprite2D.new()
	ring.texture = tex
	ring.global_position = shoot_pos
	ring.modulate = col * 0.75
	ring.scale = Vector2(0.04, 0.04)
	ring.rotation = randf_range(0.0, TAU)
	get_parent().add_child(ring)
	
	var tw := flash.create_tween()
	tw.parallel().tween_property(flash, "scale", Vector2(0.28, 0.08), 0.08).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(flash, "position:x", flash.position.x + 25.0 * facing_direction, 0.08)
	tw.parallel().tween_property(flash, "modulate:a", 0.0, 0.12)
	tw.tween_callback(flash.queue_free)
	
	var rtw := ring.create_tween()
	rtw.parallel().tween_property(ring, "scale", Vector2(0.18, 0.18), 0.10).set_ease(Tween.EASE_OUT)
	rtw.parallel().tween_property(ring, "modulate:a", 0.0, 0.10)
	rtw.tween_callback(ring.queue_free)


# --------- CLASS SPECIAL SKILLS ---------- #
# Knight: cận chiến xoay thương, đánh mọi mục tiêu quanh người chơi.
func start_knight_spear_cyclone() -> void:
	is_attacking = true
	is_special_casting = true
	special_cooldown_timer = KNIGHT_SPECIAL_COOLDOWN
	attack_cooldown_timer = 0.65
	play_attack_animation("KnightCyclone")
	if swing_sfx:
		swing_sfx.pitch_scale = 0.82
		swing_sfx.play()
	if player_node:
		var original_rotation: float = player_node.rotation
		var spin_tween := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		spin_tween.tween_property(player_node, "rotation", original_rotation + TAU, 0.36)
		spin_tween.tween_property(player_node, "rotation", original_rotation, 0.01)
	spawn_knight_cyclone_vfx()
	damage_targets_in_radius(112.0, 62.0, Vector2(float(facing_direction), -0.2).normalized())
	shake_camera(6.0, 0.18)
	if is_inside_tree() and get_tree():
		await get_tree().create_timer(0.42).timeout
	is_special_casting = false
	is_attacking = false

# Sorceress: niệm chú và phóng 1 quả cầu năng lượng khổng lồ về phía trước.
func start_mage_arcane_nova() -> void:
	start_mage_giant_orb_skill()

func start_mage_giant_orb_skill() -> void:
	is_attacking = true
	is_special_casting = true
	special_cooldown_timer = MAGE_SPECIAL_COOLDOWN
	attack_cooldown_timer = 0.75
	
	if is_on_floor():
		play_attack_animation("CastGround")
	else:
		play_attack_animation("CastAir")
		velocity.y = -60.0 # Hãm rơi lơ lửng trên không
		
	velocity.x = move_toward(velocity.x, 0.0, 450.0)
	
	# Animation niệm chú: Phù Thủy phát sáng rực rỡ với màu nguyên tố
	var elem_color := mage_element_color()
	if player_sprite:
		var cast_tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		cast_tw.tween_property(player_sprite, "modulate", elem_color * 1.8, 0.12)
		cast_tw.tween_property(player_sprite, "modulate", Color(1.2, 0.8, 1.8, 1.0), 0.20)
	
	if swing_sfx:
		swing_sfx.pitch_scale = 0.70
		swing_sfx.play()
	
	# Tạo hiệu ứng tích tụ năng lượng xoáy tròn tại điểm bắn
	var bullet_marker = get_node_or_null("student/BulletMarker")
	var spawn_pos: Vector2 = bullet_marker.global_position if bullet_marker else global_position + Vector2(25.0 * facing_direction, -42.0)
	
	for i in range(6):
		spawn_magic_cast_flare(spawn_pos + Vector2(randf_range(-25, 25), randf_range(-25, 25)))
	
	shake_camera(4.5, 0.15)
	
	# Đợi 1 nhịp niệm chú ngắn tích đủ năng lượng rồi phóng
	if is_inside_tree() and get_tree():
		await get_tree().create_timer(0.18).timeout
	
	# Phóng quả cầu năng lượng khổng lồ bay thẳng về phía trước
	spawn_mage_giant_orb(spawn_pos)
	
	shake_camera(7.5, 0.22)
	
	if is_inside_tree() and get_tree():
		await get_tree().create_timer(0.35).timeout
	is_special_casting = false
	is_attacking = false

func spawn_mage_giant_orb(spawn_pos: Vector2) -> void:
	if bullet_scene == null or not get_parent():
		return
	
	var orb = bullet_scene.instantiate()
	orb.global_position = spawn_pos
	
	# Thêm vào scene tree trước để các node bên trong khởi tạo
	get_parent().add_child(orb)
	
	# Cấu hình quả cầu khổng lồ uy lực
	if orb.has_method("configure_giant_orb"):
		orb.configure_giant_orb(current_element)
	elif orb.has_method("set_element"):
		orb.set_element(current_element)
		if "base_scale" in orb:
			orb.base_scale *= 2.8
		if orb.has_node("Sprite2D"):
			orb.get_node("Sprite2D").scale *= 2.8
	
	# Phóng thẳng về phía trước theo hướng nhìn với vận tốc cao
	var dir := Vector2(float(facing_direction), 0.0).normalized()
	if orb.has_method("shoot"):
		orb.shoot(dir, 620.0, bullet_lifetime * 1.6)
	
	# VFX: vòng sóng xung kích năng lượng khổng lồ phóng ra khi bắn
	var color := mage_element_color()
	spawn_class_shockwave(spawn_pos, color, 80.0)
	spawn_magic_cast_flare(spawn_pos)

# Ranger: kéo cung tụ khí rồi bắn một chùm ba mũi tên theo hình quạt.
func start_ranger_triple_volley() -> void:
	is_attacking = true
	is_special_casting = true
	special_cooldown_timer = RANGER_SPECIAL_COOLDOWN
	attack_cooldown_timer = 0.60
	
	var base_position := Vector2(0.0, -42.0)
	var pull_dir: float = -float(facing_direction)
	
	# Đổi sang tư thế giơ tay kéo cung ngắm bắn
	play_attack_animation("DrawBow")
	
	# Kéo căng tối đa với hào quang ngọc lục bảo
	if player_sprite:
		var tw := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(player_sprite, "position", base_position + Vector2(14.0 * pull_dir, -6.0), 0.14)
		tw.parallel().tween_property(player_sprite, "scale", Vector2(0.095, 0.145), 0.14)
		tw.parallel().tween_property(player_sprite, "rotation", 0.16 * pull_dir, 0.14)
		tw.parallel().tween_property(player_sprite, "modulate", Color(0.8, 2.5, 1.4, 1.0), 0.14)
		
	# Tụ 3 luồng năng lượng mũi tên
	for ang in [-0.18, 0.0, 0.18]:
		spawn_archer_draw_charge_vfx()
		
	if swing_sfx:
		swing_sfx.pitch_scale = 1.15
		swing_sfx.play()
		
	if is_inside_tree() and get_tree():
		await get_tree().create_timer(0.14).timeout
		
	# Bắn chùm 3 mũi tên thần tốc
	if swing_sfx:
		swing_sfx.pitch_scale = 1.6
		swing_sfx.play()
		
	for angle in [-0.18, 0.0, 0.18]:
		spawn_ranger_arrow(Vector2(float(facing_direction), angle).normalized(), 960.0)
		
	# Giật mạnh về trước
	if player_sprite:
		var shoot_tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		shoot_tw.tween_property(player_sprite, "position", base_position + Vector2(18.0 * float(facing_direction), -8.0), 0.07)
		shoot_tw.parallel().tween_property(player_sprite, "scale", Vector2(0.15, 0.10), 0.07)
		shoot_tw.parallel().tween_property(player_sprite, "rotation", -0.08 * pull_dir, 0.07)
		shoot_tw.parallel().tween_property(player_sprite, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.10)
		
		shoot_tw.tween_property(player_sprite, "position", base_position, 0.12)
		shoot_tw.parallel().tween_property(player_sprite, "scale", Vector2(0.12, 0.12), 0.12)
		shoot_tw.parallel().tween_property(player_sprite, "rotation", 0.0, 0.12)
		
	spawn_ranger_release_flash()
	shake_camera(4.5, 0.14)
	
	if is_inside_tree() and get_tree():
		await get_tree().create_timer(0.25).timeout
		
	if player_sprite:
		player_sprite.position = base_position
		player_sprite.scale = Vector2(0.12, 0.12)
		player_sprite.rotation = 0.0
		player_sprite.modulate = Color.WHITE
		
	# Hạ tay xuống tư thế bình thường
	play_attack_animation("Idle")
	
	is_special_casting = false
	is_attacking = false

func damage_targets_in_radius(radius: float, damage: float, knockback_direction: Vector2, apply_element: bool = false) -> void:
	if not is_inside_tree() or not get_tree():
		return
	var targets: Array[Node] = []
	targets.append_array(get_tree().get_nodes_in_group("Enemy"))
	targets.append_array(get_tree().get_nodes_in_group("Boss"))
	for target in targets:
		if not is_instance_valid(target) or not (target is Node2D):
			continue
		var offset: Vector2 = (target as Node2D).global_position - global_position
		if offset.length() > radius:
			continue
		var direction: Vector2 = knockback_direction if knockback_direction.length() > 0.0 else offset.normalized()
		if direction.length() == 0.0:
			direction = Vector2.RIGHT
		if apply_element and target.has_method("apply_element_effect"):
			target.apply_element_effect(current_element)
		if target.has_method("take_damage"):
			target.take_damage(damage, direction)
		elif target.has_method("take_hit"):
			target.take_hit(direction)
		play_hit_spark(target.global_position)

func spawn_knight_cyclone_vfx() -> void:
	if not slash_vfx or not slash_vfx.texture or not get_parent():
		return
	var cyclone := Sprite2D.new()
	cyclone.texture = slash_vfx.texture
	cyclone.global_position = global_position + Vector2(0.0, -42.0)
	cyclone.modulate = Color(2.5, 1.5, 0.3, 0.95)
	cyclone.scale = Vector2(0.08, 0.08)
	get_parent().add_child(cyclone)
	var tween := cyclone.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(cyclone, "scale", Vector2(0.42, 0.42), 0.36)
	tween.parallel().tween_property(cyclone, "rotation", TAU * 1.5, 0.36)
	tween.parallel().tween_property(cyclone, "modulate:a", 0.0, 0.36)
	tween.tween_callback(cyclone.queue_free)

func mage_element_color() -> Color:
	match current_element:
		1:
			return Color(3.2, 0.75, 0.1, 1.0)
		2:
			return Color(0.55, 2.1, 3.0, 1.0)
		_:
			return Color(2.0, 0.55, 3.0, 1.0)

func spawn_class_shockwave(origin: Vector2, color: Color, radius: float) -> void:
	if not slash_vfx or not slash_vfx.texture or not get_parent():
		return
	var ring := Sprite2D.new()
	ring.texture = slash_vfx.texture
	ring.global_position = origin
	ring.modulate = color
	ring.scale = Vector2(0.06, 0.06)
	get_parent().add_child(ring)
	var tween := ring.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var final_scale := radius * 0.004
	tween.parallel().tween_property(ring, "scale", Vector2(final_scale, final_scale), 0.30)
	tween.parallel().tween_property(ring, "rotation", TAU, 0.30)
	tween.parallel().tween_property(ring, "modulate:a", 0.0, 0.30)
	tween.tween_callback(ring.queue_free)

func spawn_ranger_arrow(direction: Vector2, speed: float) -> void:
	if bullet_scene == null or not get_parent():
		return
	var projectile := bullet_scene.instantiate()
	var bullet_marker := get_node_or_null("student/BulletMarker") as Marker2D
	projectile.global_position = bullet_marker.global_position if bullet_marker else global_position + Vector2(20.0 * facing_direction, -42.0)
	if projectile.has_method("set_element"):
		projectile.set_element(current_element)
	get_parent().add_child(projectile)
	if projectile.has_method("shoot"):
		projectile.shoot(direction, speed, bullet_lifetime)


func spawn_ranger_release_flash() -> void:
	if not slash_vfx or not slash_vfx.texture or not get_parent():
		return
	var flash := Sprite2D.new()
	flash.texture = slash_vfx.texture
	flash.global_position = global_position + Vector2(34.0 * facing_direction, -42.0)
	flash.modulate = Color(0.35, 2.4, 0.75, 1.0)
	flash.scale = Vector2(0.06, 0.06)
	get_parent().add_child(flash)
	var tween := flash.create_tween()
	tween.parallel().tween_property(flash, "scale", Vector2(0.16, 0.08), 0.12)
	tween.parallel().tween_property(flash, "modulate:a", 0.0, 0.12)
	tween.tween_callback(flash.queue_free)

func shoot_projectile():
	if bullet_scene == null:
		return
	var proj = bullet_scene.instantiate()
	var bullet_marker = $student/BulletMarker if has_node("student/BulletMarker") else null
	var spawn_pos = bullet_marker.global_position if bullet_marker else (global_position + Vector2(20.0 * facing_direction, -42.0))
	proj.global_position = spawn_pos
	
	if proj.has_method("set_element"):
		proj.set_element(current_element)
		
	var gm = get_node_or_null("/root/GameManager") if is_inside_tree() else null
	var speed_mult: float = 1.0
	if gm and "spear_wave_speed_mult" in gm:
		speed_mult = gm.spear_wave_speed_mult
	var dir = Vector2(facing_direction, randf_range(-0.03, 0.03)).normalized()
	get_parent().add_child(proj)
	
	# Kiểm tra trúng đích cự ly gần / điểm mù khi quái vật đứng sát hoặc trùng tọa độ (Point-Blank Hit Check)
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
					
				var dist = spawn_pos.distance_to(enemy_center)
				var center_dist = (global_position + Vector2(0, -40.0)).distance_to(enemy_center)
				var dx = (enemy_center.x - global_position.x) * float(facing_direction)
				var dy = abs(enemy_center.y - (global_position.y - 40.0))
				
				# Quái vật ở ngay trước mặt hoặc sát người chơi (bán kính <= 60px, chênh lệch độ cao <= 48px)
				if (dist <= 60.0 or center_dist <= 70.0) and dx >= -25.0 and dy <= 48.0:
					var kdir = Vector2(float(facing_direction), -0.4).normalized()
					if proj is BulletMage or proj.has_method("explode_aoe"):
						# Nếu là đạn băng có xuyên thấu (pierce)
						if "pierce_count" in proj and proj.pierce_count > 0:
							proj.pierce_count -= 1
							if proj.has_method("apply_single_target_damage"):
								proj.apply_single_target_damage(enemy)
							if proj.has_method("spawn_pierce_spark"):
								proj.spawn_pierce_spark(enemy_center)
						else:
							# Đạn nổ ngay lập tức trên thân kẻ địch
							proj.global_position = enemy_center
							proj.explode_aoe()
							proj.queue_free()
							return
					else:
						# Đạn thường / Cung tên trúng ngay mục tiêu
						apply_hit_to_enemy_advanced(enemy, kdir, 35.0, 0)
						proj.queue_free()
						return

	if proj.has_method("shoot"):
		proj.shoot(dir, 750.0 * speed_mult, bullet_lifetime)

# --------- KNIGHT TRUE MELEE COMBAT SYSTEM (3 THẾ ĐÁNH ĐỘC QUYỀN) ---------- #

func start_knight_combo():
	is_attacking = true
	combo_timer = COMBO_WINDOW
	var face_dir = float(facing_direction)
	var current_step = combo_step
	
	var base_dmg: float = 35.0
	var lunge_speed: float = 120.0
	var hit_cooldown: float = 0.26
	
	if player_sprite and player_sprite.sprite_frames and player_sprite.sprite_frames.has_animation("Attack"):
		player_sprite.play("Attack")
		
	match current_element:
		0: # ==================== THẾ 1: ⚔️ LONG ĐỘT THƯƠNG (DRAGON PIERCER) ====================
			# Đột kích xuyên giáp, tốc độ di chuyển và lướt càn quét cao nhất
			match current_step:
				0: # Đòn 1: Long Đột Kiếm Khí (Phóng kiếm khí rồng dài 260px xuyên toàn bộ quái)
					base_dmg = 40.0
					lunge_speed = 220.0
					hit_cooldown = 0.22
					attack_cooldown_timer = hit_cooldown
					if swing_sfx:
						swing_sfx.pitch_scale = randf_range(1.25, 1.4)
						swing_sfx.play()
					execute_dragon_beam_thrust(face_dir, base_dmg)
					_anim_knight_dragon_thrust(face_dir)
				1: # Đòn 2: Tam Điểm Long Kích (Đâm liên hoàn 3 mũi nhanh như chớp)
					base_dmg = 50.0
					lunge_speed = 160.0
					hit_cooldown = 0.26
					attack_cooldown_timer = hit_cooldown
					if swing_sfx:
						swing_sfx.pitch_scale = randf_range(1.1, 1.25)
						swing_sfx.play()
					execute_dragon_triple_thrust(face_dir, base_dmg)
					_anim_knight_dragon_multi_stab(face_dir)
				2: # Đòn 3: Long Dược Trọng Kích (Lao bóng rồng vàng 180px húc văng toàn bộ kẻ địch)
					base_dmg = 78.0
					lunge_speed = 240.0
					hit_cooldown = 0.40
					attack_cooldown_timer = hit_cooldown
					if hit_sfx:
						hit_sfx.pitch_scale = 0.85
						hit_sfx.play()
					execute_dragon_charge_smash(face_dir, base_dmg)
					_anim_knight_dragon_charge(face_dir)
					shake_camera(7.0, 0.2)
					
		1: # ==================== THẾ 2: 🔥 BẠO VIÊM THƯƠNG (INFERNO CLEAVE) ====================
			# Chém quét bán kính rộng, xoay 360 độ và nổ nham thạch
			match current_step:
				0: # Đòn 1: Liệt Diệm Trảm (Vung nhát chém lửa hình bán nguyệt rộng 150px)
					base_dmg = 38.0
					lunge_speed = 160.0
					hit_cooldown = 0.26
					attack_cooldown_timer = hit_cooldown
					if swing_sfx:
						swing_sfx.pitch_scale = randf_range(0.85, 0.95)
						swing_sfx.play()
					execute_flame_cleave_thrust(face_dir, base_dmg)
					_anim_knight_inferno_sweep(face_dir)
				1: # Đòn 2: Hỏa Luân 360° (Xoay thương trọn vòng tròn thiêu đốt xung quanh & tạo tường lửa)
					base_dmg = 52.0
					lunge_speed = 130.0
					hit_cooldown = 0.30
					attack_cooldown_timer = hit_cooldown
					if swing_sfx:
						swing_sfx.pitch_scale = randf_range(0.8, 0.9)
						swing_sfx.play()
					execute_flame_whirlwind_360(face_dir, base_dmg)
					_anim_knight_inferno_spin()
				2: # Đòn 3: Nham Thạch Nổ Tung (Bổ nứt địa chấn dung nham bán kính 160px hất tung quái)
					base_dmg = 82.0
					lunge_speed = 100.0
					hit_cooldown = 0.44
					attack_cooldown_timer = hit_cooldown
					if hit_sfx:
						hit_sfx.pitch_scale = 0.75
						hit_sfx.play()
					execute_magma_eruption_smash(face_dir, base_dmg)
					_anim_knight_inferno_eruption()
					shake_camera(8.5, 0.25)
					
		2: # ==================== THẾ 3: 🛡️ TRẤN THIÊN THƯƠNG (TITAN GUARDIAN) ====================
			# Đòn đánh nặng ngàn cân, trọng lực chấn động, hất tung & cọc đá khóa chân Stun 1.5s
			match current_step:
				0: # Đòn 1: Địa Chấn Trọng Kích (Cắm thương tạo sóng chấn động làm rung chuyển mặt đất)
					base_dmg = 36.0
					lunge_speed = 140.0
					hit_cooldown = 0.26
					attack_cooldown_timer = hit_cooldown
					if swing_sfx:
						swing_sfx.pitch_scale = randf_range(0.9, 1.05)
						swing_sfx.play()
					execute_titan_ground_slam(face_dir, base_dmg)
					_anim_knight_titan_stomp(face_dir)
				1: # Đòn 2: Kình Thiên Hất Tung (Hất ngược mũi thương từ đất lên trời hất tung kẻ địch)
					base_dmg = 48.0
					lunge_speed = 130.0
					hit_cooldown = 0.30
					attack_cooldown_timer = hit_cooldown
					if swing_sfx:
						swing_sfx.pitch_scale = randf_range(0.85, 0.95)
						swing_sfx.play()
					execute_titan_sky_launcher(face_dir, base_dmg)
					_anim_knight_titan_uppercut(face_dir)
				2: # Đòn 3: Trấn Địa Kim Cang (Triệu hồi 4 cọc đá kim cang trồi lên khóa chân Stun 1.5s)
					base_dmg = 74.0
					lunge_speed = 90.0
					hit_cooldown = 0.44
					attack_cooldown_timer = hit_cooldown
					if hit_sfx:
						hit_sfx.pitch_scale = 0.7
						hit_sfx.play()
					execute_titan_pillar_lock(face_dir, base_dmg)
					_anim_knight_titan_earth_shatter()
					shake_camera(7.5, 0.22)
	
	# Lướt tới phía trước theo hướng đánh
	if is_on_floor():
		velocity.x = face_dir * lunge_speed
		
	is_slash_active = true
	if melee_area:
		melee_area.set_deferred("monitoring", true)
		melee_area.set_deferred("monitorable", true)
	check_melee_hits_advanced(face_dir, base_dmg, current_step)
	
	combo_step = (combo_step + 1) % 3
	
	if is_inside_tree() and get_tree():
		await get_tree().create_timer(hit_cooldown * 0.7).timeout
	is_slash_active = false
	if melee_area:
		melee_area.set_deferred("monitoring", false)
		melee_area.set_deferred("monitorable", false)
	if is_inside_tree() and get_tree():
		await get_tree().create_timer(hit_cooldown * 0.3).timeout
	is_attacking = false


# ========================================================================= #
#          CHI TIẾT 3 THẾ VÕ THUẬT TRƯỜNG THƯƠNG CỦA HIỆP SĨ (KNIGHT)        #
# ========================================================================= #

# --------- 1. THẾ 1: LONG ĐỘT THƯƠNG (DRAGON PIERCER) --------- #

func execute_dragon_beam_thrust(face_dir: float, dmg: float) -> void:
	if not is_inside_tree() or not get_parent(): return
	var origin: Vector2 = global_position + Vector2(25.0 * face_dir, -36.0)
	
	# Luồng khí rồng vàng kim dài 260px phóng vút tới trước
	var beam := Sprite2D.new()
	beam.texture = load("res://Assets/Spritesheet/laser_bullet.png")
	beam.global_position = origin
	beam.modulate = Color(2.8, 2.2, 0.4, 1.0)
	beam.scale = Vector2(0.08, 0.05)
	beam.rotation = (Vector2(face_dir, 0.0)).angle()
	get_parent().add_child(beam)
	
	var tw = beam.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(beam, "scale", Vector2(0.85, 0.14), 0.11)
	tw.parallel().tween_property(beam, "position:x", origin.x + 140.0 * face_dir, 0.11)
	tw.tween_property(beam, "modulate:a", 0.0, 0.09)
	tw.tween_callback(beam.queue_free)
	
	# Hạt kiếm khí vàng kim
	var sparks := CPUParticles2D.new()
	sparks.emitting = false
	sparks.one_shot = true
	sparks.explosiveness = 0.95
	sparks.amount = 22
	sparks.lifetime = 0.28
	sparks.spread = 40.0
	sparks.direction = Vector2(face_dir, 0.0)
	sparks.gravity = Vector2.ZERO
	sparks.initial_velocity_min = 140.0
	sparks.initial_velocity_max = 260.0
	sparks.scale_amount_min = 2.5
	sparks.scale_amount_max = 5.5
	sparks.color = Color(2.8, 2.2, 0.4, 1.0)
	sparks.global_position = origin
	get_parent().add_child(sparks)
	sparks.emitting = true
	get_tree().create_timer(0.35).timeout.connect(sparks.queue_free)
	
	# Sát thương xuyên quái toàn bộ hàng dọc 260px
	var targets = _get_enemies_in_box(origin, Vector2(260.0 * face_dir, 0.0), 45.0)
	for t in targets:
		if is_instance_valid(t):
			if t.has_method("apply_element_effect"): t.apply_element_effect(0)
			if t.has_method("take_damage"): t.take_damage(dmg, Vector2(face_dir * 1.3, -0.2).normalized())
			play_hit_spark(t.global_position)

func execute_dragon_triple_thrust(face_dir: float, dmg: float) -> void:
	if not is_inside_tree() or not get_parent(): return
	var origin: Vector2 = global_position + Vector2(25.0 * face_dir, -36.0)
	
	# Bắn liên kích 3 mũi đâm nhanh như chớp (-12°, 0°, +12°)
	var angles = [-0.18, 0.0, 0.18]
	for a in angles:
		var dir = Vector2(face_dir, a).normalized()
		var sp := Sprite2D.new()
		sp.texture = load("res://Assets/Spritesheet/laser_bullet.png")
		sp.global_position = origin
		sp.modulate = Color(2.6, 2.0, 0.5, 0.9)
		sp.scale = Vector2(0.25, 0.06)
		sp.rotation = dir.angle()
		get_parent().add_child(sp)
		
		var tw = sp.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(sp, "position", origin + dir * 160.0, 0.14)
		tw.tween_property(sp, "modulate:a", 0.0, 0.08)
		tw.tween_callback(sp.queue_free)
		
	damage_targets_in_radius_at(origin + Vector2(60.0 * face_dir, 0.0), 100.0, dmg, Vector2(face_dir, -0.3).normalized(), true)

func execute_dragon_charge_smash(face_dir: float, dmg: float) -> void:
	if not is_inside_tree() or not get_parent(): return
	var center: Vector2 = global_position + Vector2(70.0 * face_dir, -20.0)
	
	# Bóng rồng vàng lao vút càn quét
	var dragon_wave := Sprite2D.new()
	dragon_wave.texture = load("res://Assets/Spritesheet/laser_bullet.png")
	dragon_wave.global_position = global_position + Vector2(20.0 * face_dir, -30.0)
	dragon_wave.modulate = Color(3.0, 2.4, 0.5, 1.0)
	dragon_wave.scale = Vector2(0.2, 0.2)
	dragon_wave.rotation = (Vector2(face_dir, 0.0)).angle()
	get_parent().add_child(dragon_wave)
	
	var tw = dragon_wave.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(dragon_wave, "scale", Vector2(0.8, 0.35), 0.16)
	tw.parallel().tween_property(dragon_wave, "position:x", dragon_wave.position.x + 150.0 * face_dir, 0.16)
	tw.tween_property(dragon_wave, "modulate:a", 0.0, 0.10)
	tw.tween_callback(dragon_wave.queue_free)
	
	spawn_class_shockwave(center, Color(2.8, 2.2, 0.4, 0.95), 140.0)
	damage_targets_in_radius_at(center, 150.0, dmg, Vector2(face_dir * 1.5, -0.6).normalized(), true)


# --------- 2. THẾ 2: BẠO VIÊM THƯƠNG (INFERNO CLEAVE) --------- #

func execute_flame_cleave_thrust(face_dir: float, dmg: float) -> void:
	if not is_inside_tree() or not get_parent(): return
	var origin: Vector2 = global_position + Vector2(30.0 * face_dir, -36.0)
	
	# Vệt chém lửa hình bán nguyệt rộng 150px
	if slash_vfx:
		slash_vfx.visible = true
		slash_vfx.position = Vector2(45.0, -35.0)
		slash_vfx.rotation = -0.7
		slash_vfx.scale = Vector2(0.08, 0.08)
		slash_vfx.modulate = Color(3.8, 0.85, 0.15, 1.0)
		var vtw = create_tween()
		vtw.parallel().tween_property(slash_vfx, "position", Vector2(75.0, -50.0), 0.15)
		vtw.parallel().tween_property(slash_vfx, "scale", Vector2(0.26, 0.26), 0.15)
		vtw.parallel().tween_property(slash_vfx, "rotation", 0.3, 0.15)
		vtw.parallel().tween_property(slash_vfx, "modulate:a", 0.0, 0.15)
		vtw.tween_callback(slash_vfx.hide)
		
	# Hạt lửa bốc cháy
	var fire_p := CPUParticles2D.new()
	fire_p.emitting = false
	fire_p.one_shot = true
	fire_p.explosiveness = 0.9
	fire_p.amount = 26
	fire_p.lifetime = 0.35
	fire_p.direction = Vector2(face_dir, -0.2).normalized()
	fire_p.spread = 50.0
	fire_p.gravity = Vector2(0, -90.0)
	fire_p.initial_velocity_min = 120.0
	fire_p.initial_velocity_max = 240.0
	fire_p.scale_amount_min = 3.5
	fire_p.scale_amount_max = 7.0
	fire_p.color = Color(3.6, 0.8, 0.15, 1.0)
	fire_p.global_position = origin
	get_parent().add_child(fire_p)
	fire_p.emitting = true
	get_tree().create_timer(0.45).timeout.connect(fire_p.queue_free)
	
	damage_targets_in_radius_at(origin + Vector2(45.0 * face_dir, 0.0), 110.0, dmg, Vector2(face_dir, -0.3).normalized(), true)

func execute_flame_whirlwind_360(face_dir: float, dmg: float) -> void:
	if not is_inside_tree() or not get_parent(): return
	var center: Vector2 = global_position + Vector2(0.0, -30.0)
	
	# Vòng xoáy lửa 360 độ quanh người
	var whirl := Sprite2D.new()
	whirl.texture = load("res://Assets/Spritesheet/laser_bullet.png")
	whirl.global_position = center
	whirl.modulate = Color(3.8, 0.85, 0.15, 1.0)
	whirl.scale = Vector2(0.12, 0.12)
	get_parent().add_child(whirl)
	
	var wtw = whirl.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	wtw.parallel().tween_property(whirl, "scale", Vector2(0.55, 0.55), 0.18)
	wtw.parallel().tween_property(whirl, "rotation", TAU, 0.18)
	wtw.tween_property(whirl, "modulate:a", 0.0, 0.10)
	wtw.tween_callback(whirl.queue_free)
	
	spawn_class_shockwave(center, Color(3.6, 0.8, 0.1, 0.95), 130.0)
	damage_targets_in_radius_at(center, 130.0, dmg, Vector2(face_dir, -0.4).normalized(), true)
	
	# Để lại vệt lửa trên đất cháy trong 1.3s
	_spawn_ground_fire_wall(global_position + Vector2(40.0 * face_dir, 0.0), dmg * 0.4)

func _spawn_ground_fire_wall(ground_pos: Vector2, tick_dmg: float) -> void:
	if not is_inside_tree() or not get_parent(): return
	var fire_wall = FireColumnScript.new()
	get_parent().add_child(fire_wall)
	fire_wall.setup(ground_pos, tick_dmg, Vector2(float(facing_direction), -0.2))

func execute_magma_eruption_smash(face_dir: float, dmg: float) -> void:
	if not is_inside_tree() or not get_parent(): return
	var impact_pos: Vector2 = global_position + Vector2(65.0 * face_dir, 0.0)
	
	spawn_class_shockwave(impact_pos, Color(3.6, 0.8, 0.1, 0.95), 160.0)
	
	var crater_p := CPUParticles2D.new()
	crater_p.emitting = false
	crater_p.one_shot = true
	crater_p.explosiveness = 0.95
	crater_p.amount = 45
	crater_p.lifetime = 0.45
	crater_p.direction = Vector2(0, -1)
	crater_p.spread = 110.0
	crater_p.gravity = Vector2(0, -120.0)
	crater_p.initial_velocity_min = 120.0
	crater_p.initial_velocity_max = 280.0
	crater_p.scale_amount_min = 4.0
	crater_p.scale_amount_max = 8.5
	crater_p.color = Color(3.8, 0.8, 0.1, 1.0)
	crater_p.global_position = impact_pos
	get_parent().add_child(crater_p)
	crater_p.emitting = true
	get_tree().create_timer(0.55).timeout.connect(crater_p.queue_free)
	
	damage_targets_in_radius_at(impact_pos, 160.0, dmg, Vector2(face_dir * 0.7, -0.9).normalized(), true)


# --------- 3. THẾ 3: TRẤN THIÊN THƯƠNG (TITAN GUARDIAN) --------- #

func execute_titan_ground_slam(face_dir: float, dmg: float) -> void:
	if not is_inside_tree() or not get_parent(): return
	var slam_pos = global_position + Vector2(50.0 * face_dir, 0.0)
	
	# Sóng chấn động rung chuyển mặt đất
	spawn_class_shockwave(slam_pos, Color(1.8, 1.4, 0.3, 0.95), 110.0)
	
	var rock_p := CPUParticles2D.new()
	rock_p.emitting = false
	rock_p.one_shot = true
	rock_p.explosiveness = 0.95
	rock_p.amount = 20
	rock_p.lifetime = 0.35
	rock_p.direction = Vector2(0, -1)
	rock_p.spread = 70.0
	rock_p.gravity = Vector2(0, 80.0)
	rock_p.initial_velocity_min = 80.0
	rock_p.initial_velocity_max = 180.0
	rock_p.scale_amount_min = 3.0
	rock_p.scale_amount_max = 6.0
	rock_p.color = Color(1.8, 1.4, 0.3, 1.0)
	rock_p.global_position = slam_pos
	get_parent().add_child(rock_p)
	rock_p.emitting = true
	get_tree().create_timer(0.4).timeout.connect(rock_p.queue_free)
	
	damage_targets_in_radius_at(slam_pos, 110.0, dmg, Vector2(face_dir * 0.6, -0.4).normalized(), true)

func execute_titan_sky_launcher(face_dir: float, dmg: float) -> void:
	if not is_inside_tree() or not get_parent(): return
	var center = global_position + Vector2(55.0 * face_dir, -30.0)
	
	# Hất ngược mũi thương từ đất lên trời tung sóng xung kích
	var beam := Sprite2D.new()
	beam.texture = load("res://Assets/Spritesheet/laser_bullet.png")
	beam.global_position = center
	beam.modulate = Color(2.0, 1.5, 0.3, 1.0)
	beam.scale = Vector2(0.14, 0.08)
	beam.rotation = -PI / 2.0 # Hướng thẳng lên trời
	get_parent().add_child(beam)
	
	var tw = beam.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(beam, "scale", Vector2(0.35, 0.75), 0.15)
	tw.parallel().tween_property(beam, "position:y", center.y - 65.0, 0.15)
	tw.tween_property(beam, "modulate:a", 0.0, 0.10)
	tw.tween_callback(beam.queue_free)
	
	# Hất tung quái vật lên không trung
	damage_targets_in_radius_at(center, 120.0, dmg, Vector2(face_dir * 0.2, -1.2).normalized(), true)

func execute_titan_pillar_lock(face_dir: float, dmg: float) -> void:
	if not is_inside_tree() or not get_parent(): return
	var origin: Vector2 = global_position + Vector2(25.0 * face_dir, 0.0)
	
	# Triệu hồi 4 cọc đá kim cang trồi lên khóa chân và đè bẹp quái vật (Stun 1.5s)
	for i in range(4):
		var pillar_x = origin.x + float(i) * 36.0 * face_dir
		var p_pos = Vector2(pillar_x, origin.y)
		_spawn_ground_titan_pillar(p_pos, i * 0.03)
		
	spawn_class_shockwave(origin + Vector2(60.0 * face_dir, 0.0), Color(1.8, 1.4, 0.3, 0.95), 140.0)
	damage_targets_in_radius_at(origin + Vector2(60.0 * face_dir, 0.0), 150.0, dmg, Vector2(face_dir * 0.4, -0.3).normalized(), true)

func _spawn_ground_titan_pillar(pos: Vector2, delay: float) -> void:
	if not is_inside_tree() or not get_parent(): return
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
		if not is_inside_tree() or not get_parent(): return
		
	var pillar := Sprite2D.new()
	pillar.texture = load("res://Assets/Spritesheet/laser_bullet.png")
	pillar.global_position = pos + Vector2(0.0, 10.0)
	pillar.modulate = Color(2.0, 1.5, 0.4, 1.0)
	pillar.scale = Vector2(0.18, 0.05)
	pillar.rotation = -PI / 2.0
	get_parent().add_child(pillar)
	
	var stw = pillar.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	stw.parallel().tween_property(pillar, "scale", Vector2(0.28, 0.8), 0.10)
	stw.parallel().tween_property(pillar, "position:y", pos.y - 35.0, 0.10)
	stw.tween_interval(0.35)
	stw.tween_property(pillar, "modulate:a", 0.0, 0.20)
	stw.tween_callback(pillar.queue_free)
	
	# Khóa chân Stun quái vật tại vị trí cọc đá
	if get_tree():
		var enemies = get_tree().get_nodes_in_group("Enemy") + get_tree().get_nodes_in_group("Boss")
		for en in enemies:
			if is_instance_valid(en) and en is Node2D:
				if pos.distance_to(en.global_position) <= 45.0:
					if en.has_method("apply_element_effect"):
						en.apply_element_effect(2) # Stun / Freeze solid 1.5s


# --------- TIỆN ÍCH TÌM KIẾM QUÁI VẬT TRONG HỘP/PHẠM VI ---------- #

func _get_enemies_in_box(start_pos: Vector2, offset: Vector2, half_height: float) -> Array:
	var result: Array = []
	if not is_inside_tree() or not get_tree(): return result
	var all_enemies: Array = get_tree().get_nodes_in_group("Enemy") + get_tree().get_nodes_in_group("Boss")
	
	var min_x = min(start_pos.x, start_pos.x + offset.x) - 10.0
	var max_x = max(start_pos.x, start_pos.x + offset.x) + 10.0
	var min_y = start_pos.y - half_height
	var max_y = start_pos.y + half_height
	
	for e in all_enemies:
		if is_instance_valid(e) and e is Node2D:
			var ep = e.global_position
			if ep.x >= min_x and ep.x <= max_x and ep.y >= min_y and ep.y <= max_y:
				result.append(e)
	return result


# --------- HOẠT ẢNH VŨ KHÍ CẬN CHIẾN ---------- #

func animate_weapon_thrust():
	var spear = get_node_or_null("student/WeaponSpear")
	if not spear or not spear.visible: return
	var tw = create_tween()
	tw.tween_property(spear, "position:x", 65.0, 0.08)
	tw.tween_property(spear, "position:x", 35.0, 0.12)

func animate_weapon_slash():
	var spear = get_node_or_null("student/WeaponSpear")
	if not spear or not spear.visible: return
	var tw = create_tween()
	tw.tween_property(spear, "rotation", -0.6, 0.08)
	tw.tween_property(spear, "rotation", 0.3, 0.14)
	tw.tween_property(spear, "rotation", 0.0, 0.08)

func animate_weapon_smash():
	var spear = get_node_or_null("student/WeaponSpear")
	if not spear or not spear.visible: return
	var tw = create_tween()
	tw.tween_property(spear, "rotation", -1.0, 0.1)
	tw.tween_property(spear, "rotation", 0.9, 0.12)
	tw.tween_property(spear, "rotation", 0.0, 0.12)


# ========================================================================= #
#   KNIGHT: 9 ANIMATION BODY RIÊNG BIỆT (3 THẾ x 3 COMBO STEP)            #
# ========================================================================= #

# --- THẾ 1: LONG ĐỘT THƯƠNG - Body animation nhanh, kéo dài, tập trung phóng tới ---

func _anim_knight_dragon_thrust(face_dir: float) -> void:
	# Đòn 1: Nghiêng người phóng thương tốc chiến - kéo dài body ngang rồi snap lại
	if not player_node: return
	var spear = get_node_or_null("student/WeaponSpear")
	var tw = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Nghiêng người về trước, stretch ngang mỏng dọc
	tw.tween_property(self, "scale", Vector2(1.25, 0.82), 0.06)
	tw.parallel().tween_property(player_node, "rotation", 0.15 * face_dir, 0.06)
	# Snap ngược về
	tw.tween_property(self, "scale", Vector2(0.92, 1.12), 0.06)
	tw.parallel().tween_property(player_node, "rotation", -0.05 * face_dir, 0.06)
	# Hồi phục
	tw.tween_property(self, "scale", Vector2(1.0, 1.0), 0.08)
	tw.parallel().tween_property(player_node, "rotation", 0.0, 0.08)
	if spear and spear.visible:
		var stw = create_tween()
		stw.tween_property(spear, "position:x", 75.0, 0.06)
		stw.tween_property(spear, "position:x", 35.0, 0.14)
	# Flash vàng kim chớp nhoáng
	if player_sprite:
		var ftw = create_tween()
		ftw.tween_property(player_sprite, "modulate", Color(2.8, 2.2, 0.5, 1.0), 0.04)
		ftw.tween_property(player_sprite, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.08)

func _anim_knight_dragon_multi_stab(face_dir: float) -> void:
	# Đòn 2: Rung lắc liên hoàn 3 nhịp cực nhanh
	if not player_node: return
	var spear = get_node_or_null("student/WeaponSpear")
	var tw = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# 3 nhịp đâm nhanh, body rung trái-phải
	for i in range(3):
		var offset_x = 6.0 * face_dir if i % 2 == 0 else -4.0 * face_dir
		tw.tween_property(player_node, "position:x", offset_x, 0.03)
		tw.parallel().tween_property(self, "scale", Vector2(1.12, 0.92), 0.03)
		tw.tween_property(player_node, "position:x", 0.0, 0.03)
		tw.parallel().tween_property(self, "scale", Vector2(1.0, 1.0), 0.03)
	# Flash vàng mỗi nhịp
	if player_sprite:
		var ftw = create_tween()
		for j in range(3):
			ftw.tween_property(player_sprite, "modulate", Color(2.5, 2.0, 0.6, 1.0), 0.02)
			ftw.tween_property(player_sprite, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.04)
	if spear and spear.visible:
		var stw = create_tween()
		stw.tween_property(spear, "rotation", -0.35, 0.05)
		stw.tween_property(spear, "rotation", 0.25, 0.06)
		stw.tween_property(spear, "rotation", -0.15, 0.04)
		stw.tween_property(spear, "rotation", 0.0, 0.06)

func _anim_knight_dragon_charge(face_dir: float) -> void:
	# Đòn 3: Lao người về trước toàn lực - stretch mạnh ngang rồi nén lại
	if not player_node: return
	var spear = get_node_or_null("student/WeaponSpear")
	var tw = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Nén lại trước khi lao
	tw.tween_property(self, "scale", Vector2(0.78, 1.28), 0.06)
	tw.parallel().tween_property(player_node, "rotation", -0.12 * face_dir, 0.06)
	# Bung ra lao tới - stretch dài ngang cực mạnh
	tw.tween_property(self, "scale", Vector2(1.4, 0.72), 0.08)
	tw.parallel().tween_property(player_node, "rotation", 0.22 * face_dir, 0.08)
	# Giật lại recoil
	tw.tween_property(self, "scale", Vector2(0.88, 1.15), 0.08)
	tw.parallel().tween_property(player_node, "rotation", -0.08 * face_dir, 0.08)
	# Hồi phục
	tw.tween_property(self, "scale", Vector2(1.0, 1.0), 0.10)
	tw.parallel().tween_property(player_node, "rotation", 0.0, 0.10)
	if spear and spear.visible:
		var stw = create_tween()
		stw.tween_property(spear, "position:x", 85.0, 0.08)
		stw.tween_property(spear, "rotation", 0.4, 0.08)
		stw.tween_property(spear, "position:x", 35.0, 0.16)
		stw.tween_property(spear, "rotation", 0.0, 0.16)
	# Flash vàng rực rỡ
	if player_sprite:
		var ftw = create_tween()
		ftw.tween_property(player_sprite, "modulate", Color(3.0, 2.4, 0.5, 1.0), 0.06)
		ftw.tween_property(player_sprite, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.12)

# --- THẾ 2: BẠO VIÊM THƯƠNG - Body animation mãnh liệt, xoay tròn, rung lắc ---

func _anim_knight_inferno_sweep(face_dir: float) -> void:
	# Đòn 1: Quét ngang mãnh liệt - body xoay nghiêng + squash
	if not player_node: return
	var spear = get_node_or_null("student/WeaponSpear")
	var tw = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Nghiêng lưng ra sau chuẩn bị
	tw.tween_property(player_node, "rotation", -0.25 * face_dir, 0.05)
	tw.parallel().tween_property(self, "scale", Vector2(0.9, 1.14), 0.05)
	# Quét ngang mãnh liệt
	tw.tween_property(player_node, "rotation", 0.30 * face_dir, 0.08)
	tw.parallel().tween_property(self, "scale", Vector2(1.18, 0.85), 0.08)
	# Hồi phục
	tw.tween_property(player_node, "rotation", 0.0, 0.10)
	tw.parallel().tween_property(self, "scale", Vector2(1.0, 1.0), 0.10)
	if spear and spear.visible:
		var stw = create_tween()
		stw.tween_property(spear, "rotation", -0.8, 0.06)
		stw.tween_property(spear, "rotation", 0.5, 0.10)
		stw.tween_property(spear, "rotation", 0.0, 0.08)
	# Flash cam đỏ cháy rực
	if player_sprite:
		var ftw = create_tween()
		ftw.tween_property(player_sprite, "modulate", Color(3.5, 0.9, 0.2, 1.0), 0.05)
		ftw.tween_property(player_sprite, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.10)

func _anim_knight_inferno_spin() -> void:
	# Đòn 2: Xoay tròn 360° cả người - fire tornado
	if not player_node: return
	var spear = get_node_or_null("student/WeaponSpear")
	var orig_rot = player_node.rotation
	var tw = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	# Xoay trọn 1 vòng + scale nhịp phập phồng khi quay
	tw.tween_property(player_node, "rotation", orig_rot + TAU, 0.22)
	var stw = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	stw.tween_property(self, "scale", Vector2(1.2, 0.85), 0.06)
	stw.tween_property(self, "scale", Vector2(0.85, 1.2), 0.06)
	stw.tween_property(self, "scale", Vector2(1.15, 0.88), 0.05)
	stw.tween_property(self, "scale", Vector2(1.0, 1.0), 0.05)
	# Reset rotation after spin
	var rtw = create_tween()
	rtw.tween_interval(0.23)
	rtw.tween_property(player_node, "rotation", 0.0, 0.01)
	if spear and spear.visible:
		var sptw = create_tween()
		sptw.tween_property(spear, "rotation", TAU, 0.22)
		sptw.tween_property(spear, "rotation", 0.0, 0.01)
	# Flash lửa đỏ rực liên tục khi quay
	if player_sprite:
		var ftw = create_tween()
		for k in range(3):
			ftw.tween_property(player_sprite, "modulate", Color(3.8, 0.8, 0.2, 1.0), 0.03)
			ftw.tween_property(player_sprite, "modulate", Color(2.5, 1.2, 0.3, 1.0), 0.04)
		ftw.tween_property(player_sprite, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.06)

func _anim_knight_inferno_eruption() -> void:
	# Đòn 3: Nhảy lên rồi dập xuống - nổ nham thạch
	if not player_node: return
	var spear = get_node_or_null("student/WeaponSpear")
	# Nhún lên
	var tw = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", Vector2(0.75, 1.35), 0.08)
	tw.parallel().tween_property(player_node, "position:y", -18.0, 0.08)
	# Dập mạnh xuống đất
	tw.tween_property(self, "scale", Vector2(1.45, 0.65), 0.06)
	tw.parallel().tween_property(player_node, "position:y", 8.0, 0.06)
	# Nảy lên nhẹ
	tw.tween_property(self, "scale", Vector2(0.92, 1.1), 0.06)
	tw.parallel().tween_property(player_node, "position:y", -3.0, 0.06)
	# Hồi phục
	tw.tween_property(self, "scale", Vector2(1.0, 1.0), 0.08)
	tw.parallel().tween_property(player_node, "position:y", 0.0, 0.08)
	if spear and spear.visible:
		var stw = create_tween()
		stw.tween_property(spear, "rotation", -1.2, 0.08)
		stw.tween_property(spear, "rotation", 1.0, 0.06)
		stw.tween_property(spear, "rotation", 0.0, 0.14)
	# Flash cam đỏ chớp cực mạnh
	if player_sprite:
		var ftw = create_tween()
		ftw.tween_property(player_sprite, "modulate", Color(4.0, 1.0, 0.15, 1.0), 0.06)
		ftw.tween_property(player_sprite, "modulate", Color(2.0, 0.6, 0.1, 1.0), 0.08)
		ftw.tween_property(player_sprite, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.10)

# --- THẾ 3: TRẤN THIÊN THƯƠNG - Body animation nặng nề, chậm rãi, chấn động ---

func _anim_knight_titan_stomp(face_dir: float) -> void:
	# Đòn 1: Cắm thương xuống đất - body ép nén dập xuống
	if not player_node: return
	var spear = get_node_or_null("student/WeaponSpear")
	var tw = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Giơ lên chuẩn bị
	tw.tween_property(self, "scale", Vector2(0.88, 1.18), 0.06)
	tw.parallel().tween_property(player_node, "position:y", -8.0, 0.06)
	# Dập xuống mạnh mẽ
	tw.tween_property(self, "scale", Vector2(1.28, 0.78), 0.05)
	tw.parallel().tween_property(player_node, "position:y", 6.0, 0.05)
	# Rung chấn động
	var stw = create_tween()
	for i in range(4):
		stw.tween_property(player_node, "position:x", randf_range(-4, 4), 0.02)
	stw.tween_property(player_node, "position:x", 0.0, 0.03)
	# Hồi phục
	tw.tween_property(self, "scale", Vector2(1.0, 1.0), 0.10)
	tw.parallel().tween_property(player_node, "position:y", 0.0, 0.10)
	if spear and spear.visible:
		var sptw = create_tween()
		sptw.tween_property(spear, "rotation", 1.57, 0.06)
		sptw.tween_property(spear, "position:x", 55.0, 0.06)
		sptw.tween_property(spear, "rotation", 0.0, 0.10)
		sptw.tween_property(spear, "position:x", 35.0, 0.10)
	# Flash đất đá nâu vàng
	if player_sprite:
		var ftw = create_tween()
		ftw.tween_property(player_sprite, "modulate", Color(2.0, 1.5, 0.4, 1.0), 0.05)
		ftw.tween_property(player_sprite, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.10)

func _anim_knight_titan_uppercut(face_dir: float) -> void:
	# Đòn 2: Hất ngược lên trời - body bung lên dọc
	if not player_node: return
	var spear = get_node_or_null("student/WeaponSpear")
	var tw = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Nhún xuống chuẩn bị
	tw.tween_property(self, "scale", Vector2(1.2, 0.78), 0.06)
	tw.parallel().tween_property(player_node, "position:y", 5.0, 0.06)
	# Bung lên trời
	tw.tween_property(self, "scale", Vector2(0.78, 1.35), 0.07)
	tw.parallel().tween_property(player_node, "position:y", -15.0, 0.07)
	tw.parallel().tween_property(player_node, "rotation", -0.15 * face_dir, 0.07)
	# Rơi xuống
	tw.tween_property(self, "scale", Vector2(1.05, 0.95), 0.06)
	tw.parallel().tween_property(player_node, "position:y", 2.0, 0.06)
	# Hồi phục
	tw.tween_property(self, "scale", Vector2(1.0, 1.0), 0.08)
	tw.parallel().tween_property(player_node, "position:y", 0.0, 0.08)
	tw.parallel().tween_property(player_node, "rotation", 0.0, 0.08)
	if spear and spear.visible:
		var stw = create_tween()
		stw.tween_property(spear, "rotation", -1.2, 0.06)
		stw.tween_property(spear, "position:y", -25.0, 0.07)
		stw.tween_property(spear, "rotation", 0.0, 0.10)
		stw.tween_property(spear, "position:y", 0.0, 0.10)
	# Flash nâu vàng sáng
	if player_sprite:
		var ftw = create_tween()
		ftw.tween_property(player_sprite, "modulate", Color(2.2, 1.6, 0.35, 1.0), 0.06)
		ftw.tween_property(player_sprite, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.10)

func _anim_knight_titan_earth_shatter() -> void:
	# Đòn 3: Triệu hồi cọc đá - toàn thân rung lắc chấn động cực mạnh
	if not player_node: return
	var spear = get_node_or_null("student/WeaponSpear")
	# Giơ thương lên trời chuẩn bị
	var tw = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", Vector2(0.82, 1.28), 0.10)
	tw.parallel().tween_property(player_node, "position:y", -12.0, 0.10)
	# Nện xuống đất kinh thiên
	tw.tween_property(self, "scale", Vector2(1.38, 0.68), 0.06)
	tw.parallel().tween_property(player_node, "position:y", 10.0, 0.06)
	# Rung chấn động liên tục
	var stw = create_tween()
	for i in range(6):
		var rx = randf_range(-6, 6)
		var ry = randf_range(-3, 3)
		stw.tween_property(player_node, "position", Vector2(rx, ry), 0.02)
	stw.tween_property(player_node, "position", Vector2.ZERO, 0.04)
	# Hồi phục chậm (nặng nề)
	tw.tween_property(self, "scale", Vector2(0.95, 1.08), 0.08)
	tw.tween_property(self, "scale", Vector2(1.0, 1.0), 0.10)
	tw.parallel().tween_property(player_node, "position:y", 0.0, 0.10)
	if spear and spear.visible:
		var sptw = create_tween()
		sptw.tween_property(spear, "rotation", -1.57, 0.10)
		sptw.tween_property(spear, "rotation", 1.57, 0.06)
		sptw.tween_property(spear, "rotation", 0.0, 0.14)
	# Flash nâu vàng rực rỡ kéo dài
	if player_sprite:
		var ftw = create_tween()
		ftw.tween_property(player_sprite, "modulate", Color(2.5, 1.8, 0.4, 1.0), 0.08)
		ftw.tween_property(player_sprite, "modulate", Color(1.6, 1.2, 0.3, 1.0), 0.10)
		ftw.tween_property(player_sprite, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.12)


# ========================================================================= #
#   MAGE: 6 ANIMATION BODY RIÊNG BIỆT (3 ELEMENT x GROUND/AIR)             #
# ========================================================================= #

func _anim_mage_cast_ground() -> void:
	if not player_sprite: return
	var base_y: float = -56.0
	match current_element:
		0: # 🌌 Tinh Vân: Xoáy tím vũ trụ - xoay nhẹ + float lên hút xuống
			var tw = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			tw.tween_property(player_sprite, "position:y", base_y - 10.0, 0.08)
			tw.parallel().tween_property(player_sprite, "rotation", 0.15, 0.08)
			tw.parallel().tween_property(self, "scale", Vector2(1.08, 1.12), 0.08)
			tw.tween_property(player_sprite, "position:y", base_y + 3.0, 0.06)
			tw.parallel().tween_property(player_sprite, "rotation", -0.05, 0.06)
			tw.parallel().tween_property(self, "scale", Vector2(0.95, 1.05), 0.06)
			tw.tween_property(player_sprite, "position:y", base_y, 0.08)
			tw.parallel().tween_property(player_sprite, "rotation", 0.0, 0.08)
			tw.parallel().tween_property(self, "scale", Vector2(1.0, 1.0), 0.08)
			# Flash tím vũ trụ
			var ftw = create_tween()
			ftw.tween_property(player_sprite, "modulate", Color(2.4, 0.7, 3.4, 1.0), 0.05)
			ftw.tween_property(player_sprite, "modulate", Color(1.2, 0.8, 1.8, 1.0), 0.10)
		1: # ⚡ Lôi Vân: Giật điện cực nhanh - rung lắc chớp nhoáng
			var tw = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			for i in range(4):
				var rx = randf_range(-5, 5)
				tw.tween_property(player_sprite, "position:x", rx, 0.02)
				tw.parallel().tween_property(self, "scale", Vector2(1.06, 0.96), 0.02)
				tw.tween_property(player_sprite, "position:x", 0.0, 0.02)
				tw.parallel().tween_property(self, "scale", Vector2(1.0, 1.0), 0.02)
			# Flash xanh ngọc điện quang nhấp nháy
			var ftw = create_tween()
			for j in range(3):
				ftw.tween_property(player_sprite, "modulate", Color(0.6, 2.8, 1.6, 1.0), 0.02)
				ftw.tween_property(player_sprite, "modulate", Color(1.2, 0.8, 1.8, 1.0), 0.03)
		2: # 🌑 Hư Không: Chìm xuống hắc ám - co lại rồi bung tím đen
			var tw = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(self, "scale", Vector2(0.85, 0.85), 0.06)
			tw.parallel().tween_property(player_sprite, "position:y", base_y + 5.0, 0.06)
			# Bung mở hắc ám
			tw.tween_property(self, "scale", Vector2(1.18, 1.18), 0.06)
			tw.parallel().tween_property(player_sprite, "position:y", base_y - 6.0, 0.06)
			# Thu lại
			tw.tween_property(self, "scale", Vector2(1.0, 1.0), 0.08)
			tw.parallel().tween_property(player_sprite, "position:y", base_y, 0.08)
			# Flash tím đen rùng rợn
			var ftw = create_tween()
			ftw.tween_property(player_sprite, "modulate", Color(1.3, 0.3, 2.2, 1.0), 0.05)
			ftw.tween_property(player_sprite, "modulate", Color(0.6, 0.2, 1.2, 1.0), 0.08)
			ftw.tween_property(player_sprite, "modulate", Color(1.2, 0.8, 1.8, 1.0), 0.10)

func _anim_mage_cast_air() -> void:
	if not player_sprite: return
	var base_y: float = -56.0
	match current_element:
		0: # 🌌 Tinh Vân trên không: Lơ lửng xoay tròn chậm, co giãn nhịp nhàng
			var tw = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			tw.tween_property(player_sprite, "rotation", 0.25, 0.12)
			tw.parallel().tween_property(self, "scale", Vector2(1.15, 0.9), 0.12)
			tw.parallel().tween_property(player_sprite, "position:y", base_y - 12.0, 0.12)
			tw.tween_property(player_sprite, "rotation", -0.08, 0.10)
			tw.parallel().tween_property(self, "scale", Vector2(0.92, 1.12), 0.10)
			tw.tween_property(player_sprite, "rotation", 0.0, 0.10)
			tw.parallel().tween_property(self, "scale", Vector2(1.0, 1.0), 0.10)
			tw.parallel().tween_property(player_sprite, "position:y", base_y, 0.10)
			var ftw = create_tween()
			ftw.tween_property(player_sprite, "modulate", Color(2.8, 0.8, 3.8, 1.0), 0.08)
			ftw.tween_property(player_sprite, "modulate", Color(1.2, 0.8, 1.8, 1.0), 0.14)
		1: # ⚡ Lôi Vân trên không: Giật mạnh + sáng chói cực quang
			var tw = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(self, "scale", Vector2(0.8, 1.25), 0.05)
			tw.parallel().tween_property(player_sprite, "position:y", base_y - 8.0, 0.05)
			tw.tween_property(self, "scale", Vector2(1.2, 0.82), 0.05)
			tw.parallel().tween_property(player_sprite, "position:y", base_y + 4.0, 0.05)
			tw.tween_property(self, "scale", Vector2(1.0, 1.0), 0.08)
			tw.parallel().tween_property(player_sprite, "position:y", base_y, 0.08)
			# Flash xanh sáng chói liên tục
			var ftw = create_tween()
			ftw.tween_property(player_sprite, "modulate", Color(0.5, 3.2, 2.0, 1.0), 0.04)
			ftw.tween_property(player_sprite, "modulate", Color(0.8, 2.0, 1.2, 1.0), 0.06)
			ftw.tween_property(player_sprite, "modulate", Color(1.2, 0.8, 1.8, 1.0), 0.10)
		2: # 🌑 Hư Không trên không: Tan biến trong bóng tối rồi hiện lại
			var tw = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			tw.tween_property(player_sprite, "modulate:a", 0.3, 0.08)
			tw.parallel().tween_property(self, "scale", Vector2(1.2, 0.8), 0.08)
			tw.parallel().tween_property(player_sprite, "rotation", 0.2, 0.08)
			tw.tween_property(player_sprite, "modulate:a", 1.0, 0.10)
			tw.parallel().tween_property(self, "scale", Vector2(0.9, 1.12), 0.10)
			tw.parallel().tween_property(player_sprite, "rotation", -0.08, 0.10)
			tw.tween_property(self, "scale", Vector2(1.0, 1.0), 0.08)
			tw.parallel().tween_property(player_sprite, "rotation", 0.0, 0.08)
			var ftw = create_tween()
			ftw.tween_property(player_sprite, "modulate", Color(1.6, 0.4, 2.8, 1.0), 0.06)
			ftw.tween_property(player_sprite, "modulate", Color(1.2, 0.8, 1.8, 1.0), 0.12)


# ========================================================================= #
#   ARCHER: 3 ANIMATION BODY RIÊNG BIỆT (3 ELEMENT SHOOTING STANCE)        #
# ========================================================================= #

func _anim_archer_draw_element() -> void:
	# Được gọi trong animate_ranger_draw_and_shoot trước khi bắn
	if not player_sprite: return
	var base_position := Vector2(0.0, -42.0)
	var base_scale := Vector2(0.12, 0.12)
	var pull_dir: float = -float(facing_direction)
	
	match current_element:
		0: # 🍃 Phong Linh: Kéo cung siêu tốc - body nghiêng theo hướng gió, tốc xạ nhanh
			# Nghiêng người theo gió
			var tw = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.tween_property(player_sprite, "rotation", 0.08 * pull_dir, 0.04)
			tw.parallel().tween_property(self, "scale", Vector2(1.1, 0.92), 0.04)
			tw.tween_property(player_sprite, "rotation", -0.04 * pull_dir, 0.03)
			tw.parallel().tween_property(self, "scale", Vector2(0.95, 1.06), 0.03)
			tw.tween_property(player_sprite, "rotation", 0.0, 0.04)
			tw.parallel().tween_property(self, "scale", Vector2(1.0, 1.0), 0.04)
			# Flash xanh ngọc lục gió
			var ftw = create_tween()
			ftw.tween_property(player_sprite, "modulate", Color(0.6, 2.6, 1.2, 1.0), 0.03)
			ftw.tween_property(player_sprite, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.06)
		1: # 💥 Pháo Kích: Giật lùi mạnh - body rung nổ, recoil cực mạnh
			var tw = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			# Nén trước
			tw.tween_property(self, "scale", Vector2(0.88, 1.15), 0.05)
			tw.parallel().tween_property(player_sprite, "position", base_position + Vector2(6.0 * pull_dir, -3.0), 0.05)
			# Giật bung
			tw.tween_property(self, "scale", Vector2(1.22, 0.82), 0.05)
			tw.parallel().tween_property(player_sprite, "position", base_position + Vector2(12.0 * float(facing_direction), -5.0), 0.05)
			# Rung recoil
			for i in range(3):
				tw.tween_property(player_sprite, "position:x", base_position.x + randf_range(-3, 3), 0.02)
			# Hồi phục
			tw.tween_property(self, "scale", Vector2(1.0, 1.0), 0.06)
			tw.parallel().tween_property(player_sprite, "position", base_position, 0.06)
			# Flash đỏ cam nổ
			var ftw = create_tween()
			ftw.tween_property(player_sprite, "modulate", Color(3.6, 0.8, 0.15, 1.0), 0.04)
			ftw.tween_property(player_sprite, "modulate", Color(2.0, 1.2, 0.3, 1.0), 0.05)
			ftw.tween_property(player_sprite, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.06)
		2: # 🌿 Độc Xà: Kéo chậm uốn lượn - body nhún sóng sin như rắn
			var tw = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			# Uốn lượn 3 nhịp nhẹ
			tw.tween_property(player_sprite, "position:y", base_position.y - 4.0, 0.06)
			tw.parallel().tween_property(player_sprite, "rotation", 0.06, 0.06)
			tw.parallel().tween_property(self, "scale", Vector2(1.04, 0.97), 0.06)
			tw.tween_property(player_sprite, "position:y", base_position.y + 3.0, 0.06)
			tw.parallel().tween_property(player_sprite, "rotation", -0.06, 0.06)
			tw.parallel().tween_property(self, "scale", Vector2(0.97, 1.04), 0.06)
			tw.tween_property(player_sprite, "position:y", base_position.y, 0.05)
			tw.parallel().tween_property(player_sprite, "rotation", 0.0, 0.05)
			tw.parallel().tween_property(self, "scale", Vector2(1.0, 1.0), 0.05)
			# Flash xanh lục bảo độc
			var ftw = create_tween()
			ftw.tween_property(player_sprite, "modulate", Color(0.3, 2.8, 0.6, 1.0), 0.04)
			ftw.tween_property(player_sprite, "modulate", Color(0.5, 1.8, 0.8, 1.0), 0.06)
			ftw.tween_property(player_sprite, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.06)


# --------- AIR PLUNGE ATTACK (KHÔNG KÍCH BỔ THƯƠNG) ---------- #

func start_air_plunge():
	is_plunging = true
	is_attacking = true
	attack_cooldown_timer = 0.5
	velocity.x = 0.0
	velocity.y = -80.0
	
	if swing_sfx:
		swing_sfx.pitch_scale = 0.8
		swing_sfx.play()
		
	var spear = get_node_or_null("student/WeaponSpear")
	if spear and spear.visible:
		var tw = create_tween()
		tw.tween_property(spear, "rotation", 1.5708, 0.1)

func process_plunge(delta: float):
	velocity.x = move_toward(velocity.x, 0, 400.0 * delta)
	velocity.y = 750.0
	
	if is_on_floor():
		execute_plunge_impact()
		return
	move_and_slide()

func execute_plunge_impact():
	is_plunging = false
	velocity = Vector2.ZERO
	
	if hit_sfx:
		hit_sfx.pitch_scale = 0.75
		hit_sfx.play()
	play_sfx("explosion_sfx")
	
	shake_camera(9.0, 0.3)
	play_hit_spark(global_position + Vector2(0, -10))
	
	var plunge_dmg = 55.0
	var targets: Array = get_tree().get_nodes_in_group("Enemy") if is_inside_tree() and get_tree() else []
	for enemy in targets:
		if is_instance_valid(enemy) and enemy is Node2D:
			var dist = global_position.distance_to(enemy.global_position)
			if dist <= 140.0:
				var kdir = (enemy.global_position - global_position).normalized()
				if kdir.length() == 0: kdir = Vector2.UP
				apply_hit_to_enemy_advanced(enemy, kdir, plunge_dmg, 2)
				
	var spear = get_node_or_null("student/WeaponSpear")
	if spear and spear.visible:
		var tw = create_tween()
		tw.tween_property(spear, "rotation", 0.0, 0.15)
		
	hit_stop(0.05)
	if is_inside_tree() and get_tree():
		await get_tree().create_timer(0.18).timeout
	is_attacking = false


# --------- MELEE HIT DETECTION & DAMAGE ---------- #

func check_melee_hits_advanced(face_dir: float, base_damage: float, step: int):
	if not melee_area or not melee_area.monitoring:
		return
	var kdir = Vector2(face_dir, -0.3).normalized()
	if step == 1:
		kdir = Vector2(face_dir * 0.6, -0.8).normalized()
	elif step == 2:
		kdir = Vector2(face_dir * 0.9, -0.2).normalized()
		
	var bodies = melee_area.get_overlapping_bodies()
	for body in bodies:
		if body != self and (body.is_in_group("Enemy") or body is Enemy):
			apply_hit_to_enemy_advanced(body, kdir, base_damage, step)
			
	var areas = melee_area.get_overlapping_areas()
	for area in areas:
		var parent = area.get_parent()
		if parent and (parent.is_in_group("Enemy") or parent is Enemy):
			apply_hit_to_enemy_advanced(parent, kdir, base_damage, step)

func _on_melee_body_entered(body: Node2D) -> void:
	if is_slash_active and body != self and (body.is_in_group("Enemy") or body is Enemy):
		var kdir = Vector2(float(facing_direction), -0.4).normalized()
		apply_hit_to_enemy_advanced(body, kdir, 40.0, combo_step)

func _on_melee_area_entered(area: Area2D) -> void:
	if is_slash_active:
		var parent = area.get_parent()
		if parent and (parent.is_in_group("Enemy") or parent is Enemy):
			var kdir = Vector2(float(facing_direction), -0.4).normalized()
			apply_hit_to_enemy_advanced(parent, kdir, 40.0, combo_step)

func apply_hit_to_enemy_advanced(enemy_node: Node2D, knockback_dir: Vector2, base_damage: float, step: int):
	var final_damage = base_damage
	if current_element == 0:
		final_damage *= 1.25
	elif current_element == 1:
		final_damage *= 1.10
		
	if enemy_node.has_method("apply_element_effect"):
		enemy_node.apply_element_effect(current_element)
		
	if enemy_node.has_method("take_damage"):
		enemy_node.take_damage(final_damage, knockback_dir)
	elif enemy_node.has_method("take_hit"):
		enemy_node.take_hit(knockback_dir)
	elif enemy_node.has_method("death_tween"):
		enemy_node.death_tween()
		
	if hit_sfx:
		hit_sfx.pitch_scale = randf_range(0.95, 1.15) if step != 2 else 0.8
		hit_sfx.play()


# ============================================================ #
#      PERSISTENT ELEMENTAL AURA & ELEMENT SWITCH (3 NHÂN VẬT) #
# ============================================================ #

func setup_persistent_element_aura() -> void:
	if aura_particles != null: return
	aura_particles = CPUParticles2D.new()
	aura_particles.name = "PersistentAura"
	aura_particles.position = Vector2(0, -22.0)
	aura_particles.amount = 26
	aura_particles.lifetime = 0.42
	aura_particles.local_coords = false
	aura_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	aura_particles.emission_rect_extents = Vector2(16.0, 24.0)
	add_child(aura_particles)
	update_persistent_element_aura()

func update_persistent_element_aura() -> void:
	if not aura_particles: return
	
	var gm = get_node_or_null("/root/GameManager") if is_inside_tree() else null
	var cid: String = gm.selected_character_id if gm and "selected_character_id" in gm else "knight"
	var spear = get_node_or_null("student/WeaponSpear")
	
	match cid:
		"knight":
			match current_element:
				0: # ⚔️ Long Đột: Hào quang ánh kim rồng vàng
					aura_particles.color = Color(2.6, 2.0, 0.4, 0.85)
					aura_particles.gravity = Vector2(0, -35.0)
					aura_particles.initial_velocity_min = 20.0
					aura_particles.initial_velocity_max = 50.0
					aura_particles.scale_amount_min = 2.0
					aura_particles.scale_amount_max = 4.2
					if spear: spear.modulate = Color(2.6, 2.0, 0.5, 1.0)
				1: # 🔥 Bạo Viêm: Ngọn lửa đỏ rực bốc cháy dữ dội
					aura_particles.color = Color(3.8, 0.85, 0.15, 0.95)
					aura_particles.gravity = Vector2(0, -90.0)
					aura_particles.initial_velocity_min = 35.0
					aura_particles.initial_velocity_max = 80.0
					aura_particles.scale_amount_min = 3.0
					aura_particles.scale_amount_max = 6.0
					if spear: spear.modulate = Color(3.6, 0.8, 0.2, 1.0)
				2: # 🛡️ Trấn Thiên: Bụi đất đá kim cang nâu vàng hộ thể
					aura_particles.color = Color(1.8, 1.4, 0.3, 0.85)
					aura_particles.gravity = Vector2(0, -10.0)
					aura_particles.initial_velocity_min = 10.0
					aura_particles.initial_velocity_max = 30.0
					aura_particles.scale_amount_min = 2.5
					aura_particles.scale_amount_max = 5.0
					if spear: spear.modulate = Color(1.8, 1.4, 0.3, 1.0)
		"mage":
			match current_element:
				0: # 🌌 Tinh Vân: Hạt tinh tú tím vũ trụ
					aura_particles.color = Color(2.4, 0.7, 3.4, 0.85)
					aura_particles.gravity = Vector2(0, -20.0)
					aura_particles.initial_velocity_min = 15.0
					aura_particles.initial_velocity_max = 40.0
					aura_particles.scale_amount_min = 2.0
					aura_particles.scale_amount_max = 4.5
				1: # ⚡ Lôi Vân: Tia chớp ngọc bích cực quang
					aura_particles.color = Color(0.6, 2.8, 1.6, 0.9)
					aura_particles.gravity = Vector2.ZERO
					aura_particles.initial_velocity_min = 30.0
					aura_particles.initial_velocity_max = 70.0
					aura_particles.scale_amount_min = 2.5
					aura_particles.scale_amount_max = 5.0
				2: # 🌑 Hư Không: Khói hắc ám tím đen lượn lờ
					aura_particles.color = Color(1.3, 0.3, 2.2, 0.85)
					aura_particles.gravity = Vector2(0, -45.0)
					aura_particles.initial_velocity_min = 10.0
					aura_particles.initial_velocity_max = 35.0
					aura_particles.scale_amount_min = 3.0
					aura_particles.scale_amount_max = 6.0
		"archer":
			match current_element:
				0: # 🍃 Phong Linh: Luồng lốc gió xoáy xanh ngọc lục
					aura_particles.color = Color(0.6, 2.6, 1.2, 0.85)
					aura_particles.gravity = Vector2(0, -15.0)
					aura_particles.initial_velocity_min = 25.0
					aura_particles.initial_velocity_max = 60.0
					aura_particles.scale_amount_min = 2.0
					aura_particles.scale_amount_max = 4.5
				1: # 💥 Pháo Kích: Tàn lửa đỏ cam chớp nổ
					aura_particles.color = Color(3.6, 0.8, 0.15, 0.9)
					aura_particles.gravity = Vector2(0, -70.0)
					aura_particles.initial_velocity_min = 30.0
					aura_particles.initial_velocity_max = 75.0
					aura_particles.scale_amount_min = 2.5
					aura_particles.scale_amount_max = 5.5
				2: # 🌿 Độc Xà: Phấn hoa độc và dây leo xanh lục bảo
					aura_particles.color = Color(0.3, 2.8, 0.6, 0.85)
					aura_particles.gravity = Vector2(0, -10.0)
					aura_particles.initial_velocity_min = 10.0
					aura_particles.initial_velocity_max = 30.0
					aura_particles.scale_amount_min = 2.5
					aura_particles.scale_amount_max = 5.0

func spawn_element_switch_vfx() -> void:
	if not is_inside_tree() or not get_parent(): return
	
	var gm = get_node_or_null("/root/GameManager") if is_inside_tree() else null
	var cid: String = gm.selected_character_id if gm and "selected_character_id" in gm else "knight"
	
	var col: Color = Color.WHITE
	var banner_text: String = ""
	var banner_col: Color = Color.WHITE
	var switch_pitch: float = 1.0
	
	match cid:
		"knight":
			match current_element:
				0:
					col = Color(2.8, 2.2, 0.4, 1.0)
					banner_text = "⚔️ LONG ĐỘT THƯƠNG"
					banner_col = Color(1.0, 0.88, 0.2, 1.0)
					switch_pitch = 1.35
				1:
					col = Color(3.8, 0.85, 0.15, 1.0)
					banner_text = "🔥 BẠO VIÊM THƯƠNG"
					banner_col = Color(1.0, 0.45, 0.1, 1.0)
					switch_pitch = 0.90
				2:
					col = Color(1.8, 1.4, 0.3, 1.0)
					banner_text = "🛡️ TRẤN THIÊN THƯƠNG"
					banner_col = Color(0.9, 0.75, 0.35, 1.0)
					switch_pitch = 0.75
		"mage":
			match current_element:
				0:
					col = Color(2.4, 0.7, 3.4, 1.0)
					banner_text = "🌌 TINH VÂN MA PHÁO"
					banner_col = Color(0.9, 0.65, 1.0, 1.0)
					switch_pitch = 1.40
				1:
					col = Color(0.6, 2.8, 1.6, 1.0)
					banner_text = "⚡ LÔI VÂN CỰC QUANG"
					banner_col = Color(0.4, 1.0, 0.7, 1.0)
					switch_pitch = 1.60
				2:
					col = Color(1.3, 0.3, 2.2, 1.0)
					banner_text = "🌑 HƯ KHÔNG HẮC MA"
					banner_col = Color(0.7, 0.4, 0.9, 1.0)
					switch_pitch = 0.80
		"archer":
			match current_element:
				0:
					col = Color(0.6, 2.6, 1.2, 1.0)
					banner_text = "🍃 PHONG LINH TIỄN"
					banner_col = Color(0.6, 1.0, 0.7, 1.0)
					switch_pitch = 1.55
				1:
					col = Color(3.6, 0.8, 0.15, 1.0)
					banner_text = "💥 PHÁO KÍCH TIỄN"
					banner_col = Color(1.0, 0.5, 0.15, 1.0)
					switch_pitch = 0.85
				2:
					col = Color(0.3, 2.8, 0.6, 1.0)
					banner_text = "🌿 ĐỘC XÀ TRÓI CHÂN"
					banner_col = Color(0.4, 1.0, 0.5, 1.0)
					switch_pitch = 1.20
			
	if swing_sfx:
		swing_sfx.pitch_scale = switch_pitch
		swing_sfx.play()
		
	# CỘT NĂNG LƯỢNG GIÁNG XUỐNG
	var pillar := Sprite2D.new()
	pillar.texture = load("res://Assets/Spritesheet/laser_bullet.png")
	pillar.global_position = global_position + Vector2(0, -130.0)
	pillar.modulate = col
	pillar.scale = Vector2(0.35, 2.2)
	pillar.rotation = PI / 2.0
	get_parent().add_child(pillar)
	
	var ptw = pillar.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	ptw.parallel().tween_property(pillar, "scale", Vector2(0.85, 2.6), 0.15)
	ptw.tween_property(pillar, "modulate:a", 0.0, 0.20)
	ptw.tween_callback(pillar.queue_free)
	
	spawn_class_shockwave(global_position + Vector2(0, -5.0), col, 120.0)
	
	var p := CPUParticles2D.new()
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = 32
	p.lifetime = 0.38
	p.spread = 180.0
	p.gravity = Vector2(0, -40.0)
	p.initial_velocity_min = 90.0
	p.initial_velocity_max = 190.0
	p.scale_amount_min = 3.0
	p.scale_amount_max = 6.5
	p.color = col
	p.global_position = global_position + Vector2(0, -35.0)
	get_parent().add_child(p)
	p.emitting = true
	get_tree().create_timer(0.48).timeout.connect(p.queue_free)
	
	_spawn_floating_element_banner(banner_text, banner_col)
	shake_camera(3.5, 0.12)

func _spawn_floating_element_banner(text: String, text_color: Color) -> void:
	if not is_inside_tree() or not get_parent(): return
	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_color_override("font_color", text_color)
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	lbl.add_theme_constant_override("shadow_offset_x", 2)
	lbl.add_theme_constant_override("shadow_offset_y", 2)
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.custom_minimum_size = Vector2(220.0, 24.0)
	lbl.pivot_offset = Vector2(110.0, 12.0)
	lbl.global_position = global_position + Vector2(-110.0, -85.0)
	get_parent().add_child(lbl)
	
	var pos_tw = lbl.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pos_tw.tween_property(lbl, "position:y", lbl.position.y - 30.0, 0.65)
	
	var s_tw = lbl.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	s_tw.tween_property(lbl, "scale", Vector2(1.25, 1.25), 0.15)
	s_tw.tween_property(lbl, "scale", Vector2(1.0, 1.0), 0.35)
	s_tw.tween_property(lbl, "modulate:a", 0.0, 0.20)
	s_tw.tween_callback(lbl.queue_free)

func damage_targets_in_radius_at(origin: Vector2, radius: float, damage: float, knockback_direction: Vector2 = Vector2.ZERO, apply_element: bool = true) -> void:
	if not is_inside_tree() or not get_tree():
		return
	var targets: Array = []
	targets.append_array(get_tree().get_nodes_in_group("Enemy"))
	targets.append_array(get_tree().get_nodes_in_group("Boss"))
	for target in targets:
		if not is_instance_valid(target) or not (target is Node2D):
			continue
		var offset: Vector2 = (target as Node2D).global_position - origin
		if offset.length() > radius:
			continue
		var direction: Vector2 = knockback_direction if knockback_direction.length() > 0.0 else offset.normalized()
		if direction.length() == 0.0:
			direction = Vector2.RIGHT
		if apply_element and target.has_method("apply_element_effect"):
			target.apply_element_effect(current_element)
		if target.has_method("take_damage"):
			target.take_damage(damage, direction)
		elif target.has_method("take_hit"):
			target.take_hit(direction)
		play_hit_spark(target.global_position)


# --------- ESSENTIAL ENGINE & CAMERA HELPERS ---------- #

func hit_stop(duration: float = 0.04):
	Engine.time_scale = 0.05
	if is_inside_tree() and get_tree():
		await get_tree().create_timer(duration * 0.05).timeout
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
	else:
		var gm = get_node_or_null("/root/GameManager")
		if gm and gm.has_method("shake_camera"):
			gm.shake_camera(strength, duration)

func apply_shake(intensity: float = 8.0, duration: float = 0.2) -> void:
	shake(intensity, duration)

func shake_camera(strength: float = 4.0, duration: float = 0.15) -> void:
	shake(strength, duration)

func _on_animation_finished() -> void:
	if not player_sprite: return
	if (player_sprite.animation == "Attack" or player_sprite.animation == "CastGround" or player_sprite.animation == "CastAir" or player_sprite.animation == "DrawBow") and not is_special_casting:
		is_attacking = false
