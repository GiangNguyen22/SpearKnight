class_name LevelResult
extends CanvasLayer

signal next_level_pressed
signal replay_pressed
signal menu_pressed

@export var next_scene: PackedScene

@onready var backdrop: ColorRect = $Backdrop
@onready var panel: PanelContainer = $CenterContainer/Panel
@onready var level_name_lbl: Label = $CenterContainer/Panel/Margin/VBox/HeaderBox/LevelNameLabel
@onready var star1_rect: TextureRect = $CenterContainer/Panel/Margin/VBox/StarsBox/StarCol1/Star1
@onready var star2_rect: TextureRect = $CenterContainer/Panel/Margin/VBox/StarsBox/StarCol2/Star2
@onready var star3_rect: TextureRect = $CenterContainer/Panel/Margin/VBox/StarsBox/StarCol3/Star3
@onready var star1_lbl: Label = $CenterContainer/Panel/Margin/VBox/StarsBox/StarCol1/Label1
@onready var star2_lbl: Label = $CenterContainer/Panel/Margin/VBox/StarsBox/StarCol2/Label2
@onready var star3_lbl: Label = $CenterContainer/Panel/Margin/VBox/StarsBox/StarCol3/Label3
@onready var time_val: Label = $CenterContainer/Panel/Margin/VBox/StatsGrid/CardTime/VBox/Value
@onready var time_sub: Label = $CenterContainer/Panel/Margin/VBox/StatsGrid/CardTime/VBox/Sub
@onready var coin_val: Label = $CenterContainer/Panel/Margin/VBox/StatsGrid/CardCoins/VBox/Value
@onready var coin_sub: Label = $CenterContainer/Panel/Margin/VBox/StatsGrid/CardCoins/VBox/Sub
@onready var hp_val: Label = $CenterContainer/Panel/Margin/VBox/StatsGrid/CardHP/VBox/Value
@onready var hp_sub: Label = $CenterContainer/Panel/Margin/VBox/StatsGrid/CardHP/VBox/Sub
@onready var next_btn: Button = $CenterContainer/Panel/Margin/VBox/ButtonsBox/NextButton
@onready var replay_btn: Button = $CenterContainer/Panel/Margin/VBox/ButtonsBox/ReplayButton
@onready var menu_btn: Button = $CenterContainer/Panel/Margin/VBox/ButtonsBox/MenuButton
@onready var ding_sfx: AudioStreamPlayer = $DingSfx
@onready var complete_sfx: AudioStreamPlayer = $CompleteSfx

var gold_star_tex: Texture2D
var gray_star_tex: Texture2D
var earned_stars: int = 1


func _ready() -> void:
	gold_star_tex = load("res://Assets/UI/star_gold.png")
	gray_star_tex = load("res://Assets/UI/star_gray.png")
	
	star1_rect.texture = gray_star_tex
	star2_rect.texture = gray_star_tex
	star3_rect.texture = gray_star_tex
	
	star1_rect.pivot_offset = Vector2(32, 32)
	star2_rect.pivot_offset = Vector2(34, 34)
	star3_rect.pivot_offset = Vector2(32, 32)
	
	star1_lbl.modulate = Color(0.5, 0.55, 0.6)
	star2_lbl.modulate = Color(0.5, 0.55, 0.6)
	star3_lbl.modulate = Color(0.5, 0.55, 0.6)
	
	next_btn.pressed.connect(_on_next_pressed)
	replay_btn.pressed.connect(_on_replay_pressed)
	menu_btn.pressed.connect(_on_menu_pressed)


