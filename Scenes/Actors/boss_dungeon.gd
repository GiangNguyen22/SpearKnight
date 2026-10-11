class_name BossDungeon
extends CharacterBody2D

signal hp_changed(current_hp: float, max_hp: float)
signal boss_defeated

enum BossPhase { PHASE_1, PHASE_2, PHASE_3 }

@export_category("Boss Properties")
@export var max_hp: float = 500.0
@export var hp: float = 500.0
@export var speed: float = 80.0
@export var bullet_scene: PackedScene
@export var minion_scene: PackedScene

var current_phase: BossPhase = BossPhase.PHASE_1
var alive: bool = true
var direction: int = -1
var attack_timer: float = 0.0
var summon_timer: float = 0.0
var charge_timer: float = 0.0
var is_charging: bool = false

@onready var sprite: Node2D = $Sprite if has_node("Sprite") else null
@onready var wall_ray: RayCast2D = $Sprite/Ray/wallRay if has_node("Sprite/Ray/wallRay") else null
@onready var floor_ray: RayCast2D = $Sprite/Ray/floorRay if has_node("Sprite/Ray/floorRay") else null
@onready var death_particles: CPUParticles2D = $DeathParticles if has_node("DeathParticles") else null
@onready var death_sfx: AudioStreamPlayer = $DeathSfx if has_node("DeathSfx") else null

func _ready() -> void:
	hp = max_hp
	if bullet_scene == null:
		bullet_scene = load("res://Scenes/Prefabs/bullet.tscn")
	if minion_scene == null:
		minion_scene = load("res://Scenes/Actors/monster_mushroom.tscn")
	
	if has_node("HitArea"):
		$HitArea.area_entered.connect(_on_hit_area_area_entered)
		$HitArea.body_entered.connect(_on_hit_area_body_entered)
	
	emit_signal_hp()

func emit_signal_hp():
	hp_changed.emit(hp, max_hp)

func _physics_process(delta: float) -> void:
	if not is_on_floor() or not alive:
		velocity += get_gravity() * delta

	if not alive:
		velocity.x = move_toward(velocity.x, 0, 300.0 * delta)
		move_and_slide()
		return

	update_phase()
	process_phase_behavior(delta)
	
	if direction < 0 and sprite: sprite.scale.x = 1
	elif direction > 0 and sprite: sprite.scale.x = -1
	
	move_and_slide()

# --------- PHASE STATE MACHINE ---------- #

func update_phase() -> void:
	var hp_percent = hp / max_hp
	if hp_percent > 0.6:
		if current_phase != BossPhase.PHASE_1:
			set_phase(BossPhase.PHASE_1)
	elif hp_percent > 0.3:
		if current_phase != BossPhase.PHASE_2:
			set_phase(BossPhase.PHASE_2)
	else:
		if current_phase != BossPhase.PHASE_3:
			set_phase(BossPhase.PHASE_3)

func set_phase(new_phase: BossPhase) -> void:
	current_phase = new_phase
	phase_transition_effect()

func phase_transition_effect():
	# Visual effect upon phase change
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.3, 0.7), 0.15)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.15)
	
	if sprite:
		match current_phase:
			BossPhase.PHASE_1:
				sprite.modulate = Color(1.2, 0.9, 0.9)
			BossPhase.PHASE_2:
				sprite.modulate = Color(2.0, 1.0, 0.3) # Cam lửa
			BossPhase.PHASE_3:
				sprite.modulate = Color(2.5, 0.3, 0.3) # Đỏ rực nổ hỏa

