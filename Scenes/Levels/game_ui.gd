extends CanvasLayer

@onready var score_label: Label = %ScoreLabel if has_node("%ScoreLabel") else null
@onready var key_label: Label = %KeyLabel if has_node("%KeyLabel") else null
@onready var hp_bar: ProgressBar = %ProgressBar if has_node("%ProgressBar") else null
@onready var hp_label: Label = %HPLabel if has_node("%HPLabel") else null
@onready var max_hp_label: Label = %MaxHPLabel if has_node("%MaxHPLabel") else null
@onready var life_rect: TextureRect = %LifeRect if has_node("%LifeRect") else null

@onready var btn_sound: Button = get_node_or_null("GameUI/TopBar/TopRightWidget/BtnSound") if has_node("GameUI/TopBar/TopRightWidget/BtnSound") else (%BtnSound if has_node("%BtnSound") else null)
@onready var btn_music: Button = get_node_or_null("GameUI/TopBar/TopRightWidget/BtnMusic") if has_node("GameUI/TopBar/TopRightWidget/BtnMusic") else (%BtnMusic if has_node("%BtnMusic") else null)
@onready var btn_pause: Button = get_node_or_null("GameUI/TopBar/TopRightWidget/BtnPause") if has_node("GameUI/TopBar/TopRightWidget/BtnPause") else (%BtnPause if has_node("%BtnPause") else null)
@onready var sound_icon: TextureRect = get_node_or_null("GameUI/TopBar/TopRightWidget/BtnSound/SoundIcon") if has_node("GameUI/TopBar/TopRightWidget/BtnSound/SoundIcon") else (%SoundIcon if has_node("%SoundIcon") else null)
@onready var music_icon: TextureRect = get_node_or_null("GameUI/TopBar/TopRightWidget/BtnMusic/MusicIcon") if has_node("GameUI/TopBar/TopRightWidget/BtnMusic/MusicIcon") else (%MusicIcon if has_node("%MusicIcon") else null)

@onready var boss_panel: Control = %BossBarPanel if has_node("%BossBarPanel") else null
@onready var boss_bar: ProgressBar = %BossProgressBar if has_node("%BossProgressBar") else null

@onready var alert_label: Label = %AlertLabel if has_node("%AlertLabel") else null
@onready var shop_menu: Control = $ShopMenu if has_node("ShopMenu") else null
@onready var pause_menu: Control = $PauseMenu if has_node("PauseMenu") else null

@onready var btn_skill: Button = get_node_or_null("GameUI/BottomControls/btnSkill")
@onready var skill_label: Label = %SkillLabel if has_node("%SkillLabel") else null
@onready var cooldown_overlay: ColorRect = %CooldownOverlay if has_node("%CooldownOverlay") else null

var current_boss: Node2D = null
var _last_cid: String = ""

# Preloaded audio icon textures for fast switching
var sound_on_tex: Texture2D
var sound_off_tex: Texture2D
var music_on_tex: Texture2D
var music_off_tex: Texture2D


func _ready() -> void:
	sound_on_tex = load("res://Assets/UI/icon_sound_on.png")
	sound_off_tex = load("res://Assets/UI/icon_sound_off.png")
	music_on_tex = load("res://Assets/UI/icon_music_on.png")
	music_off_tex = load("res://Assets/UI/icon_music_off.png")
	
	if btn_pause and not btn_pause.pressed.is_connected(_on_btn_pause_pressed):
		btn_pause.pressed.connect(_on_btn_pause_pressed)
	if btn_sound and not btn_sound.pressed.is_connected(_on_btn_sound_pressed):
		btn_sound.pressed.connect(_on_btn_sound_pressed)
	if btn_music and not btn_music.pressed.is_connected(_on_btn_music_pressed):
		btn_music.pressed.connect(_on_btn_music_pressed)
		
	update_audio_icons()
	update_skill_button_for_character()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_B:
		toggle_shop()


func toggle_shop() -> void:
	if shop_menu:
		if shop_menu.visible:
			shop_menu.close_shop()
		else:
			shop_menu.open_shop()


func _process(_delta: float) -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		if score_label:
			score_label.text = "Score: %d" % gm.score
		if key_label:
			key_label.text = "Keys: %d/%d" % [gm.keys_collected, gm.required_keys]
		if hp_bar:
			hp_bar.max_value = gm.max_hp
			hp_bar.value = gm.hp
		if hp_label and hp_label.text != "HP":
			hp_label.text = "HP"
		if max_hp_label:
			max_hp_label.text = "%d HP" % gm.max_hp
		if life_rect:
			# Each heart icon is 48px wide as in original game
			life_rect.size.x = 48.0 * float(gm.life)
		
		update_audio_icons()
	
	check_boss_status()
	update_skill_cooldown()
	
	# Cập nhật skill button khi nhân vật thay đổi
	var gm2 = get_node_or_null("/root/GameManager")
	var cid: String = gm2.selected_character_id if gm2 and "selected_character_id" in gm2 else "knight"
	if cid != _last_cid:
		_last_cid = cid
		update_skill_button_for_character()


