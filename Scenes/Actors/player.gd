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
@export var bullet_scene : PackedScene
@export var bullet_lifetime : float = 1.5

# Mỗi class có một kỹ năng chủ động độc lập, ngoài đòn đánh thường.
var special_cooldown_timer: float = 0.0
var is_special_casting: bool = false
const KNIGHT_SPECIAL_COOLDOWN: float = 2.5
const MAGE_SPECIAL_COOLDOWN: float = 3.0
const RANGER_SPECIAL_COOLDOWN: float = 2.2

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
		var elem_names = ["Quang Ma Pháp / Arcane (+Đẩy lùi)", "Hỏa Phép / Fireball (Nổ diện rộng & Cháy)", "Băng Phép / Frost (Xuyên thấu & Làm chậm 50%)"]
		if current_element == 0:
			elem_names[0] = "Quang Ma Pháp / Arcane (+Đẩy lùi)" if (get_node_or_null("/root/GameManager") and get_node_or_null("/root/GameManager").get("selected_character_id") == "mage") else "Hoàng Kim (+25% Sát Thương)"
		var gm = get_node_or_null("/root/GameManager") if is_inside_tree() else null
		var cid: String = gm.selected_character_id if gm and "selected_character_id" in gm else "knight"
		var title = "Cường Hóa Thương: " if cid == "knight" else ("Phép Thuật: " if cid == "mage" else "Mũi Tên: ")
		var ui = get_tree().current_scene.get_node_or_null("UserInterface") if is_inside_tree() and get_tree() and get_tree().current_scene else null
		if ui and ui.has_method("alert"):
			ui.alert(title + elem_names[current_element])

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
	if velocity.y > 5000 and not is_dying and can_damage:
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
	
	# --- GIAI ĐOẠN 1: KÉO CUNG & TỤ KHÍ (DRAW & TENSION ~0.11s) ---
	# Archer ngả người lui sau, căng cơ thể theo chiều dọc
	var draw_tw := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	draw_tw.tween_property(player_sprite, "position", base_position + Vector2(10.0 * pull_dir, -4.0), 0.11)
	draw_tw.parallel().tween_property(player_sprite, "scale", Vector2(0.105, 0.138), 0.11)
	draw_tw.parallel().tween_property(player_sprite, "rotation", 0.12 * pull_dir, 0.11)
	
	# VFX ánh sáng mũi tên tụ lại trên cánh cung
	spawn_archer_draw_charge_vfx()
	
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
	charge.modulate = Color(0.6, 2.5, 1.2, 0.8) # Xanh lục phát sáng
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
	
	# Tia sáng xé gió
	var flash := Sprite2D.new()
	flash.texture = tex
	flash.global_position = shoot_pos
	flash.modulate = Color(0.5, 2.8, 1.0, 1.0) # Vệt sáng xanh ngọc phát quang
	flash.scale = Vector2(0.05, 0.05)
	flash.rotation = (Vector2(float(facing_direction), 0.0)).angle()
	get_parent().add_child(flash)
	
	# Vòng khí nén xé gió bùng ra
	var ring := Sprite2D.new()
	ring.texture = tex
	ring.global_position = shoot_pos
	ring.modulate = Color(0.4, 2.2, 0.9, 0.7)
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

# --------- KNIGHT TRUE MELEE COMBAT SYSTEM ---------- #

func start_knight_combo():
	is_attacking = true
	combo_timer = COMBO_WINDOW
	var face_dir = float(facing_direction)
	var current_step = combo_step
	
	var base_dmg: float = 35.0
	var lunge_speed: float = 120.0
	var hit_cooldown: float = 0.25
	
	match current_step:
		0: # Đòn 1: Quick Thrust (Đâm nhanh)
			base_dmg = 35.0
			lunge_speed = 180.0
			hit_cooldown = 0.24
			attack_cooldown_timer = hit_cooldown
			if swing_sfx:
				swing_sfx.pitch_scale = randf_range(1.15, 1.3)
				swing_sfx.play()
			play_thrust_vfx(face_dir)
			animate_weapon_thrust()
		1: # Đòn 2: Upward Slash (Chém hất ngược lên)
			base_dmg = 45.0
			lunge_speed = 140.0
			hit_cooldown = 0.28
			attack_cooldown_timer = hit_cooldown
			if swing_sfx:
				swing_sfx.pitch_scale = randf_range(0.95, 1.05)
				swing_sfx.play()
			play_upward_slash_vfx(face_dir)
			animate_weapon_slash()
		2: # Đòn 3: Heavy Overhead Smash (Bổ kết liễu uy lực cực mạnh)
			base_dmg = 70.0
			lunge_speed = 100.0
			hit_cooldown = 0.42
			attack_cooldown_timer = hit_cooldown
			if hit_sfx:
				hit_sfx.pitch_scale = 0.85
				hit_sfx.play()
			play_heavy_smash_vfx(face_dir)
			animate_weapon_smash()
			shake_camera(6.5, 0.2)
	
	# Nhẹ nhàng lướt tới phía trước theo hướng đánh
	if is_on_floor():
		velocity.x = face_dir * lunge_speed
		
	# Phát hoạt ảnh đánh của nhân vật
	if player_sprite and player_sprite.sprite_frames and player_sprite.sprite_frames.has_animation("Attack"):
		player_sprite.play("Attack")
		
	# Kích hoạt hitbox cận chiến
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

