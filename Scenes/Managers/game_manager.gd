# This script is an autoload, that can be accessed from any other script!

extends Node2D

signal keys_updated(current_keys: int, target_keys: int)

var score : int = 0
var hp    : int = 100
var life  : int = 4
var max_life : int = 5
var max_hp  :int = 100
var keys_collected : int = 0
var required_keys : int = 3

var level_stars : Dictionary = {}
var level_time : float = 0.0
var level_coins_collected : int = 0
var level_coins_total : int = 0
var level_lives_lost : int = 0

# Run stats shown on the ending screen.
var play_time : float = 0.0
var lives_lost : int = 0
var _timing_active : bool = false

var sfx_on = true
var music_on = true
var master_volume: float = 1.0
var music_volume: float = 0.8
var sfx_volume: float = 1.0

var player :Player = null
var selected_character_id: String = "knight"
var current_level : String = "res://Scenes/Levels/level_01.tscn"
var unlocked_level : String = "res://Scenes/Levels/level_01.tscn"
var save_path := "user://game.save"
var save_player_position = Vector2.ZERO

func _ready() -> void:
	peek_save_metadata()

# Adds score (combat, killing enemies, boss)
func add_score(v=1):
	score += v

# Adds coin (collecting coins in level)
func add_coin(v=1):
	score += v
	level_coins_collected += v

func _process(delta: float) -> void:
	if _timing_active:
		play_time += delta
		var dm = get_node_or_null("/root/DialogueManager")
		var is_dialogue_open: bool = (dm != null and "is_active" in dm and dm.is_active)
		if not is_dialogue_open:
			level_time += delta

# Starts the run timer. Called by each level so the clock only runs during play.
func begin_timing() -> void:
	_timing_active = true

func start_level_tracking(total_coins: int = 0) -> void:
	level_time = 0.0
	level_coins_collected = 0
	level_coins_total = total_coins
	level_lives_lost = 0
	_timing_active = true

func get_level_number(path: String) -> int:
	var lower = path.to_lower()
	for i in range(1, 10):
		if ("level_0%d" % i) in lower or ("level_%d" % i) in lower:
			return i
	return 1

func get_target_continue_level() -> String:
	var unl_num = get_level_number(unlocked_level)
	var cur_num = get_level_number(current_level)
	if unl_num > cur_num and unlocked_level.to_lower().contains("level"):
		return unlocked_level
	if current_level.to_lower().contains("level"):
		return current_level
	return "res://Scenes/Levels/level_01.tscn"

func get_continue_level_display_name() -> String:
	if not has_gamesaved():
		return ""
	var target = get_target_continue_level()
	var num = get_level_number(target)
	return "Tầng %d" % num

func complete_level(level_key: String, stars: int, next_scene_path: String = "") -> void:
	# 1. Update best star count
	var prev_stars: int = level_stars.get(level_key, 0)
	if stars > prev_stars:
		level_stars[level_key] = stars
	
	# 2. Advance progression to next floor
	if next_scene_path != "" and next_scene_path.to_lower().contains("level"):
		current_level = next_scene_path
		if get_level_number(next_scene_path) > get_level_number(unlocked_level):
			unlocked_level = next_scene_path
	elif next_scene_path.to_lower().contains("congrat"):
		# Finished game
		current_level = "res://Scenes/Levels/level_04.tscn"
		unlocked_level = "res://Scenes/Levels/level_04.tscn"
	
	# 3. Clean up level-specific states for the fresh level
	save_player_position = Vector2.ZERO
	keys_collected = 0
	level_coins_collected = 0
	level_time = 0.0
	level_lives_lost = 0
	
	# 4. Persist to disk immediately so Continue starts at the new level
	save_game()

func on_level_entered(scene_path: String) -> void:
	if "level_" in scene_path.to_lower():
		current_level = scene_path
		if get_level_number(scene_path) > get_level_number(unlocked_level):
			unlocked_level = scene_path
		save_checkpoint(scene_path)
	keys_collected = 0
	keys_updated.emit(0, required_keys)

func record_level_stars(level_key: String, stars: int) -> void:
	complete_level(level_key, stars, "")

# Formats play_time as MM:SS for the ending screen.
func play_time_text() -> String:
	var total := int(play_time)
	return "%02d:%02d" % [total / 60, total % 60]

func add_key(v: int = 1) -> void:
	keys_collected += v
	keys_updated.emit(keys_collected, required_keys)

func shake_camera(strength: float = 6.0, duration: float = 0.2) -> void:
	if player and is_instance_valid(player) and player.has_method("shake"):
		player.shake(strength, duration)

func slow_motion(time_scale: float = 0.2, duration_sec: float = 0.5) -> void:
	Engine.time_scale = time_scale
	await get_tree().create_timer(duration_sec, true, false, true).timeout
	var tween = create_tween().set_trans(Tween.TRANS_SINE)
	tween.tween_property(Engine, "time_scale", 1.0, 0.15)

# Loads next level
func load_next_level(next_scene : PackedScene):
	Engine.time_scale = 1.0
	get_tree().change_scene_to_packed(next_scene)

