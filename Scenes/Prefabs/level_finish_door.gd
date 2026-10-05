class_name LevelFinishDoor
extends Area2D

# Define the next scene to load in the inspector
@export var next_scene : PackedScene
@export var required_keys : int = 0

@onready var sprite: Sprite2D = $Sprite2D
@onready var lock_badge: Label = $LockBadge if has_node("LockBadge") else null

var is_unlocked: bool = false
var _is_transitioning: bool = false


func _ready() -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.has_signal("keys_updated"):
		if not gm.keys_updated.is_connected(_on_keys_updated):
			gm.keys_updated.connect(_on_keys_updated)
	_update_door_state()


func _update_door_state() -> void:
	if required_keys <= 0:
		is_unlocked = true
		if lock_badge:
			lock_badge.visible = false
		if sprite:
			sprite.modulate = Color(1.2, 1.2, 1.5, 1.0)
		return

	var gm = get_node_or_null("/root/GameManager")
	var keys_collected: int = gm.keys_collected if gm else 0

	is_unlocked = (keys_collected >= required_keys)
	
	if lock_badge:
		lock_badge.visible = true
		if is_unlocked:
			lock_badge.text = "🔓 CỔNG ĐÃ MỞ"
			lock_badge.modulate = Color(0.3, 1.0, 0.4)
			if sprite:
				sprite.modulate = Color(1.2, 1.2, 1.5, 1.0)
		else:
			lock_badge.text = "🔒 Cần Chìa: %d/%d" % [keys_collected, required_keys]
			lock_badge.modulate = Color(1.0, 0.7, 0.2)
			if sprite:
				sprite.modulate = Color(0.8, 0.8, 0.9, 0.85)


func _on_keys_updated(current: int, target: int) -> void:
	var was_unlocked := is_unlocked
	_update_door_state()
	
	if not was_unlocked and is_unlocked:
		# Hiệu ứng hào quang khi vừa mở phong ấn
		var ui = get_tree().current_scene.get_node_or_null("UserInterface")
		if ui and ui.has_method("alert"):
			ui.alert("✨ Phong ấn đã mở! Cổng hầm ngục đã mở ra! ✨")
		
		var tween = create_tween()
		tween.tween_property(sprite, "scale", Vector2(1.8, 1.8), 0.2)
		tween.tween_property(sprite, "scale", Vector2(1.5, 1.5), 0.2)


# Load next level scene when player collide with level finish door.
func _on_body_entered(body: Node2D) -> void:
	if _is_transitioning:
		return
		
	if body is Player or body.is_in_group("Player"):
		if not is_unlocked:
			# Chưa đủ chìa khóa -> từ chối qua màn
			var ui = get_tree().current_scene.get_node_or_null("UserInterface")
			if ui and ui.has_method("alert"):
				var gm = get_node_or_null("/root/GameManager")
				var keys_collected: int = gm.keys_collected if gm else 0
				ui.alert("Cổng bị phong ấn! Cần thu thập đủ %d Chìa Khóa Cổ (Hiện có: %d/%d)" % [required_keys, keys_collected, required_keys])
			
			# Rung lắc cánh cửa khi bị khóa
			var orig_pos = sprite.position
			var tween = create_tween()
			tween.tween_property(sprite, "position:x", orig_pos.x - 5.0, 0.05)
			tween.tween_property(sprite, "position:x", orig_pos.x + 5.0, 0.05)
			tween.tween_property(sprite, "position:x", orig_pos.x, 0.05)
		else:
			# Đủ điều kiện -> Hiển thị Bảng Đánh Giá Màn Chơi (Level Result 1-3 Stars)
			_is_transitioning = true
			var result_packed = load("res://Scenes/UI/level_result.tscn")
			if result_packed:
				var result_ui = result_packed.instantiate()
				get_tree().current_scene.add_child(result_ui)
				if result_ui.has_method("show_result"):
					result_ui.show_result(next_scene)
			elif next_scene != null:
				var audio_mgr = get_node_or_null("/root/AudioManager")
				if audio_mgr and "level_complete_sfx" in audio_mgr and audio_mgr.level_complete_sfx:
					audio_mgr.level_complete_sfx.play()
				var st = get_node_or_null("/root/SceneTransition")
				if st and st.has_method("load_scene"):
					st.load_scene(next_scene)
