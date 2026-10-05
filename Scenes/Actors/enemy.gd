class_name Enemy
extends CharacterBody2D

@export var speed: float = 100.0
@export var direction: int = 1
@export var flip: bool = false
@export var hp: float = 100.0
@export var max_hp: float = 100.0

var alive: bool = true
var attack_cooldown_timer: float = 0.0

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
		$HitArea.area_entered.connect(_on_hit_area_area_entered)
		$HitArea.body_entered.connect(_on_hit_area_body_entered)

func _process(_delta: float) -> void:
	if flip:
		if has_node("Sprite"): $Sprite.scale.x = -1
	else:
		if has_node("Sprite"): $Sprite.scale.x = 1

func _physics_process(delta: float) -> void:
	if not is_on_floor() or not alive:
		velocity += get_gravity() * delta

	if attack_cooldown_timer > 0:
		attack_cooldown_timer -= delta

	if alive and is_on_floor():
		var player = get_player_node()
		var player_detected = false
		if player_ray and player_ray.is_colliding():
			var col = player_ray.get_collider()
			if col and (col.is_in_group("Player") or col is Player):
				player_detected = true
		
		# Nếu gặp bẫy phía trước khi tuần tra -> thông minh quay đầu lại, không tự sát!
		if is_trap_ahead():
			direction = -direction
		# Nếu phát hiện người chơi ở tầm mắt, tự động quay hướng về người chơi
		elif player_detected and player:
			found_player(player.global_position)
		# Nếu va tường, gặp raycast tường hoặc hết sàn -> lập tức quay đầu mượt như bản gốc
		elif is_on_wall() or (wall_ray and wall_ray.is_colliding()) or (floor_ray and !floor_ray.is_colliding()):
			direction = -direction
			
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
	# Chỉ chết vì bẫy nếu bị người chơi đánh bật lùi / bắn ngã vào bẫy
	if alive and body.is_in_group("Traps") and (not is_on_floor() or abs(velocity.x) > 120.0):
		death_tween()
	if alive and body.is_in_group("Bullet"):
		var kdir = Vector2.RIGHT
		if "linear_velocity" in body:
			kdir = Vector2.RIGHT if body.linear_velocity.x >= 0 else Vector2.LEFT
		elif "velocity" in body:
			kdir = Vector2.RIGHT if body.velocity.x >= 0 else Vector2.LEFT
		
		if "element_type" in body:
			apply_element_effect(body.element_type)
		take_hit(kdir)
		body.queue_free()

func apply_element_effect(element_val: int) -> void:
	if not alive:
		return
	hp -= 35.0
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
	if alive and area.is_in_group("MeleeAttack"):
		hp -= 40.0
		var kdir = Vector2.RIGHT if area.global_position.x <= global_position.x else Vector2.LEFT
		if hp <= 0:
			take_hit(kdir)
		else:
			velocity = kdir * 180.0 + Vector2(0, -100.0)

func take_hit(knockback_dir: Vector2 = Vector2.RIGHT) -> void:
	if not alive:
		return
	alive = false
	collision_layer = 0
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.has_method("add_score"):
		gm.add_score()
	velocity = knockback_dir * 280.0 + Vector2(0, -160.0)
	
	if has_node("Sprite"):
		var tween = create_tween()
		tween.tween_property($Sprite, "modulate", Color.RED, 0.08)
		tween.tween_property($Sprite, "modulate", Color(1, 1, 1, 0), 0.25)
	
	if has_node("DeathParticles"):
		$DeathParticles.emitting = true
	if has_node("DeathSfx"):
		$DeathSfx.play()
	await get_tree().create_timer(0.4).timeout
	queue_free()

func death_tween() -> void:
	take_hit(Vector2.UP)
