class_name RockProjectile
extends Area2D

@export var damage: float = 18.0
@export var fall_gravity: float = 480.0

var velocity: Vector2 = Vector2.ZERO
var lifetime: float = 3.5
var is_shattered: bool = false

@onready var sprite: Sprite2D = $Sprite2D if has_node("Sprite2D") else null
@onready var trail: CPUParticles2D = $Trail if has_node("Trail") else null

func _ready() -> void:
	collision_layer = 16 # Enemy Projectile / Trap layer
	collision_mask = 3   # Layer 1 = World/Ground, Layer 2 = Player
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	
	if trail:
		trail.emitting = true

func launch(start_pos: Vector2, target_pos: Vector2) -> void:
	global_position = start_pos
	var dx = target_pos.x - start_pos.x
	var dy = target_pos.y - start_pos.y
	var dir_x = 1.0 if dx >= 0 else -1.0
	
	# Tính toán quỹ đạo parabol vòng cung tự nhiên
	var dist_x = abs(dx)
	var h_speed = clampf(dist_x * 1.35 + 140.0, 200.0, 460.0)
	var v_speed = -230.0 if dy <= 20.0 else -160.0
	velocity = Vector2(dir_x * h_speed, v_speed)

func _physics_process(delta: float) -> void:
	if is_shattered: return
	velocity.y += fall_gravity * delta
	global_position += velocity * delta
	
	if sprite:
		sprite.rotation += velocity.x * 0.025 * delta
		
	lifetime -= delta
	if lifetime <= 0:
		shatter_debris()

func _on_body_entered(body: Node) -> void:
	if is_shattered: return
	if body.is_in_group("Enemy") or body.is_in_group("Boss") or body.is_in_group("Bullet"):
		return
		
	if body.is_in_group("Player") or body is Player:
		var gm = get_node_or_null("/root/GameManager")
		if gm and gm.has_method("damage"):
			gm.damage(int(damage))
		if body.has_method("damage_tween"):
			body.damage_tween()
		if "velocity" in body:
			var kdir = Vector2(signf(velocity.x), -0.4).normalized()
			body.velocity = kdir * 280.0
		shatter_debris()
		return
		
	# Va chạm mặt đất, tường, bẫy -> vỡ vụn
	shatter_debris()

func _on_area_entered(area: Area2D) -> void:
	if is_shattered: return
	if area.is_in_group("MeleeAttack"):
		# Người chơi vung vũ khí chém vỡ hòn đá giữa không trung (Cơ chế parry / deflect cực đã!)
		shatter_debris(true)

func shatter_debris(deflected: bool = false) -> void:
	if is_shattered: return
	is_shattered = true
	
	if is_inside_tree() and get_parent():
		var debris := CPUParticles2D.new()
		debris.emitting = false
		debris.one_shot = true
		debris.explosiveness = 0.95
		debris.amount = 14
		debris.lifetime = 0.35
		debris.spread = 180.0
		debris.gravity = Vector2(0, 360.0)
		debris.initial_velocity_min = 60.0
		debris.initial_velocity_max = 160.0
		debris.scale_amount_min = 2.0
		debris.scale_amount_max = 4.5
		debris.color = Color(0.75, 0.6, 0.45, 1.0) if not deflected else Color(2.5, 2.0, 0.5, 1.0)
		debris.global_position = global_position
		get_parent().add_child(debris)
		debris.emitting = true
		get_tree().create_timer(0.4).timeout.connect(debris.queue_free)
		
	queue_free()
