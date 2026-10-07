class_name BulletBossAbyss
extends Area2D

@export var speed: float = 450.0
@export var damage: float = 20.0
@export var lifetime: float = 4.0

var direction: Vector2 = Vector2.RIGHT
var _time_alive: float = 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	modulate = Color(1.8, 0.4, 2.2, 1.0)


func _physics_process(delta: float) -> void:
	position += direction * speed * delta
	_time_alive += delta
	if _time_alive >= lifetime:
		queue_free()


func shoot(dir: Vector2, spd: float = 450.0, life: float = 4.0) -> void:
	direction = dir.normalized()
	speed = spd
	lifetime = life
	rotation = direction.angle()


func _on_body_entered(body: Node2D) -> void:
	if body is Player or body.is_in_group("Player"):
		if body.has_method("on_hit_by_enemy"):
			body.on_hit_by_enemy(self)
		elif body.has_method("damage_tween"):
			body.damage_tween()
		queue_free()
	elif body.is_in_group("TileMap") or body is TileMapLayer:
		queue_free()


func _on_area_entered(area: Area2D) -> void:
	var parent = area.get_parent()
	if parent and (parent is Player or parent.is_in_group("Player")):
		if parent.has_method("on_hit_by_enemy"):
			parent.on_hit_by_enemy(self)
		queue_free()
