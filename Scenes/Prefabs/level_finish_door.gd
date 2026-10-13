class_name LevelFinishDoor
extends Area2D

# Define the next scene to load in the inspector
@export var next_scene : PackedScene
@export var required_keys : int = 0
@export var require_boss_defeat : bool = false

@onready var sprite: Sprite2D = $Sprite2D
@onready var lock_badge: Label = $LockBadge if has_node("LockBadge") else null

var is_unlocked: bool = false
var is_boss_cleared: bool = false
var _is_transitioning: bool = false
var _has_boss_in_level: bool = false


func _ready() -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.has_signal("keys_updated"):
		if not gm.keys_updated.is_connected(_on_keys_updated):
			gm.keys_updated.connect(_on_keys_updated)
			
	_setup_boss_requirement.call_deferred()


func _setup_boss_requirement() -> void:
	if not is_inside_tree():
		return
	var bosses = get_tree().get_nodes_in_group("Boss")
	if bosses.size() > 0 or require_boss_defeat:
		require_boss_defeat = true
		_has_boss_in_level = true
		is_boss_cleared = false
		for b in bosses:
			if b.has_signal("boss_defeated"):
				if not b.boss_defeated.is_connected(_on_boss_defeated):
					b.boss_defeated.connect(_on_boss_defeated)
			if not b.tree_exited.is_connected(_on_boss_tree_exited):
				b.tree_exited.connect(_on_boss_tree_exited)
	else:
		_has_boss_in_level = false
		is_boss_cleared = true
		
	_update_door_state()


func _on_boss_defeated() -> void:
	if is_boss_cleared:
		return
	is_boss_cleared = true
	var was_unlocked := is_unlocked
	_update_door_state()
	_play_boss_unlocked_effect()


func _on_boss_tree_exited() -> void:
	if is_boss_cleared or not is_inside_tree() or get_tree() == null:
		return
	_check_remaining_bosses.call_deferred()


func _check_remaining_bosses() -> void:
	if is_boss_cleared or not is_inside_tree() or get_tree() == null:
		return
	var remaining = get_tree().get_nodes_in_group("Boss")
	var any_alive := false
	for b in remaining:
		if is_instance_valid(b) and ("alive" not in b or b.alive):
			any_alive = true
			break
	if not any_alive and not is_boss_cleared:
		_on_boss_defeated()


func _update_door_state() -> void:
	var gm = get_node_or_null("/root/GameManager")
	var keys_collected: int = gm.keys_collected if gm else 0
	var keys_ok: bool = (required_keys <= 0 or keys_collected >= required_keys)
	var boss_ok: bool = (not require_boss_defeat or is_boss_cleared)

	is_unlocked = keys_ok and boss_ok

	if not lock_badge:
		if sprite:
			sprite.modulate = Color(1.3, 1.3, 1.6, 1.0) if is_unlocked else Color(0.9, 0.4, 0.45, 0.9)
		return

	lock_badge.visible = true

	if is_unlocked:
		lock_badge.text = "🔓 CỔNG ĐÃ MỞ"
		lock_badge.modulate = Color(0.3, 1.0, 0.4)
		if sprite:
			sprite.modulate = Color(1.3, 1.3, 1.6, 1.0)
	elif not boss_ok:
		# Chưa hạ gục Boss của màn
		if required_keys > 0 and keys_collected < required_keys:
			lock_badge.text = "👹 Cần Chìa %d/%d & Hạ Boss" % [keys_collected, required_keys]
		else:
			lock_badge.text = "👹 CẦN HẠ GỤC BOSS!"
		lock_badge.modulate = Color(1.0, 0.3, 0.3)
		if sprite:
			sprite.modulate = Color(0.85, 0.35, 0.45, 0.9) # Phong ấn ma thuật đỏ thẫm
	else:
		# Đã hạ boss nhưng chưa đủ chìa khóa
		lock_badge.text = "🔒 Cần Chìa: %d/%d" % [keys_collected, required_keys]
		lock_badge.modulate = Color(1.0, 0.7, 0.2)
		if sprite:
			sprite.modulate = Color(0.8, 0.8, 0.9, 0.85)


func _get_ui_node() -> Node:
	if not is_inside_tree() or get_tree() == null:
		return null
	if get_tree().current_scene:
		var ui = get_tree().current_scene.get_node_or_null("UserInterface")
		if ui: return ui
	var root = get_tree().root
	if root:
		return root.find_child("UserInterface", true, false)
	return null


