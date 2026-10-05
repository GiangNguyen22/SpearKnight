class_name BulletArcher
extends RigidBody2D

@export var damage: int = 18
@export var pierce_count: int = 2

@onready var sprite: Sprite2D = $Sprite2D if has_node("Sprite2D") else null

func _ready() -> void:
	if sprite:
		sprite.modulate = Color(0.4, 2.0, 0.8, 1.0) # Forest Swift Green

func shoot(direction: Vector2, speed: float, lifetime: float) -> void:
	rotation = direction.angle()
	apply_impulse(direction * speed * 1.3)
	get_tree().create_timer(lifetime).timeout.connect(queue_free)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("Enemy") or body.name.to_lower().contains("enemy") or body.name.to_lower().contains("boss"):
		if body.has_method("hit"):
			body.hit(damage, Vector2.ZERO)
		elif body.has_method("take_damage"):
			body.take_damage(damage)
		
		pierce_count -= 1
		if pierce_count <= 0:
			queue_free()
	else:
		queue_free()
