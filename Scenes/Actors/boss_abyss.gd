class_name BossAbyss
extends CharacterBody2D

signal hp_changed(current_hp: float, max_hp: float)
signal boss_defeated

enum BossPhase { PHASE_1, PHASE_2, PHASE_3 }

@export_category("Boss Properties")
@export var max_hp: float = 800.0
@export var hp: float = 800.0
@export var speed: float = 90.0
@export var bullet_scene: PackedScene
@export var minion_scene: PackedScene

var current_phase: BossPhase = BossPhase.PHASE_1
var alive: bool = true
var is_invincible: bool = false
var direction: int = -1

var attack_timer: float = 0.0
var teleport_timer: float = 0.0
var laser_sweep_timer: float = 0.0
var is_laser_sweeping: bool = false

var teleport_spots: Array[Vector2] = []
var active_minions: Array[Node2D] = []

@onready var sprite: Node2D = $Sprite if has_node("Sprite") else null
@onready var anim_sprite: AnimatedSprite2D = $Sprite/AnimateSprite if has_node("Sprite/AnimateSprite") else null
@onready var shield_sprite: Sprite2D = $ShieldSprite if has_node("ShieldSprite") else null
@onready var laser_area: Area2D = $LaserBeamArea if has_node("LaserBeamArea") else null
@onready var death_particles: CPUParticles2D = $DeathParticles if has_node("DeathParticles") else null
@onready var death_sfx: AudioStreamPlayer = $DeathSfx if has_node("DeathSfx") else null


func _ready() -> void:
	hp = max_hp
	if bullet_scene == null:
		bullet_scene = load("res://Scenes/Prefabs/bullet_boss_abyss.tscn")
	if minion_scene == null:
		minion_scene = load("res://Scenes/Actors/monster_mushroom.tscn")
	if teleport_spots.is_empty():
		teleport_spots = [
			Vector2(2060, 448),
			Vector2(2280, 448),
			Vector2(2480, 448)
		]
	
	if has_node("HitArea"):
		if not $HitArea.area_entered.is_connected(_on_hit_area_area_entered):
			$HitArea.area_entered.connect(_on_hit_area_area_entered)
		if not $HitArea.body_entered.is_connected(_on_hit_area_body_entered):
			$HitArea.body_entered.connect(_on_hit_area_body_entered)
	if laser_area:
		if not laser_area.body_entered.is_connected(_on_laser_area_body_entered):
			laser_area.body_entered.connect(_on_laser_area_body_entered)
		laser_area.visible = false
		if laser_area.has_node("CollisionShape2D"):
			laser_area.get_node("CollisionShape2D").disabled = true

	emit_signal_hp()


func emit_signal_hp() -> void:
	hp_changed.emit(hp, max_hp)


func set_teleport_spots(spots: Array[Vector2]) -> void:
	teleport_spots = spots


func _physics_process(delta: float) -> void:
	if not alive:
		if not is_on_floor():
			velocity += get_gravity() * delta
		velocity.x = move_toward(velocity.x, 0, 300.0 * delta)
		move_and_slide()
		return

	if not is_on_floor():
		velocity += get_gravity() * delta

	update_phase()
	process_phase_behavior(delta)
	
	if direction < 0 and sprite: sprite.scale.x = 1.0
	elif direction > 0 and sprite: sprite.scale.x = -1.0
	
	move_and_slide()


# --------- PHASE FSM LOGIC ---------- #

func update_phase() -> void:
	var hp_percent = hp / max_hp
	if hp_percent > 0.7:
		if current_phase != BossPhase.PHASE_1:
			set_phase(BossPhase.PHASE_1)
	elif hp_percent > 0.35:
		if current_phase != BossPhase.PHASE_2:
			set_phase(BossPhase.PHASE_2)
	else:
		if current_phase != BossPhase.PHASE_3:
			set_phase(BossPhase.PHASE_3)


func set_phase(new_phase: BossPhase) -> void:
	current_phase = new_phase
	phase_transition_effect()


