extends Node2D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.player = %Player if has_node("%Player") else null
		if gm.has_method("on_level_entered"):
			gm.on_level_entered(scene_file_path)
		else:
			gm.keys_collected = 0
			gm.keys_updated.emit(0, gm.required_keys)
		
		var coin_count := 0
		if has_node("Coins"):
			for child in $Coins.get_children():
				if "Coin" in child.name or child.is_in_group("Coin"):
					coin_count += 1
		gm.start_level_tracking(coin_count)
	
	if has_node("MusicPlayer"):
		$MusicPlayer.play(0)
		
	if has_node("UserInterface/Label"):
		var tween = create_tween()
		$UserInterface/Label.scale = Vector2.ZERO
		tween.stop(); tween.play()
		tween.tween_property($UserInterface/Label, "scale", Vector2.ONE, 1)
		await get_tree().create_timer(3).timeout
		if has_node("UserInterface/Label"):
			$UserInterface/Label.queue_free()
	
	var current_score = gm.score if gm else 0
	if current_score == 0 and scene_file_path.to_lower().contains("level_01"):
		await get_tree().create_timer(0.4).timeout
		var dm = get_node_or_null("/root/DialogueManager")
		if dm and dm.has_method("start_dialogue"):
			dm.start_dialogue([
				"Ta đã đặt chân vào Tầng 1 của Hầm Ngục Hắc Ám...",
				"Kìa, Trưởng Làng đang đứng phía trước! Ta nên tới gặp ông ấy xem tình hình thế nào."
			], "Hiệp Sĩ")

func _on_player_hit_enemy() -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.damage(15)	

func _on_player_hit_trap() -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.death()

func _on_music_player_finished() -> void:
	if has_node("MusicPlayer"):
		$MusicPlayer.play(0)