func play_thrust_vfx(face_dir: float):
	if not slash_vfx: return
	slash_vfx.visible = true
	slash_vfx.position = Vector2(40, -45)
	slash_vfx.rotation = 0.0
	slash_vfx.scale = Vector2(0.04, 0.04)
	apply_element_to_vfx(slash_vfx)
	
	var tween = create_tween()
	tween.parallel().tween_property(slash_vfx, "position", Vector2(90, -45), 0.14).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(slash_vfx, "scale", Vector2(0.18, 0.06), 0.14)
	tween.parallel().tween_property(slash_vfx, "modulate:a", 0.0, 0.14)
	await tween.finished
	slash_vfx.visible = false

func play_upward_slash_vfx(face_dir: float):
	if not slash_vfx: return
	slash_vfx.visible = true
	slash_vfx.position = Vector2(50, -35)
	slash_vfx.rotation = -0.7
	slash_vfx.scale = Vector2(0.04, 0.04)
	apply_element_to_vfx(slash_vfx)
	
	var tween = create_tween()
	tween.parallel().tween_property(slash_vfx, "position", Vector2(75, -55), 0.16).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(slash_vfx, "scale", Vector2(0.14, 0.14), 0.16)
	tween.parallel().tween_property(slash_vfx, "rotation", 0.2, 0.16)
	tween.parallel().tween_property(slash_vfx, "modulate:a", 0.0, 0.16)
	await tween.finished
	slash_vfx.visible = false

func play_heavy_smash_vfx(face_dir: float):
	if not slash_vfx: return
	slash_vfx.visible = true
	slash_vfx.position = Vector2(45, -65)
	slash_vfx.rotation = -1.2
	slash_vfx.scale = Vector2(0.06, 0.06)
	apply_element_to_vfx(slash_vfx)
	
	var tween = create_tween()
	tween.parallel().tween_property(slash_vfx, "position", Vector2(85, -30), 0.2).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(slash_vfx, "scale", Vector2(0.2, 0.2), 0.2)
	tween.parallel().tween_property(slash_vfx, "rotation", 0.8, 0.2)
	tween.parallel().tween_property(slash_vfx, "modulate:a", 0.0, 0.2)
	await tween.finished
	slash_vfx.visible = false

func apply_element_to_vfx(vfx_node: CanvasItem):
	if not vfx_node: return
	match current_element:
		0: vfx_node.modulate = Color(2.2, 1.8, 0.5, 1.0) # Hoàng Kim / Sáng chói
		1: vfx_node.modulate = Color(2.8, 0.5, 0.2, 1.0) # Hỏa Phép / Đỏ rực
		2: vfx_node.modulate = Color(0.4, 1.6, 2.5, 1.0) # Băng Phép / Xanh băng

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

# --------- AIR PLUNGE ATTACK (KHÔNG KÍCH BỔ THƯƠNG) ---------- #

func start_air_plunge():
	is_plunging = true
	is_attacking = true
	attack_cooldown_timer = 0.5
	velocity.x = 0.0
	velocity.y = -80.0 # Bật nhẹ lên một nhịp lấy đà
	
	if swing_sfx:
		swing_sfx.pitch_scale = 0.8
		swing_sfx.play()
		
	var spear = get_node_or_null("student/WeaponSpear")
	if spear and spear.visible:
		var tw = create_tween()
		tw.tween_property(spear, "rotation", 1.5708, 0.1) # Chĩa mũi thương thẳng xuống đất

func process_plunge(delta: float):
	velocity.x = move_toward(velocity.x, 0, 400.0 * delta)
	velocity.y = 750.0 # Lao nhanh cắm xuống đất
	
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
	
	# Sóng xung kích quét quái vật diện rộng xung quanh (AoE 140px)
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
	if not melee_area: return
	var kdir = Vector2(face_dir, -0.3).normalized()
	if step == 1: # Chém hất lên
		kdir = Vector2(face_dir * 0.6, -0.8).normalized()
	elif step == 2: # Bổ mạnh
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
	if current_element == 0: # Hoàng Kim (+25% damage)
		final_damage *= 1.25
	elif current_element == 1: # Hỏa (+10% damage)
		final_damage *= 1.10
		
	if enemy_node.has_method("take_damage"):
		enemy_node.take_damage(final_damage, knockback_dir)
	elif enemy_node.has_method("apply_element_effect"):
		enemy_node.apply_element_effect(current_element)
		if enemy_node.has_method("take_hit"):
			enemy_node.take_hit(knockback_dir)
	elif enemy_node.has_method("take_hit"):
		enemy_node.take_hit(knockback_dir)
	elif enemy_node.has_method("death_tween"):
		enemy_node.death_tween()
		
	if hit_sfx:
		hit_sfx.pitch_scale = randf_range(0.95, 1.15) if step != 2 else 0.8
		hit_sfx.play()
		
	play_hit_spark(enemy_node.global_position)
	
	var stop_time = 0.04 if step != 2 else 0.07
	hit_stop(stop_time)
	
	if step == 2:
		shake_camera(7.0, 0.2)
	else:
		shake_camera(3.5, 0.12)

func hit_stop(duration: float = 0.04):
	if is_inside_tree() and get_tree():
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
	if (player_sprite.animation == "Attack" or player_sprite.animation == "CastGround" or player_sprite.animation == "CastAir" or player_sprite.animation == "DrawBow") and not is_special_casting:
		is_attacking = false