func phase_transition_effect() -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.has_method("shake_camera"):
		gm.shake_camera(14.0, 0.35)

	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.2, 1.2), 0.15)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.15)

	match current_phase:
		BossPhase.PHASE_1:
			is_invincible = false
			if shield_sprite: shield_sprite.visible = false
			if sprite: sprite.modulate = Color(1.6, 0.4, 1.8, 1.0) # Tím hắc á m
		BossPhase.PHASE_2:
			is_invincible = true
			if shield_sprite:
				shield_sprite.visible = true
				shield_sprite.modulate = Color(0.4, 2.0, 2.5, 0.8) # Giáp vô địch
			if sprite: sprite.modulate = Color(0.8, 1.2, 2.0, 1.0)
			summon_elite_guardians()
		BossPhase.PHASE_3:
			is_invincible = false
			if shield_sprite: shield_sprite.visible = false
			if sprite: sprite.modulate = Color(3.0, 0.2, 0.2, 1.0) # Quỷ đỏ cuồng nộ


func process_phase_behavior(delta: float) -> void:
	var player = get_player_node()
	if player:
		direction = 1 if player.global_position.x > global_position.x else -1

	match current_phase:
		BossPhase.PHASE_1:
			speed = 90.0
			velocity.x = speed * direction
			
			teleport_timer += delta
			if teleport_timer >= 3.8:
				teleport_timer = 0.0
				teleport_and_spiral_nova()

		BossPhase.PHASE_2:
			speed = 110.0
			velocity.x = speed * direction
			
			_check_minions_status()
			
			attack_timer += delta
			if attack_timer >= 2.8:
				attack_timer = 0.0
				shoot_spiral_nova(6)

		BossPhase.PHASE_3:
			speed = 260.0
			velocity.x = speed * direction
			
			laser_sweep_timer += delta
			if laser_sweep_timer >= 3.5 and not is_laser_sweeping:
				laser_sweep_timer = 0.0
				start_dark_laser_sweep()


func _check_minions_status() -> void:
	if current_phase != BossPhase.PHASE_2:
		return
	
	var alive_count = 0
	for m in active_minions:
		if is_instance_valid(m) and m.is_inside_tree():
			if "alive" in m and m.alive:
				alive_count += 1
			elif m.has_method("is_alive") and m.is_alive():
				alive_count += 1
			elif not ("alive" in m):
				alive_count += 1

	if alive_count <= 0 and is_invincible:
		is_invincible = false
		if shield_sprite:
			shield_sprite.visible = false
		var gm = get_node_or_null("/root/GameManager")
		if gm and gm.has_method("alert"):
			gm.alert("✨ Giáp Boss đã bị phá hủy! Tấn công ngay! ✨")


func teleport_and_spiral_nova() -> void:
	if not alive:
		return
	
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.has_method("shake_camera"):
		gm.shake_camera(6.0, 0.2)
		
	# Teleport visual disappear
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	await tween.finished

	# Change position
	if teleport_spots.size() > 0:
		var target_spot = teleport_spots[randi() % teleport_spots.size()]
		global_position = target_spot
	else:
		var player = get_player_node()
		if player:
			global_position.x = player.global_position.x + randf_range(-250, 250)

	# Teleport reappear
	var tween_in = create_tween()
	tween_in.tween_property(self, "modulate:a", 1.0, 0.2)
	await tween_in.finished

	shoot_spiral_nova(8)


func shoot_spiral_nova(bullet_count: int = 8) -> void:
	if bullet_scene == null or not alive:
		return
	
	var step_angle = TAU / float(bullet_count)
	for i in range(bullet_count):
		var angle = i * step_angle
		var dir = Vector2(cos(angle), sin(angle))
		var bullet = bullet_scene.instantiate()
		bullet.global_position = global_position + Vector2(0, -30)
		get_parent().add_child(bullet)
		if bullet.has_method("shoot"):
			bullet.shoot(dir, 420.0, 3.5)


func summon_elite_guardians() -> void:
	if minion_scene == null or not alive:
		return
	
	active_minions.clear()
	for i in range(2):
		var minion = minion_scene.instantiate()
		var offset_x = -120.0 if i == 0 else 120.0
		minion.global_position = global_position + Vector2(offset_x, -10.0)
		if minion.has_node("AnimatedSprite2D"):
			minion.get_node("AnimatedSprite2D").modulate = Color(2.0, 0.5, 0.5, 1.0)
		get_parent().add_child(minion)
		active_minions.append(minion)


