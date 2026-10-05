class_name KeyItem
extends Area2D

signal collected

@export var bob_amplitude: float = 6.0
@export var bob_speed: float = 3.0
@export var rotation_amplitude: float = 0.12

@onready var sprite: Sprite2D = $Sprite2D
@onready var pickup_sfx: AudioStreamPlayer2D = $PickupSfx
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var _base_y: float = 0.0
var _time: float = 0.0
var _is_collected: bool = false


func _ready() -> void:
	_base_y = position.y
	_time = randf_range(0.0, TAU)
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	if _is_collected:
		return
	_time += delta * bob_speed
	position.y = _base_y + sin(_time) * bob_amplitude
	if sprite:
		sprite.rotation = sin(_time * 0.8) * rotation_amplitude


func _on_body_entered(body: Node2D) -> void:
	if _is_collected:
		return
	if body is Player or body.is_in_group("Player"):
		_is_collected = true
		collision_shape.set_deferred("disabled", true)
		
		var gm = get_node_or_null("/root/GameManager")
		var keys_c = 0
		var keys_req = 3
		if gm:
			if gm.has_method("add_key"):
				gm.add_key(1)
			if "keys_collected" in gm:
				keys_c = gm.keys_collected
			if "required_keys" in gm:
				keys_req = gm.required_keys
		collected.emit()
		
		var ui = get_tree().current_scene.get_node_or_null("UserInterface")
		if ui and ui.has_method("alert"):
			ui.alert("Đã nhặt Chìa Khóa Cổ! (%d/%d)" % [keys_c, keys_req])
		
		if pickup_sfx:
			pickup_sfx.play()
		
		var tween = create_tween()
		tween.parallel().tween_property(self, "position:y", position.y - 40.0, 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		tween.parallel().tween_property(self, "scale", Vector2(1.5, 1.5), 0.35)
		tween.parallel().tween_property(self, "modulate:a", 0.0, 0.35)
		
		await tween.finished
		queue_free()
