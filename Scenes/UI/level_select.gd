class_name LevelSelect
extends Control

const STAR_GOLD := preload("res://Assets/UI/star_gold.png")
const STAR_GRAY := preload("res://Assets/UI/star_gray.png")

const LEVEL_DATA: Array[Dictionary] = [
	{
		"index": 1,
		"key": "level_01",
		"name": "TẦNG 01",
		"sub": "Cổng Hầm Ngục",
		"scene": "res://Scenes/Levels/level_01.tscn"
	},
	{
		"index": 2,
		"key": "level_02",
		"name": "TẦNG 02",
		"sub": "Rừng Nấm Độc",
		"scene": "res://Scenes/Levels/level_02.tscn"
	},
	{
		"index": 3,
		"key": "level_03",
		"name": "TẦNG 03",
		"sub": "Vực Thẳm Lưỡi Cưa",
		"scene": "res://Scenes/Levels/level_03.tscn"
	},
	{
		"index": 4,
		"key": "level_04",
		"name": "TẦNG 04",
		"sub": "Động Troll Chúa",
		"scene": "res://Scenes/Levels/level_04.tscn"
	},
	{
		"index": 5,
		"key": "level_05",
		"name": "TẦNG 05",
		"sub": "Sào Huyệt Abyss",
		"scene": "res://Scenes/Levels/level_05.tscn"
	}
]

@onready var total_stars_label: Label = %TotalStarsLabel if has_node("%TotalStarsLabel") else null
@onready var btn_back: Button = %BtnBack if has_node("%BtnBack") else null
@onready var btn_reset: Button = %BtnReset if has_node("%BtnReset") else null
@onready var confirm_dialog: ConfirmationDialog = %ConfirmDialog if has_node("%ConfirmDialog") else null

func _ready() -> void:
	if btn_back:
		btn_back.pressed.connect(_on_back_pressed)
	if btn_reset:
		btn_reset.pressed.connect(_on_btn_reset_pressed)
	if confirm_dialog:
		confirm_dialog.confirmed.connect(_on_confirm_reset)
	
	_setup_level_cards()
	_update_total_stars()

func _setup_level_cards() -> void:
	var gm = get_node_or_null("/root/GameManager")
	
	for i in range(LEVEL_DATA.size()):
		var data: Dictionary = LEVEL_DATA[i]
		var card: PanelContainer = find_child("CardLevel%d" % data["index"], true, false)
		if card == null:
			continue
			
		var is_unlocked: bool = true
		if gm and gm.has_method("is_level_unlocked"):
			is_unlocked = gm.is_level_unlocked(data["index"])
		elif data["index"] > 1:
			is_unlocked = false
			
		var stars_count: int = 0
		if gm and "level_stars" in gm and gm.level_stars.has(data["key"]):
			stars_count = int(gm.level_stars[data["key"]])
			
		_configure_card(card, data, is_unlocked, stars_count)

func _configure_card(card: PanelContainer, data: Dictionary, is_unlocked: bool, stars_count: int) -> void:
	card.pivot_offset = card.custom_minimum_size / 2.0
	
	# Connect card hover animation
	card.mouse_entered.connect(func():
		if is_unlocked:
			card.pivot_offset = card.custom_minimum_size / 2.0
			var tw = card.create_tween()
			tw.tween_property(card, "scale", Vector2(1.05, 1.05), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	)
	card.mouse_exited.connect(func():
		card.pivot_offset = card.custom_minimum_size / 2.0
		var tw = card.create_tween()
		tw.tween_property(card, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	)
	
	# Allow clicking anywhere on an unlocked card to enter
	card.gui_input.connect(func(event: InputEvent):
		if is_unlocked and event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
				_on_select_level(data["scene"])
	)

	var title_lbl: Label = card.get_node_or_null("VBox/TitleLabel")
	var sub_lbl: Label = card.get_node_or_null("VBox/SubLabel")
	var status_lbl: Label = card.get_node_or_null("VBox/StatusLabel")
	var btn_play: Button = card.get_node_or_null("VBox/BtnPlay")
	var stars_box: HBoxContainer = card.get_node_or_null("VBox/StarsBox")
	
	if title_lbl: title_lbl.text = data["name"]
	if sub_lbl: sub_lbl.text = data["sub"]
	
	if is_unlocked:
		card.modulate = Color(1.0, 1.0, 1.0, 1.0)
		if status_lbl:
			status_lbl.text = "⭐ %d / 3 SAO" % stars_count
			status_lbl.modulate = Color(1.0, 0.9, 0.3)
		if btn_play:
			btn_play.disabled = false
			btn_play.text = "Vào Chơi"
			btn_play.pressed.connect(func(): _on_select_level(data["scene"]))
		if stars_box:
			stars_box.visible = true
			_render_stars(stars_box, stars_count)
	else:
		card.modulate = Color(0.55, 0.55, 0.6, 0.75)
		if status_lbl:
			status_lbl.text = "🔒 CHƯA MỞ"
			status_lbl.modulate = Color(0.7, 0.7, 0.7)
		if btn_play:
			btn_play.disabled = true
			btn_play.text = "🔒 Khóa"
		if stars_box:
			_render_stars(stars_box, 0)

func _render_stars(box: HBoxContainer, stars: int) -> void:
	var star1: TextureRect = box.get_node_or_null("Star1")
	var star2: TextureRect = box.get_node_or_null("Star2")
	var star3: TextureRect = box.get_node_or_null("Star3")
	
	if star1: star1.texture = STAR_GOLD if stars >= 1 else STAR_GRAY
	if star2: star2.texture = STAR_GOLD if stars >= 2 else STAR_GRAY
	if star3: star3.texture = STAR_GOLD if stars >= 3 else STAR_GRAY

func _update_total_stars() -> void:
	if total_stars_label:
		var gm = get_node_or_null("/root/GameManager")
		var total := 0
		if gm and gm.has_method("get_total_stars"):
			total = gm.get_total_stars()
		total_stars_label.text = "⭐ TỔNG SAO: %d / 15" % total

func _on_select_level(scene_path: String) -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.selected_level_to_play = scene_path
	# Navigate to character select so player can choose class for this level
	if ResourceLoader.exists("res://Scenes/UI/character_select.tscn"):
		get_tree().change_scene_to_file("res://Scenes/UI/character_select.tscn")
	else:
		get_tree().change_scene_to_file(scene_path)

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/Levels/menu.tscn")

func _on_btn_reset_pressed() -> void:
	if confirm_dialog:
		confirm_dialog.popup_centered()
	else:
		_on_confirm_reset()

func _on_confirm_reset() -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.has_method("reset_all_save_data"):
		gm.reset_all_save_data()
	_setup_level_cards()
	_update_total_stars()
