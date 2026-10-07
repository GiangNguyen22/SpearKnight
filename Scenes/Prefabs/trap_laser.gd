class_name TrapLaser
extends Area2D

@export var toggle_interval: float = 1.5
@export var damage: float = 25.0
@export var is_laser_on: bool = true
@export var start_delay: float = 0.0

@onready var beam_sprite: Sprite2D = $BeamSprite if has_node("BeamSprite") else null
@onready var collision_shape: CollisionShape2D = $CollisionShape2D if has_node("CollisionShape2D") else null
@onready var toggle_timer: Timer = $ToggleTimer if has_node("ToggleTimer") else null
@onready var light_glow: PointLight2D = $PointLight2D if has_node("PointLight2D") else null

var _damage_cooldown: float = 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	if toggle_timer == null:
		toggle_timer = Timer.new()
		toggle_timer.name = "ToggleTimer"
		add_child(toggle_timer)
	
	toggle_timer.wait_time = maxf(0.2, toggle_interval)
	toggle_timer.one_shot = false
	toggle_timer.timeout.connect(_on_timer_timeout)
	
	if start_delay > 0:
		toggle_timer.stop()
		await get_tree().create_timer(start_delay).timeout
		
	toggle_timer.start()
	_update_state()


func _process(delta: float) -> void:
	if _damage_cooldown > 0:
		_damage_cooldown -= delta
	
	if is_laser_on:
		for body in get_overlapping_bodies():
			_check_and_damage_player(body)


func _on_timer_timeout() -> void:
	is_laser_on = not is_laser_on
	_update_state()


func _update_state() -> void:
	if collision_shape:
		collision_shape.disabled = not is_laser_on
	if beam_sprite:
		beam_sprite.visible = is_laser_on
		if is_laser_on:
			beam_sprite.modulate = Color(2.5, 0.4, 0.4, 1.0)
	if light_glow:
		light_glow.enabled = is_laser_on


func _on_body_entered(body: Node2D) -> void:
	if is_laser_on:
		_check_and_damage_player(body)


func _check_and_damage_player(body: Node2D) -> void:
	if _damage_cooldown > 0:
		return
	if body is Player or body.is_in_group("Player"):
		_damage_cooldown = 0.8
		if body.has_method("on_hit_by_enemy"):
			body.on_hit_by_enemy(self)
		elif body.has_method("damage_tween"):
			body.damage_tween()
		
		var gm = get_node_or_null("/root/GameManager")
		if gm and gm.has_method("shake_camera"):
			gm.shake_camera(12.0, 0.25)
		elif body.has_method("shake"):
			body.shake(12.0, 0.25)