func update_audio_icons() -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		if sound_icon:
			sound_icon.texture = sound_on_tex if gm.sfx_on else sound_off_tex
			sound_icon.modulate = Color(1, 1, 1, 1) if gm.sfx_on else Color(0.7, 0.7, 0.7, 0.5)
		if music_icon:
			music_icon.texture = music_on_tex if gm.music_on else music_off_tex
			music_icon.modulate = Color(1, 1, 1, 1) if gm.music_on else Color(0.7, 0.7, 0.7, 0.5)
		
		# Also update legacy child nodes if they exist
		var sound_on = get_node_or_null("GameUI/TopBar/btnSound/on")
		if sound_on: sound_on.visible = gm.sfx_on
		var sound_mute = get_node_or_null("GameUI/TopBar/btnSound/mute")
		if sound_mute: sound_mute.visible = !gm.sfx_on
		var music_mute = get_node_or_null("GameUI/TopBar/btnMusic/mute")
		if music_mute: music_mute.visible = !gm.music_on


func check_boss_status() -> void:
	if boss_panel == null:
		return
	if current_boss == null or not is_instance_valid(current_boss):
		var boss_nodes = get_tree().get_nodes_in_group("Boss")
		if boss_nodes.size() > 0:
			setup_boss(boss_nodes[0])
		else:
			boss_panel.visible = false


func setup_boss(boss_node: Node2D) -> void:
	current_boss = boss_node
	boss_panel.visible = true
	if boss_node.has_signal("hp_changed"):
		if not boss_node.hp_changed.is_connected(_on_boss_hp_changed):
			boss_node.hp_changed.connect(_on_boss_hp_changed)
	if "hp" in boss_node and "max_hp" in boss_node:
		_on_boss_hp_changed(boss_node.hp, boss_node.max_hp)


func _on_boss_hp_changed(c_hp: float, m_hp: float) -> void:
	if boss_bar and m_hp > 0:
		boss_bar.value = (c_hp / m_hp) * 100.0


