class_name FallingPlatform
extends AnimatableBody2D

@export var fall_delay: float = 0.8
@export var respawn_delay: float = 3.0
@export var fall_distance: float = 400.0

@onready var sprite: Sprite2D = $Sprite2D if has_node("Sprite2D") else null
@onready var collision_shape: CollisionShape2D = $CollisionShape2D if has_node("CollisionShape2D") else null
@onready var top_area: Area2D = $TopArea if has_node("TopArea") else null

var _initial_position: Vector2
var _is_triggered: bool = false
var _is_falling: bool = false


func _ready() -> void:
	_initial_position = position
	if top_area:
		top_area.body_entered.connect(_on_top_area_body_entered)


func _on_top_area_body_entered(body: Node2D) -> void:
	if _is_triggered:
		return
	if body is Player or body.is_in_group("Player"):
		_is_triggered = true
		_start_shake_and_fall()


func _start_shake_and_fall() -> void:
	# Shake effect
	var shake_tween = create_tween().set_loops(8)
	shake_tween.tween_property(self, "position", _initial_position + Vector2(randf_range(-3.0, 3.0), randf_range(-1.0, 2.0)), fall_delay / 8.0)
	await shake_tween.finished
	
	_is_falling = true
	if collision_shape:
		collision_shape.disabled = true
	
	# Fall tween
	var fall_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall_tween.parallel().tween_property(self, "position", _initial_position + Vector2(0, fall_distance), 0.5)
	if sprite:
		fall_tween.parallel().tween_property(sprite, "modulate:a", 0.0, 0.5)
	await fall_tween.finished
	
	# Wait for respawn
	await get_tree().create_timer(respawn_delay).timeout
	_respawn()


func _respawn() -> void:
	position = _initial_position
	if sprite:
		sprite.modulate = Color(1.0, 0.7, 0.7, 0.2)
	
	var fade_tween = create_tween()
	if sprite:
		fade_tween.parallel().tween_property(sprite, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.4)
	await fade_tween.finished
	
	if collision_shape:
		collision_shape.disabled = false
	_is_triggered = false
	_is_falling = false