func process_phase_behavior(delta: float) -> void:
	var player = get_player_node()
	if player:
		direction = 1 if player.global_position.x > global_position.x else -1

	match current_phase:
		BossPhase.PHASE_1:
			# Patrol and shoot 3 fan-shaped bullets
			speed = 80.0
			velocity.x = speed * direction
			
			attack_timer += delta
			if attack_timer >= 2.0:
				attack_timer = 0.0
				shoot_fan_bullets()

		BossPhase.PHASE_2:
			# Move and periodically summon minions
			speed = 100.0
			velocity.x = speed * direction
			
			attack_timer += delta
			if attack_timer >= 2.5:
				attack_timer = 0.0
				shoot_fan_bullets()

			summon_timer += delta
			if summon_timer >= 4.5:
				summon_timer = 0.0
				summon_minions()

		BossPhase.PHASE_3:
			# Rage mode: High speed charge attack
			charge_timer += delta
			if is_charging:
				velocity.x = direction * 380.0
			else:
				speed = 140.0
				velocity.x = speed * direction

			if charge_timer >= 2.8:
				charge_timer = 0.0
				start_charge_attack()

func shoot_fan_bullets():
	if bullet_scene == null or not alive:
		return
	
	var player = get_player_node()
	var base_dir = Vector2(direction, 0)
	if player:
		base_dir = (player.global_position - global_position).normalized()

	var angles = [-0.26, 0.0, 0.26] # -15 deg, 0 deg, +15 deg
	for angle in angles:
		var dir = base_dir.rotated(angle)
		var bullet = bullet_scene.instantiate()
		bullet.global_position = global_position + Vector2(direction * 30, -30)
		if bullet.has_method("set_element"):
			bullet.set_element(1) # Fire element bullets for Boss
		get_parent().add_child(bullet)
		if bullet.has_method("shoot"):
			bullet.shoot(dir, 600, 2.5)

func summon_minions():
	if minion_scene == null or not alive:
		return
	
	# Ground slam visual effect
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.has_method("shake_camera"):
		gm.shake_camera(8.0, 0.25)
		
	var tween = create_tween()
	tween.tween_property(self, "position:y", position.y - 30, 0.12)
	tween.tween_property(self, "position:y", position.y, 0.12)
	
	for i in range(2):
		var minion = minion_scene.instantiate()
		var offset_x = -60.0 if i == 0 else 60.0
		minion.global_position = global_position + Vector2(offset_x, -10.0)
		get_parent().add_child(minion)

func start_charge_attack():
	is_charging = true
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.has_method("shake_camera"):
		gm.shake_camera(10.0, 0.35)
		
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color.RED, 0.1)
	tween.tween_property(self, "modulate", Color.WHITE, 0.1)
	await get_tree().create_timer(0.8).timeout
	is_charging = false

func get_player_node() -> Node2D:
	var gm = get_node_or_null("/root/GameManager")
	if gm and "player" in gm and gm.player and is_instance_valid(gm.player):
		return gm.player
	return null

# --------- DAMAGE & HIT HANDLING ---------- #

func take_damage(amount: float, knockback_dir: Vector2 = Vector2.RIGHT):
	if not alive:
		return
	hp -= amount
	if hp < 0: hp = 0
	emit_signal_hp()
	
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.has_method("shake_camera"):
		gm.shake_camera(4.5, 0.12)
	
	# Hit flash
	if sprite:
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color.WHITE * 2.0, 0.06)
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)
		
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

func die(knockback_dir: Vector2):
	alive = false
	collision_layer = 0
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.has_method("add_score"):
		gm.add_score(50)
	
	# Task 4.1: Epic Boss Defeat Juice - Strong Shake + Cinematic Slow-Mo
	if gm and gm.has_method("shake_camera"):
		gm.shake_camera(20.0, 0.8)
	
	# Slow motion impact in unscaled real time (0.5s)
	Engine.time_scale = 0.2
	await get_tree().create_timer(0.5, true, false, true).timeout
	var tw_time = create_tween().set_trans(Tween.TRANS_SINE)
	tw_time.tween_property(Engine, "time_scale", 1.0, 0.2)
	
	if death_particles:
		death_particles.emitting = true
	if death_sfx:
		death_sfx.play()
		
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.5, 1.5), 0.2)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.5)
	
	boss_defeated.emit()
	await get_tree().create_timer(0.6).timeout
	queue_free()