func alert(text: String) -> void:
	if alert_label == null:
		alert_label = %AlertLabel if has_node("%AlertLabel") else null
	if alert_label:
		alert_label.text = str(text)
		alert_label.visible = true
		alert_label.scale = Vector2.ZERO
		var tween = create_tween()
		tween.tween_property(alert_label, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		await get_tree().create_timer(2.2).timeout
		if is_instance_valid(alert_label):
			alert_label.visible = false


func _on_btn_sound_pressed() -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.sfx_on = !gm.sfx_on
		gm.update_option()
		gm.save_option()
		update_audio_icons()


func _on_btn_music_pressed() -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.music_on = !gm.music_on
		gm.update_option()
		gm.save_option()
		update_audio_icons()


func _on_btn_pause_pressed() -> void:
	if pause_menu and pause_menu.has_method("open_pause_menu"):
		pause_menu.open_pause_menu()


func _on_btn_save_pressed() -> void:
	# Save button is removed from UI per user request; kept as no-op stub for safety
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.save_game()


# On-screen touch action buttons
func _on_btn_left_pressed() -> void:
	Input.action_press("Left")

func _on_btn_left_released() -> void:
	Input.action_release("Left")

func _on_btn_up_pressed() -> void:
	Input.action_press("Jump")

func _on_btn_up_released() -> void:
	Input.action_release("Jump")

func _on_btn_right_pressed() -> void:
	Input.action_press("Right")

func _on_btn_right_released() -> void:
	Input.action_release("Right")

func _on_btn_shoot_button_down() -> void:
	Input.action_press("Shoot")

func _on_btn_shoot_button_up() -> void:
	Input.action_release("Shoot")

func _on_btn_dash_button_down() -> void:
	Input.action_press("Dash")

func _on_btn_dash_button_up() -> void:
	Input.action_release("Dash")

func _on_btn_element_pressed() -> void:
	Input.action_press("SwitchElement")
	Input.action_release("SwitchElement")

func _on_btn_special_pressed() -> void:
	Input.action_press("Special")
	Input.action_release("Special")

func _on_btn_interact_pressed() -> void:
	Input.action_press("Interact")
	Input.action_release("Interact")

func _on_btn_shop_pressed() -> void:
	toggle_shop()


# --------- SKILL BUTTON PER-CHARACTER ---------- #

func update_skill_button_for_character() -> void:
	var gm = get_node_or_null("/root/GameManager")
	var cid: String = gm.selected_character_id if gm and "selected_character_id" in gm else "knight"
	_last_cid = cid
	
	if not btn_skill:
		return
	
	# Cấu hình skill riêng biệt cho mỗi nhân vật
	var skill_name: String = ""
	var skill_text: String = ""
	var border_color: Color = Color(0.85, 0.45, 1.0, 0.95)
	var bg_color: Color = Color(0.12, 0.04, 0.18, 0.88)
	var bg_pressed: Color = Color(0.75, 0.35, 0.95, 0.95)
	var font_color: Color = Color(1, 0.9, 0.45, 1)
	
	match cid:
		"knight":
			skill_text = "⚔️"
			skill_name = "Xoay Thương"
			border_color = Color(1.0, 0.75, 0.15, 0.95)  # Vàng hoàng kim
			bg_color = Color(0.16, 0.10, 0.02, 0.88)
			bg_pressed = Color(0.95, 0.68, 0.1, 0.95)
			font_color = Color(1.0, 0.88, 0.3, 1.0)
		"mage":
			skill_text = "🔮"
			skill_name = "Cầu Ma Thuật"
			border_color = Color(0.6, 0.3, 1.0, 0.95)  # Tím arcane
			bg_color = Color(0.08, 0.02, 0.18, 0.88)
			bg_pressed = Color(0.65, 0.25, 0.95, 0.95)
			font_color = Color(0.85, 0.65, 1.0, 1.0)
		"archer":
			skill_text = "🏹"
			skill_name = "Mưa Tên"
			border_color = Color(0.2, 0.9, 0.5, 0.95)  # Xanh lá rừng
			bg_color = Color(0.02, 0.12, 0.06, 0.88)
			bg_pressed = Color(0.15, 0.82, 0.45, 0.95)
			font_color = Color(0.6, 1.0, 0.7, 1.0)
	
	# Cập nhật text chính trên nút
	btn_skill.text = skill_text
	btn_skill.add_theme_color_override("font_color", font_color)
	
	# Cập nhật label phụ hiển thị tên skill
	if skill_label:
		skill_label.text = skill_name
		skill_label.add_theme_color_override("font_color", font_color)
	
	# Cập nhật style (tạo StyleBoxFlat mới cho nút)
	var style_normal := StyleBoxFlat.new()
	style_normal.bg_color = bg_color
	style_normal.border_color = border_color
	style_normal.set_border_width_all(3)
	style_normal.set_corner_radius_all(40)
	btn_skill.add_theme_stylebox_override("normal", style_normal)
	btn_skill.add_theme_stylebox_override("hover", style_normal)
	
	var style_pressed := StyleBoxFlat.new()
	style_pressed.bg_color = bg_pressed
	style_pressed.border_color = Color(1.0, 1.0, 1.0, 1.0)
	style_pressed.set_border_width_all(3)
	style_pressed.set_corner_radius_all(40)
	btn_skill.add_theme_stylebox_override("pressed", style_pressed)


func update_skill_cooldown() -> void:
	if not btn_skill:
		return
	
	# Tìm player để lấy thời gian cooldown
	var player: Node = null
	if is_inside_tree() and get_tree():
		var players = get_tree().get_nodes_in_group("Player")
		if players.size() > 0:
			player = players[0]
	
	var on_cooldown: bool = false
	var cooldown_remaining: float = 0.0
	var cooldown_max: float = 1.0
	
	if player and "special_cooldown_timer" in player:
		cooldown_remaining = player.special_cooldown_timer
		on_cooldown = cooldown_remaining > 0.0
		
		# Lấy cooldown tối đa theo class
		var gm = get_node_or_null("/root/GameManager")
		var cid: String = gm.selected_character_id if gm and "selected_character_id" in gm else "knight"
		match cid:
			"knight": cooldown_max = 2.5
			"mage": cooldown_max = 3.0
			"archer": cooldown_max = 2.2
	
	# Hiển thị overlay cooldown
	if cooldown_overlay:
		if on_cooldown:
			cooldown_overlay.visible = true
			# Thay đổi độ mờ theo thời gian cooldown còn lại
			var ratio: float = clampf(cooldown_remaining / cooldown_max, 0.0, 1.0)
			cooldown_overlay.color = Color(0, 0, 0, 0.55 * ratio)
			
			# Hiển thị số giây còn lại trên nút
			btn_skill.text = "%.1f" % cooldown_remaining
		else:
			cooldown_overlay.visible = false
			# Khôi phục text gốc theo nhân vật
			var gm2 = get_node_or_null("/root/GameManager")
			var cid2: String = gm2.selected_character_id if gm2 and "selected_character_id" in gm2 else "knight"
			match cid2:
				"knight": btn_skill.text = "⚔️"
				"mage": btn_skill.text = "✦"
				"archer": btn_skill.text = "🏹"
				_: btn_skill.text = "SKILL"
