class_name ShopMenu
extends Control

signal shop_closed

@onready var coin_label: Label = $Panel/CoinLabel if has_node("Panel/CoinLabel") else null
@onready var status_label: Label = $Panel/StatusLabel if has_node("Panel/StatusLabel") else null

# Buttons
@onready var btn_heal: Button = %BtnHeal if has_node("%BtnHeal") else null
@onready var btn_max_hp: Button = %BtnMaxHp if has_node("%BtnMaxHp") else null
@onready var btn_speed: Button = %BtnSpeed if has_node("%BtnSpeed") else null
@onready var btn_life: Button = %BtnLife if has_node("%BtnLife") else null
@onready var btn_close: Button = %BtnClose if has_node("%BtnClose") else null
@onready var btn_top_close: Button = $Panel/BtnTopClose if has_node("Panel/BtnTopClose") else null

func _ready() -> void:
	visible = false
	update_ui()
	
	if btn_close:
		btn_close.pressed.connect(close_shop)
	if btn_top_close:
		btn_top_close.pressed.connect(close_shop)
	if btn_heal:
		btn_heal.pressed.connect(_on_btn_heal_pressed)
	if btn_max_hp:
		btn_max_hp.pressed.connect(_on_btn_max_hp_pressed)
	if btn_speed:
		btn_speed.pressed.connect(_on_btn_speed_pressed)
	if btn_life:
		btn_life.pressed.connect(_on_btn_life_pressed)

func open_shop() -> void:
	visible = true
	get_tree().paused = true
	update_ui()
	show_status("Chào mừng đến Cửa Hàng Dũng Sĩ!")

func close_shop() -> void:
	visible = false
	get_tree().paused = false
	shop_closed.emit()

func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close_shop()
		get_viewport().set_input_as_handled()

func update_ui() -> void:
	var gm = get_node_or_null("/root/GameManager")
	var current_score = gm.score if gm else 0
	if coin_label:
		coin_label.text = "Xu Hiện Có: 🪙 %d" % current_score

func show_status(text: String, is_error: bool = false) -> void:
	if status_label:
		status_label.text = text
		if is_error:
			status_label.modulate = Color(1.0, 0.4, 0.4, 1.0)
		else:
			status_label.modulate = Color(0.4, 1.0, 0.4, 1.0)

func play_buy_sfx() -> void:
	var am = get_node_or_null("/root/AudioManager")
	if am and "coin_sfx" in am and am.coin_sfx:
		am.coin_sfx.play()

func _on_btn_heal_pressed() -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm == null:
		return
	var cost = 5
	if gm.score >= cost:
		if gm.hp >= gm.max_hp:
			show_status("Máu đã đầy!", true)
			return
		gm.score -= cost
		gm.add_hp(30)
		play_buy_sfx()
		show_status("Đã hồi +30 HP!")
		update_ui()
	else:
		show_status("Không đủ xu! Cần %d xu." % cost, true)

func _on_btn_max_hp_pressed() -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm == null:
		return
	var cost = 15
	if gm.score >= cost:
		gm.score -= cost
		gm.max_hp += 20
		gm.add_hp(20)
		play_buy_sfx()
		show_status("Đã tăng Máu Tối Đa (+20 HP)!")
		update_ui()
	else:
		show_status("Không đủ xu! Cần %d xu." % cost, true)

func _on_btn_speed_pressed() -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm == null:
		return
	var cost = 20
	if gm.score >= cost:
		gm.score -= cost
		if "spear_wave_speed_mult" in gm:
			gm.spear_wave_speed_mult += 0.2
		else:
			gm.set("spear_wave_speed_mult", 1.2)
		play_buy_sfx()
		show_status("Đã tăng +20% Tốc độ Đạn / Sóng thương!")
		update_ui()
	else:
		show_status("Không đủ xu! Cần %d xu." % cost, true)

func _on_btn_life_pressed() -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm == null:
		return
	var cost = 25
	if gm.score >= cost:
		if gm.life >= gm.max_life:
			show_status("Mạng đã đạt tối đa (%d)!" % gm.max_life, true)
			return
		gm.score -= cost
		gm.add_life()
		play_buy_sfx()
		show_status("Đã tăng thêm 1 Mạng dự phòng!")
		update_ui()
	else:
		show_status("Không đủ xu! Cần %d xu." % cost, true)
