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

# --- 1 Skill Button Duy Nhất ---
@onready var btn_skill: Button = get_node_or_null("GameUI/BottomControls/btnSkill")
@onready var skill_label: Label = %SkillLabel if has_node("%SkillLabel") else null
@onready var cooldown_overlay: ColorRect = %CooldownOverlay if has_node("%CooldownOverlay") else null

# --- Nút Đổi Cách Tấn Công (Element Switch) ---
@onready var btn_element: Button = get_node_or_null("GameUI/BottomControls/btnElement")
@onready var element_icon: TextureRect = get_node_or_null("GameUI/BottomControls/btnElement/Icon")
@onready var element_label: Label = %ElementLabel if has_node("%ElementLabel") else null

var current_boss: Node2D = null
var _last_cid: String = ""
var _last_element: int = -1

# Preloaded audio icon textures for fast switching
var sound_on_tex: Texture2D
var sound_off_tex: Texture2D
var music_on_tex: Texture2D
var music_off_tex: Texture2D


# Cấu hình 1 kỹ năng chủ động duy nhất cho từng nhân vật
const SKILL_CONFIG := {
	"knight": {
		"emoji": "⚔️", "name": "Xoay Thương", "cooldown": 2.5,
		"border": Color(1.0, 0.75, 0.15, 0.95), "bg": Color(0.16, 0.10, 0.02, 0.88),
		"pressed": Color(0.95, 0.68, 0.1, 0.95), "font": Color(1.0, 0.88, 0.3, 1.0)
	},
	"mage": {
		"emoji": "🔮", "name": "Cầu Ma Thuật", "cooldown": 3.5,
		"border": Color(0.85, 0.4, 1.0, 0.95), "bg": Color(0.12, 0.03, 0.16, 0.88),
		"pressed": Color(0.8, 0.35, 0.95, 0.95), "font": Color(0.9, 0.7, 1.0, 1.0)
	},
	"archer": {
		"emoji": "🏹", "name": "Mưa Tên", "cooldown": 3.0,
		"border": Color(0.3, 0.9, 0.45, 0.95), "bg": Color(0.03, 0.14, 0.06, 0.88),
		"pressed": Color(0.25, 0.85, 0.4, 0.95), "font": Color(0.6, 1.0, 0.7, 1.0)
	}
}

# Cấu hình 3 cách tấn công riêng biệt theo đặc tính của từng nhân vật
const ELEMENT_CONFIG := {
	"knight": [
		{ "name": "⚔️ LONG ĐỘT", "color": Color(1.0, 0.9, 0.3, 1.0), "border": Color(1.0, 0.85, 0.2, 0.95), "bg": Color(0.24, 0.18, 0.02, 0.92) },
		{ "name": "🔥 BẠO VIÊM", "color": Color(1.0, 0.45, 0.15, 1.0), "border": Color(1.0, 0.35, 0.1, 0.95), "bg": Color(0.24, 0.05, 0.02, 0.92) },
		{ "name": "🛡️ TRẤN THIÊN", "color": Color(0.9, 0.75, 0.4, 1.0), "border": Color(0.85, 0.65, 0.3, 0.95), "bg": Color(0.18, 0.12, 0.04, 0.92) },
	],
	"mage": [
		{ "name": "🌌 TINH VÂN", "color": Color(0.9, 0.65, 1.0, 1.0), "border": Color(0.85, 0.5, 1.0, 0.95), "bg": Color(0.18, 0.04, 0.24, 0.92) },
		{ "name": "⚡ LÔI VÂN", "color": Color(0.4, 1.0, 0.7, 1.0), "border": Color(0.3, 0.95, 0.6, 0.95), "bg": Color(0.02, 0.18, 0.12, 0.92) },
		{ "name": "🌑 HƯ KHÔNG", "color": Color(0.7, 0.4, 0.9, 1.0), "border": Color(0.55, 0.25, 0.8, 0.95), "bg": Color(0.10, 0.02, 0.16, 0.92) },
	],
	"archer": [
		{ "name": "🍃 PHONG LINH", "color": Color(0.6, 1.0, 0.7, 1.0), "border": Color(0.4, 0.95, 0.5, 0.95), "bg": Color(0.03, 0.18, 0.08, 0.92) },
		{ "name": "💥 PHÁO KÍCH", "color": Color(1.0, 0.5, 0.15, 1.0), "border": Color(1.0, 0.4, 0.1, 0.95), "bg": Color(0.24, 0.06, 0.02, 0.92) },
		{ "name": "🌿 ĐỘC XÀ", "color": Color(0.4, 1.0, 0.5, 1.0), "border": Color(0.3, 0.9, 0.4, 0.95), "bg": Color(0.02, 0.16, 0.06, 0.92) },
	]
}


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
		
	if pause_menu and pause_menu.has_signal("pause_toggled"):
		if not pause_menu.pause_toggled.is_connected(_on_pause_toggled):
			pause_menu.pause_toggled.connect(_on_pause_toggled)
		
	update_audio_icons()
	update_skill_button()
	update_element_button_style()


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
			life_rect.size.x = 48.0 * float(gm.life)
		
		update_audio_icons()
	
	check_boss_status()
	update_skill_cooldown()
	
	# Cập nhật khi nhân vật thay đổi
	var gm2 = get_node_or_null("/root/GameManager")
	var cid: String = gm2.selected_character_id if gm2 and "selected_character_id" in gm2 else "knight"
	if cid != _last_cid:
		_last_cid = cid
		update_skill_button()
		update_element_button_style()
		
	# Theo dõi chế độ tấn công của player để cập nhật nút Element
	var player = _get_player()
	if player and "current_element" in player:
		var cur_e: int = player.get("current_element")
		if cur_e != _last_element:
			_last_element = cur_e
			update_element_button_style()
			if element_icon:
				element_icon.pivot_offset = element_icon.size / 2.0
				var r_tw := element_icon.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				r_tw.tween_property(element_icon, "rotation", element_icon.rotation + 2.0944, 0.22)


