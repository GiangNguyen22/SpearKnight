extends CanvasLayer

@onready var score_label: Label = %ScoreLabel if has_node("%ScoreLabel") else null
@onready var key_label: Label = %KeyLabel if has_node("%KeyLabel") else null
@onready var hp_bar: ProgressBar = %ProgressBar if has_node("%ProgressBar") else null
@onready var hp_label: Label = %HPLabel if has_node("%HPLabel") else null
@onready var max_hp_label: Label = %MaxHPLabel if has_node("%MaxHPLabel") else null
@onready var life_rect: TextureRect = %LifeRect if has_node("%LifeRect") else null

@onready var btn_sound: Button = %BtnSound if has_node("%BtnSound") else null
@onready var btn_music: Button = %BtnMusic if has_node("%BtnMusic") else null
@onready var btn_pause: Button = %BtnPause if has_node("%BtnPause") else null
@onready var sound_icon: TextureRect = %SoundIcon if has_node("%SoundIcon") else null
@onready var music_icon: TextureRect = %MusicIcon if has_node("%MusicIcon") else null

@onready var boss_panel: Control = %BossBarPanel if has_node("%BossBarPanel") else null
@onready var boss_bar: ProgressBar = %BossProgressBar if has_node("%BossProgressBar") else null

@onready var alert_label: Label = %AlertLabel if has_node("%AlertLabel") else null
@onready var shop_menu: Control = $ShopMenu if has_node("ShopMenu") else null
@onready var pause_menu: Control = $PauseMenu if has_node("PauseMenu") else null

var current_boss: Node2D = null

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
	
	if btn_pause:
		btn_pause.pressed.connect(_on_btn_pause_pressed)
	if btn_sound:
		btn_sound.pressed.connect(_on_btn_sound_pressed)
	if btn_music:
		btn_music.pressed.connect(_on_btn_music_pressed)
		
	update_audio_icons()


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


func update_audio_icons() -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		if sound_icon:
			sound_icon.texture = sound_on_tex if gm.sfx_on else sound_off_tex
		if music_icon:
			music_icon.texture = music_on_tex if gm.music_on else music_off_tex
		
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

func _on_btn_interact_pressed() -> void:
	Input.action_press("Interact")
	Input.action_release("Interact")

func _on_btn_shop_pressed() -> void:
	toggle_shop()
