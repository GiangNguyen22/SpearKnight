class_name BulletMage
extends RigidBody2D

@export var damage: int = 25
@export var aoe_radius: float = 45.0

@onready var sprite: Sprite2D = $Sprite2D if has_node("Sprite2D") else null

func _ready() -> void:
	if sprite:
		sprite.modulate = Color(1.8, 0.5, 2.0, 1.0) # Violet Arcane

func shoot(direction: Vector2, speed: float, lifetime: float) -> void:
	rotation = direction.angle()
	apply_impulse(direction * speed)
	get_tree().create_timer(lifetime).timeout.connect(queue_free)

func _on_body_entered(body: Node) -> void:
	explode_aoe()
	queue_free()

func explode_aoe() -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.has_method("shake_camera"):
		gm.shake_camera(8.0, 0.2)
	
	var enemies = get_tree().get_nodes_in_group("Enemy")
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.global_position.distance_to(global_position) <= aoe_radius:
			if enemy.has_method("hit"):
				enemy.hit(damage, Vector2.ZERO)
			elif enemy.has_method("take_damage"):
				enemy.take_damage(damage)