func _get_player() -> Node:
	if is_inside_tree() and get_tree():
		var players = get_tree().get_nodes_in_group("Player")
		if players.size() > 0:
			return players[0]
	return null


func update_audio_icons() -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		if sound_icon:
			sound_icon.texture = sound_on_tex if gm.sfx_on else sound_off_tex
			sound_icon.modulate = Color(1, 1, 1, 1) if gm.sfx_on else Color(0.7, 0.7, 0.7, 0.5)
		if music_icon:
			music_icon.texture = music_on_tex if gm.music_on else music_off_tex
			music_icon.modulate = Color(1, 1, 1, 1) if gm.music_on else Color(0.7, 0.7, 0.7, 0.5)
		
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
		boss_bar.max_value = m_hp
		boss_bar.value = c_hp


func alert(text: String) -> void:
	if alert_label:
		alert_label.text = text
		alert_label.visible = true
		var tween = create_tween()
		tween.tween_property(alert_label, "modulate:a", 1.0, 0.15)
		tween.tween_interval(1.8)
		tween.tween_property(alert_label, "modulate:a", 0.0, 0.35)
		tween.tween_callback(alert_label.hide)


# --------- BUTTON INPUT EVENT HANDLERS ---------- #

func _on_pause_toggled(is_paused: bool) -> void:
	var bottom_controls = get_node_or_null("GameUI/BottomControls")
	if bottom_controls:
		bottom_controls.visible = not is_paused
	var top_right = get_node_or_null("GameUI/TopBar/TopRightWidget")
	if top_right:
		top_right.visible = not is_paused


func _on_btn_pause_pressed() -> void:
	if pause_menu:
		if pause_menu.has_method("open_pause_menu"):
			pause_menu.open_pause_menu()
		else:
			pause_menu.visible = true
			get_tree().paused = true


func _on_btn_sound_pressed() -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.sfx_on = !gm.sfx_on
		update_audio_icons()


func _on_btn_music_pressed() -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.music_on = !gm.music_on
		update_audio_icons()
		var am = get_node_or_null("/root/AudioManager")
		if am and am.has_method("toggle_music"):
			am.toggle_music(gm.music_on)


func _on_btn_left_pressed() -> void:
	Input.action_press("Left")

func _on_btn_left_released() -> void:
	Input.action_release("Left")

func _on_btn_up_pressed() -> void:
	Input.action_press("Jump")
	Input.action_press("Up")
	
	# Hiệu ứng nảy nút khi bấm nút nhảy
	var btn_up = get_node_or_null("GameUI/BottomControls/btnUp")
	if btn_up:
		btn_up.pivot_offset = btn_up.size / 2.0
		var tw := btn_up.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(btn_up, "scale", Vector2(1.15, 1.15), 0.06)
		tw.tween_property(btn_up, "scale", Vector2(1.0, 1.0), 0.12)

func _on_btn_up_released() -> void:
	Input.action_release("Jump")
	Input.action_release("Up")

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
	
	# Chỉ xoay icon 3 chấm màu ở giữa nút, giữ chữ và khung nút luôn thẳng đứng!
	if element_icon:
		element_icon.pivot_offset = element_icon.size / 2.0
		var r_tw := element_icon.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		r_tw.tween_property(element_icon, "rotation", element_icon.rotation + 2.0944, 0.22)
		
	if btn_element:
		btn_element.rotation = 0.0 # Luôn giữ nút và nhãn chữ thẳng đứng
		var s_tw := btn_element.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		s_tw.tween_property(btn_element, "scale", Vector2(1.15, 1.15), 0.06)
		s_tw.tween_property(btn_element, "scale", Vector2(1.0, 1.0), 0.12)

func _on_btn_special_pressed() -> void:
	Input.action_press("Special")
	Input.action_release("Special")
	
	if btn_skill:
		var tw := btn_skill.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(btn_skill, "scale", Vector2(1.15, 1.15), 0.06)
		tw.tween_property(btn_skill, "scale", Vector2(1.0, 1.0), 0.12)