func _on_keys_updated(current: int, target: int) -> void:
	var was_unlocked := is_unlocked
	_update_door_state()
	
	if not was_unlocked and is_unlocked:
		var ui = _get_ui_node()
		if ui and ui.has_method("alert"):
			ui.alert("✨ Phong ấn đã mở! Cổng hầm ngục đã mở ra! ✨")
		
		if sprite:
			var tween = create_tween()
			tween.tween_property(sprite, "scale", Vector2(1.8, 1.8), 0.2)
			tween.tween_property(sprite, "scale", Vector2(1.5, 1.5), 0.2)


func _play_boss_unlocked_effect() -> void:
	var ui = _get_ui_node()
	if ui and ui.has_method("alert"):
		ui.alert("👑 Trùm Hắc Ám đã bị tiêu diệt! Phong ấn cổng thử thách đã mở ra! 👑")
	
	if sprite:
		var tween = create_tween()
		tween.tween_property(sprite, "scale", Vector2(2.0, 2.0), 0.25)
		tween.tween_property(sprite, "scale", Vector2(1.5, 1.5), 0.2)
		
		# Hiệu ứng nổ hạt hào quang giải phóng phong ấn
		var burst := CPUParticles2D.new()
		burst.emitting = false
		burst.one_shot = true
		burst.explosiveness = 0.9
		burst.amount = 26
		burst.lifetime = 0.85
		burst.spread = 180.0
		burst.gravity = Vector2.ZERO
		burst.initial_velocity_min = 90.0
		burst.initial_velocity_max = 200.0
		burst.scale_amount_min = 2.5
		burst.scale_amount_max = 5.5
		burst.color = Color(1.9, 1.6, 0.6, 1.0)
		burst.global_position = global_position
		add_child(burst)
		burst.emitting = true
		get_tree().create_timer(1.0).timeout.connect(burst.queue_free)


# Load next level scene when player collide with level finish door.
func _on_body_entered(body: Node2D) -> void:
	if _is_transitioning:
		return
		
	if body is Player or body.is_in_group("Player"):
		if not is_unlocked:
			var ui = _get_ui_node()
			var gm = get_node_or_null("/root/GameManager")
			var keys_collected: int = gm.keys_collected if gm else 0
			var keys_ok: bool = (required_keys <= 0 or keys_collected >= required_keys)
			var boss_ok: bool = (not require_boss_defeat or is_boss_cleared)
			
			if not boss_ok:
				if ui and ui.has_method("alert"):
					ui.alert("⚠️ Cổng bị phong ấn bởi Sức Mạnh Trùm! Phải tiêu diệt Boss trước mới có thể hoàn thành thử thách!")
			elif not keys_ok:
				if ui and ui.has_method("alert"):
					ui.alert("Cổng bị phong ấn! Cần thu thập đủ %d Chìa Khóa Cổ (Hiện có: %d/%d)" % [required_keys, keys_collected, required_keys])
			
			# Rung lắc cánh cửa khi bị khóa từ chối vào
			if sprite:
				var orig_pos = sprite.position
				var tween = create_tween()
				tween.tween_property(sprite, "position:x", orig_pos.x - 6.0, 0.04)
				tween.tween_property(sprite, "position:x", orig_pos.x + 6.0, 0.04)
				tween.tween_property(sprite, "position:x", orig_pos.x - 4.0, 0.04)
				tween.tween_property(sprite, "position:x", orig_pos.x + 4.0, 0.04)
				tween.tween_property(sprite, "position:x", orig_pos.x, 0.04)
		else:
			# Đủ điều kiện -> Hiển thị Bảng Đánh Giá Màn Chơi (Level Result 1-3 Stars)
			_is_transitioning = true
			var result_packed = load("res://Scenes/UI/level_result.tscn")
			if result_packed:
				var result_ui = result_packed.instantiate()
				var parent_node = get_tree().current_scene if (get_tree() and get_tree().current_scene) else (get_tree().root if get_tree() else self)
				parent_node.add_child(result_ui)
				if result_ui.has_method("show_result"):
					result_ui.show_result(next_scene)
			elif next_scene != null:
				var audio_mgr = get_node_or_null("/root/AudioManager")
				if audio_mgr and "level_complete_sfx" in audio_mgr and audio_mgr.level_complete_sfx:
					audio_mgr.level_complete_sfx.play()
				var st = get_node_or_null("/root/SceneTransition")
				if st and st.has_method("load_scene"):
					st.load_scene(next_scene)
