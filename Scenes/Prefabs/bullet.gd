extends RigidBody2D

enum ElementType { NORMAL, FIRE, ICE }

@export var element_type: ElementType = ElementType.NORMAL

@onready var sprite: Sprite2D = $LaserBullet if has_node("LaserBullet") else null

func _ready():
	apply_element_visuals()

func set_element(element: ElementType):
	element_type = element
	apply_element_visuals()

func apply_element_visuals():
	if not is_inside_tree():
		return
	if sprite:
		match element_type:
			ElementType.NORMAL:
				sprite.modulate = Color(1.8, 1.4, 0.4, 1.0) # Vàng hoàng kim
			ElementType.FIRE:
				sprite.modulate = Color(2.0, 0.4, 0.2, 1.0) # Đỏ lửa
			ElementType.ICE:
				sprite.modulate = Color(0.3, 1.3, 2.0, 1.0) # Xanh băng

func shoot(direction: Vector2, speed: float, lifetime: float):
	rotation = direction.angle()
	apply_impulse(direction * speed)
	get_tree().create_timer(lifetime).timeout.connect(queue_free)