func show_result(p_next_scene: PackedScene = null) -> void:
	if p_next_scene:
		next_scene = p_next_scene
		
	# Pause player physics & stop timer
	GameManager._timing_active = false
	if GameManager.player and is_instance_valid(GameManager.player):
		GameManager.player.movement_enabled = false
		GameManager.player.velocity = Vector2.ZERO
		
	# 1. Level Name Display
	var cur_path: String = get_tree().current_scene.scene_file_path
	var level_file := cur_path.get_file().get_basename().to_lower()
	var level_title := "HẦM NGỤC"
	if "level_01" in level_file:
		level_title = "HẦM NGỤC - TẦNG 1"
	elif "level_02" in level_file:
		level_title = "HẦM NGỤC - TẦNG 2"
	elif "level_03" in level_file:
		level_title = "HẦM NGỤC - TẦNG 3"
	elif "level_04" in level_file:
		level_title = "HÀNG Ổ QUÁI VẬT - TẦNG 4"
	level_name_lbl.text = level_title
		
	# 2. Accurate Star Calculation:
	# ⭐ Star 1: Finish Level (Always earned upon reaching door)
	var star1_pass := true
	
	# ⭐ Star 2: Collect >= 80% Coins in Level
	var coin_ratio: float = 1.0
	if GameManager.level_coins_total > 0:
		coin_ratio = float(GameManager.level_coins_collected) / float(GameManager.level_coins_total)
	var star2_pass: bool = (coin_ratio >= 0.8)
	
	# ⭐ Star 3: Time <= 60s and No deaths in level and HP >= 50%
	var time_pass: bool = (GameManager.level_time <= 60.0)
	var hp_pass: bool = (GameManager.hp >= 50 and GameManager.level_lives_lost == 0)
	var star3_pass: bool = (time_pass and hp_pass)
	
	earned_stars = 1
	if star2_pass: earned_stars += 1
	if star3_pass: earned_stars += 1
	
	# 3. Populate Accurate Numerical Stats (Clean Cards)
	var total_sec := int(GameManager.level_time)
	var time_str := "%02d:%02d" % [total_sec / 60, total_sec % 60]
	time_val.text = time_str
	time_sub.text = "Mục tiêu: < 60s"
	time_sub.modulate = Color(0.4, 1.0, 0.7) if time_pass else Color(0.65, 0.7, 0.75)
	
	var coin_pct := int(clampf(coin_ratio * 100.0, 0.0, 100.0))
	coin_val.text = "%d / %d" % [GameManager.level_coins_collected, GameManager.level_coins_total]
	coin_sub.text = "%d%% (Mục tiêu: ≥ 80%%)" % coin_pct
	coin_sub.modulate = Color(1.0, 0.85, 0.3) if star2_pass else Color(0.65, 0.7, 0.75)
	
	hp_val.text = "%d HP" % GameManager.hp
	if GameManager.level_lives_lost > 0:
		hp_sub.text = "Mất %d mạng" % GameManager.level_lives_lost
		hp_sub.modulate = Color(0.9, 0.4, 0.4)
	else:
		hp_sub.text = "Không mất mạng"
		hp_sub.modulate = Color(0.4, 1.0, 0.7) if hp_pass else Color(0.65, 0.7, 0.75)
	
	# 4. Advance progression & save stars for completing this level
	var next_path := ""
	if next_scene != null:
		next_path = next_scene.resource_path
	GameManager.complete_level(level_file, earned_stars, next_path)
	
	# 5. Animate Window Entry
	panel.scale = Vector2(0.8, 0.8)
	panel.modulate.a = 0.0
	backdrop.modulate.a = 0.0
	
	var tw = create_tween()
	tw.parallel().tween_property(backdrop, "modulate:a", 1.0, 0.2)
	tw.parallel().tween_property(panel, "modulate:a", 1.0, 0.2)
	tw.parallel().tween_property(panel, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	await tw.finished
	await get_tree().create_timer(0.12).timeout
	
	# 6. Star Pop Animation with Chimes
	var star_rects = [star1_rect, star2_rect, star3_rect]
	var star_lbls = [star1_lbl, star2_lbl, star3_lbl]
	var star_passes = [star1_pass, star2_pass, star3_pass]
	
	for i in range(3):
		await get_tree().create_timer(0.22).timeout
		var s_rect: TextureRect = star_rects[i]
		var s_lbl: Label = star_lbls[i]
		var is_pass: bool = star_passes[i]
		
		if is_pass:
			s_rect.texture = gold_star_tex
			s_rect.scale = Vector2.ZERO
			s_lbl.modulate = Color(1.0, 0.88, 0.35)
			
			if ding_sfx:
				ding_sfx.pitch_scale = 1.0 + float(i) * 0.24
				ding_sfx.play()
			
			var s_tw = create_tween()
			s_tw.tween_property(s_rect, "scale", Vector2(1.35, 1.35), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			s_tw.tween_property(s_rect, "scale", Vector2.ONE, 0.1)
		else:
			s_rect.texture = gray_star_tex
			s_rect.modulate.a = 0.35
			s_lbl.modulate = Color(0.45, 0.5, 0.55)
			
	await get_tree().create_timer(0.2).timeout
	if complete_sfx:
		complete_sfx.play()


func _on_next_pressed() -> void:
	if next_scene != null:
		SceneTransition.load_scene(next_scene)
	else:
		var congrat_path := "res://Scenes/Levels/congrat.tscn"
		if ResourceLoader.exists(congrat_path):
			get_tree().change_scene_to_file(congrat_path)
		else:
			get_tree().change_scene_to_file("res://Scenes/Levels/game_win.tscn")


func _on_replay_pressed() -> void:
	var cur_path: String = get_tree().current_scene.scene_file_path
	GameManager.load_next_level(load(cur_path))


func _on_menu_pressed() -> void:
	SceneTransition.load_scene(load("res://Scenes/Levels/menu.tscn"))