func _on_btn_interact_pressed() -> void:
	Input.action_press("Interact")
	Input.action_release("Interact")

func _on_btn_shop_pressed() -> void:
	toggle_shop()


# --------- NÚT ĐỔI CÁCH TẤN CÔNG (ELEMENT BUTTON) ---------- #

func update_element_button_style() -> void:
	if not btn_element:
		return
	btn_element.rotation = 0.0 # Khung nút và nhãn chữ luôn cố định thẳng đứng
		
	var gm = get_node_or_null("/root/GameManager")
	var cid: String = gm.selected_character_id if gm and "selected_character_id" in gm else "knight"
	var elems: Array = ELEMENT_CONFIG.get(cid, ELEMENT_CONFIG["knight"])
	
	var player = _get_player()
	var current_idx: int = player.get("current_element") if (player and "current_element" in player) else 0
	current_idx = clampi(current_idx, 0, elems.size() - 1)
	
	var elem_cfg: Dictionary = elems[current_idx]
	
	# Cập nhật nhãn bên dưới nút
	if element_label:
		element_label.text = elem_cfg.get("name", "Hoàng Kim")
		element_label.add_theme_color_override("font_color", elem_cfg.get("color", Color.WHITE))
	
	# Đổi viền và màu nền nút theo hệ đang chọn
	var style_normal := StyleBoxFlat.new()
	style_normal.bg_color = elem_cfg.get("bg", Color(0.18, 0.14, 0.02, 0.88))
	style_normal.border_color = elem_cfg.get("border", Color(1.0, 0.8, 0.2, 0.95))
	style_normal.set_border_width_all(3)
	style_normal.set_corner_radius_all(36)
	btn_element.add_theme_stylebox_override("normal", style_normal)
	btn_element.add_theme_stylebox_override("hover", style_normal)
	
	var style_pressed := StyleBoxFlat.new()
	style_pressed.bg_color = elem_cfg.get("border", Color(1.0, 0.8, 0.2, 0.95))
	style_pressed.border_color = Color.WHITE
	style_pressed.set_border_width_all(3)
	style_pressed.set_corner_radius_all(36)
	btn_element.add_theme_stylebox_override("pressed", style_pressed)


# --------- NÚT SKILL DUY NHẤT ---------- #

func update_skill_button() -> void:
	if not btn_skill:
		return
		
	var gm = get_node_or_null("/root/GameManager")
	var cid: String = gm.selected_character_id if gm and "selected_character_id" in gm else "knight"
	var cfg: Dictionary = SKILL_CONFIG.get(cid, SKILL_CONFIG["knight"])
	
	btn_skill.text = cfg.get("emoji", "⚔️")
	btn_skill.add_theme_color_override("font_color", cfg.get("font", Color.WHITE))
	
	if skill_label:
		skill_label.text = cfg.get("name", "Skill")
		skill_label.add_theme_color_override("font_color", cfg.get("font", Color.WHITE))
	
	var style_normal := StyleBoxFlat.new()
	style_normal.bg_color = cfg.get("bg", Color(0.16, 0.10, 0.02, 0.88))
	style_normal.border_color = cfg.get("border", Color(1.0, 0.75, 0.15, 0.95))
	style_normal.set_border_width_all(3)
	style_normal.set_corner_radius_all(40)
	btn_skill.add_theme_stylebox_override("normal", style_normal)
	btn_skill.add_theme_stylebox_override("hover", style_normal)
	
	var style_pressed := StyleBoxFlat.new()
	style_pressed.bg_color = cfg.get("pressed", Color(0.95, 0.68, 0.1, 0.95))
	style_pressed.border_color = Color.WHITE
	style_pressed.set_border_width_all(3)
	style_pressed.set_corner_radius_all(40)
	btn_skill.add_theme_stylebox_override("pressed", style_pressed)


func update_skill_cooldown() -> void:
	if not btn_skill:
		return
		
	var player = _get_player()
	var cd_remaining: float = 0.0
	var on_cd: bool = false
	
	if player and "special_cooldown_timer" in player:
		cd_remaining = player.get("special_cooldown_timer")
		on_cd = cd_remaining > 0.0
		
	var gm = get_node_or_null("/root/GameManager")
	var cid: String = gm.selected_character_id if gm and "selected_character_id" in gm else "knight"
	var cfg: Dictionary = SKILL_CONFIG.get(cid, SKILL_CONFIG["knight"])
	var cd_max: float = cfg.get("cooldown", 2.5)
	
	if cooldown_overlay:
		if on_cd:
			cooldown_overlay.visible = true
			var ratio: float = clampf(cd_remaining / cd_max, 0.0, 1.0)
			cooldown_overlay.color = Color(0, 0, 0, 0.55 * ratio)
			btn_skill.text = "%.1f" % cd_remaining
		else:
			cooldown_overlay.visible = false
			btn_skill.text = cfg.get("emoji", "⚔️")