func restart():
	Engine.time_scale = 1.0
	score = 0
	hp = 100
	life = 4
	keys_collected = 0
	level_time = 0.0
	level_coins_collected = 0
	save_player_position = Vector2.ZERO
	play_time = 0.0
	lives_lost = 0
	_timing_active = false
	current_level = "res://Scenes/Levels/level_01.tscn"
	unlocked_level = "res://Scenes/Levels/level_01.tscn"
	keys_updated.emit(keys_collected, required_keys)
	save_game()
	get_tree().change_scene_to_file("res://Scenes/Levels/level_01.tscn")


func damage(val=1):
	hp = hp - val
	if hp <=0 :
		death()
func add_hp(val=1):
	hp = hp + val
	if hp >max_hp:
		hp = max_hp

func set_bus_volume(bus_name: String, linear_val: float) -> void:
	var bus_idx = AudioServer.get_bus_index(bus_name)
	if bus_idx != -1:
		var db_val = linear_to_db(clampf(linear_val, 0.0001, 1.0))
		AudioServer.set_bus_volume_db(bus_idx, db_val)
		AudioServer.set_bus_mute(bus_idx, linear_val <= 0.001)

func update_option():
	set_bus_volume("Master", master_volume)
	set_bus_volume("music", music_volume if music_on else 0.0)
	set_bus_volume("sfx", sfx_volume if sfx_on else 0.0)

func add_life():
	if life < max_life:
		life += 1

func death():
	if player != null:
		await player.death_tween()
	life -= 1
	lives_lost += 1
	level_lives_lost += 1
	if life <= 0:
		_timing_active = false
		get_tree().change_scene_to_file("res://Scenes/Levels/game_over.tscn")	

func save_option():
	var file = FileAccess.open("user://option.json", FileAccess.WRITE)
	if file:
		var payload: Dictionary = {
			"music": music_on,
			"sound": sfx_on,
			"master_volume": master_volume,
			"music_volume": music_volume,
			"sfx_volume": sfx_volume,
		}
		var json_text = JSON.stringify(payload, "  ")
		file.store_pascal_string(json_text)
		file.close()

func load_option():
	if FileAccess.file_exists("user://option.json"):
		var file = FileAccess.open("user://option.json", FileAccess.READ)
		var text = file.get_pascal_string()
		var data = JSON.parse_string(text)        		
		file.close()
		music_on = data.get("music", true)
		sfx_on = data.get("sound", true)
		master_volume = data.get("master_volume", 1.0)
		music_volume = data.get("music_volume", 0.8)
		sfx_volume = data.get("sfx_volume", 1.0)
		update_option()
				
func peek_save_metadata() -> void:
	if FileAccess.file_exists(save_path):
		var file = FileAccess.open(save_path, FileAccess.READ)
		if file:
			var text = file.get_pascal_string()
			file.close()
			var data = JSON.parse_string(text)
			if data is Dictionary:
				current_level = data.get("current_level", current_level)
				unlocked_level = data.get("unlocked_level", current_level)
				score = int(data.get("score", score))
				life = int(data.get("life", life))
				hp = int(data.get("hp", hp))
				level_stars = data.get("level_stars", level_stars)
				selected_character_id = data.get("selected_character_id", selected_character_id)

func save_checkpoint(custom_scene: String = "") -> void:
	var scene_to_save: String = custom_scene
	if scene_to_save == "":
		var active = get_tree().current_scene
		if active and active.scene_file_path:
			scene_to_save = active.scene_file_path
		else:
			scene_to_save = current_level
	if "level_" in scene_to_save.to_lower():
		current_level = scene_to_save
		if get_level_number(scene_to_save) > get_level_number(unlocked_level):
			unlocked_level = scene_to_save
	save_player_position = Vector2.ZERO
	save_game()

func save_game():
	var active = get_tree().current_scene
	if active and active.scene_file_path:
		var path: String = active.scene_file_path
		if "level_" in path.to_lower():
			current_level = path
			if get_level_number(path) > get_level_number(unlocked_level):
				unlocked_level = path

	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		var pos = save_player_position
		var payload: Dictionary = {
			"current_level" : current_level,
			"unlocked_level": unlocked_level,
			"player" : [pos.x, pos.y],
			"score": score,
			"hp": max(hp, 50),
			"life" : max(life, 1),
			"keys_collected": keys_collected,
			"level_stars": level_stars,
			"selected_character_id": selected_character_id
		}
		var json_text = JSON.stringify(payload, "  ")
		file.store_pascal_string(json_text)
		file.close()

func has_gamesaved():
	return FileAccess.file_exists(save_path)

func load_game():
	if FileAccess.file_exists(save_path):
		var file = FileAccess.open(save_path, FileAccess.READ)
		var text = file.get_pascal_string()
		var data = JSON.parse_string(text)
		file.close()
		if data is Dictionary:
			current_level = data.get("current_level", current_level)
			unlocked_level = data.get("unlocked_level", current_level)
			score = int(data.get("score", score))
			life = int(data.get("life", 4))
			if life <= 0: life = 1
			hp = int(data.get("hp", 100))
			if hp <= 0: hp = 100
			keys_collected = 0
			level_stars = data.get("level_stars", {})
			selected_character_id = data.get("selected_character_id", "knight")
			keys_updated.emit(keys_collected, required_keys)
			
			var target_level = get_target_continue_level()
			current_level = target_level
			save_player_position = Vector2.ZERO
			
			_timing_active = false
			level_time = 0.0
			level_coins_collected = 0
			level_lives_lost = 0
			Engine.time_scale = 1.0
			
			get_tree().change_scene_to_file(current_level)
			return
	restart()	