func start_dark_laser_sweep() -> void:
	if not alive:
		return
	is_laser_sweeping = true
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.has_method("shake_camera"):
		gm.shake_camera(12.0, 0.4)

	# Warning charge flash
	if sprite:
		var tw_warn = create_tween().set_loops(4)
		tw_warn.tween_property(sprite, "modulate", Color.WHITE * 3.0, 0.1)
		tw_warn.tween_property(sprite, "modulate", Color(3.0, 0.2, 0.2, 1.0), 0.1)

	await get_tree().create_timer(0.8).timeout

	# Activate Laser Beam
	if laser_area:
		laser_area.visible = true
		if laser_area.has_node("CollisionShape2D"):
			laser_area.get_node("CollisionShape2D").disabled = false
		
		# Sweep across arena floor
		var tw_laser = create_tween()
		tw_laser.tween_property(laser_area, "scale:y", 1.8, 0.2)
		tw_laser.tween_property(laser_area, "scale:y", 0.1, 1.0)
		await tw_laser.finished
		
		laser_area.visible = false
		if laser_area.has_node("CollisionShape2D"):
			laser_area.get_node("CollisionShape2D").disabled = true

	is_laser_sweeping = false


func _on_laser_area_body_entered(body: Node2D) -> void:
	if body is Player or body.is_in_group("Player"):
		if body.has_method("on_hit_by_enemy"):
			body.on_hit_by_enemy(self)
		elif body.has_method("damage_tween"):
			body.damage_tween()


func get_player_node() -> Node2D:
	var gm = get_node_or_null("/root/GameManager")
	if gm and "player" in gm and gm.player and is_instance_valid(gm.player):
		return gm.player
	return null


# --------- DAMAGE & HIT HANDLING ---------- #

func take_damage(amount: float, knockback_dir: Vector2 = Vector2.RIGHT) -> void:
	if not alive:
		return
	
	if is_invincible:
		# Shield deflection effect
		var gm = get_node_or_null("/root/GameManager")
		if gm and gm.has_method("shake_camera"):
			gm.shake_camera(3.0, 0.1)
		if shield_sprite:
			var tw_s = create_tween()
			tw_s.tween_property(shield_sprite, "modulate", Color.WHITE * 3.0, 0.08)
			tw_s.tween_property(shield_sprite, "modulate", Color(0.4, 2.0, 2.5, 0.8), 0.1)
		return

	hp -= amount
	if hp < 0: hp = 0
	emit_signal_hp()
	
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.has_method("shake_camera"):
		gm.shake_camera(6.0, 0.15)
	
	if sprite:
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color.WHITE * 2.5, 0.06)
		tween.tween_property(sprite, "modulate", Color(3.0, 0.2, 0.2, 1.0) if current_phase == BossPhase.PHASE_3 else Color.WHITE, 0.1)
		
	if hp <= 0:
		die(knockback_dir)


func _on_hit_area_body_entered(body: Node2D) -> void:
	if alive and body.is_in_group("Bullet"):
		if body.has_method("explode_aoe"):
			body.explode_aoe()
			body.queue_free()
			return
		var kdir = Vector2.RIGHT if body.position.x <= position.x else Vector2.LEFT
		take_damage(40.0, kdir)
		body.queue_free()


func _on_hit_area_area_entered(area: Area2D) -> void:
	if alive and area.is_in_group("MeleeAttack"):
		var kdir = Vector2.RIGHT if area.global_position.x <= global_position.x else Vector2.LEFT
		take_damage(50.0, kdir)


func die(knockback_dir: Vector2) -> void:
	alive = false
	collision_layer = 0
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.has_method("add_score"):
		gm.add_score(200)
	
	if gm and gm.has_method("shake_camera"):
		gm.shake_camera(25.0, 1.0)
	
	Engine.time_scale = 0.15
	await get_tree().create_timer(0.6, true, false, true).timeout
	var tw_time = create_tween().set_trans(Tween.TRANS_SINE)
	tw_time.tween_property(Engine, "time_scale", 1.0, 0.2)
	
	if death_particles:
		death_particles.emitting = true
	if death_sfx:
		death_sfx.play()
		
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.6, 1.6), 0.2)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.6)
	
	boss_defeated.emit()
	await get_tree().create_timer(0.8).timeout
	queue_free()
