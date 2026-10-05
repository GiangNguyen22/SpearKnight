class_name CharacterSelect
extends Control

@onready var card_knight: PanelContainer = $Control/Margin/VBox/CardsContainer/CardKnight if has_node("Control/Margin/VBox/CardsContainer/CardKnight") else null
@onready var card_mage: PanelContainer = $Control/Margin/VBox/CardsContainer/CardMage if has_node("Control/Margin/VBox/CardsContainer/CardMage") else null
@onready var card_archer: PanelContainer = $Control/Margin/VBox/CardsContainer/CardArcher if has_node("Control/Margin/VBox/CardsContainer/CardArcher") else null

@onready var btn_knight: Button = %BtnKnight if has_node("%BtnKnight") else null
@onready var btn_mage: Button = %BtnMage if has_node("%BtnMage") else null
@onready var btn_archer: Button = %BtnArcher if has_node("%BtnArcher") else null

@onready var btn_start: Button = %BtnStart if has_node("%BtnStart") else null
@onready var btn_back: Button = %BtnBack if has_node("%BtnBack") else null

@onready var desc_label: RichTextLabel = %DescLabel if has_node("%DescLabel") else null

var selected_class: String = "knight"

var class_descriptions: Dictionary = {
	"knight": "[b][color=#ffd700]⚔️ HIỆP SĨ THIẾT GIÁP (KNIGHT)[/color][/b]\n[color=#e0e0e0]• Sinh Mệnh: 100 HP  |  Tốc Độ: 200 px/s[/color]\n[color=#87cefa]• Vũ khí: Ngọn Thương Thần (Sóng Thương Nguyên Tố Lửa/Băng)[/color]\n[color=#cccccc]• Đặc trưng: Phòng thủ vững chắc, khả năng Lướt bóng ma (Dash) và Nảy Tường (Wall Jump) cân bằng.[/color]",
	"mage": "[b][color=#ba55d3]🔮 PHÙ THỦY HẦM NGỤC (SORCERESS)[/color][/b]\n[color=#e0e0e0]• Sinh Mệnh: 80 HP  |  Tốc Độ: 190 px/s[/color]\n[color=#ff7f50]• Vũ khí: Gậy Phép Ma Thuật (Cầu Lửa Nổ Diện Rộng AOE)[/color]\n[color=#cccccc]• Đặc trưng: Sát thương phép thuật bùng nổ, tạo vụ nổ lan 40px quét sạch bầy quái.[/color]",
	"archer": "[b][color=#3cb371]🏹 CUNG THỦ TRINH SÁT (RANGER)[/color][/b]\n[color=#e0e0e0]• Sinh Mệnh: 90 HP  |  Tốc Độ: 230 px/s (+15% Thần Tốc)[/color]\n[color=#adff2f]• Vũ khí: Cung Tên Thần Tốc (Bắn Xuyên 2 Kẻ Địch)[/color]\n[color=#cccccc]• Đặc trưng: Nhanh nhẹn nhất hầm ngục, mũi tên xé gió xuyên qua nhiều mục tiêu cùng lúc.[/color]"
}


func _ensure_nodes() -> void:
	if card_knight == null: card_knight = get_node_or_null("Control/Margin/VBox/CardsContainer/CardKnight")
	if card_mage == null: card_mage = get_node_or_null("Control/Margin/VBox/CardsContainer/CardMage")
	if card_archer == null: card_archer = get_node_or_null("Control/Margin/VBox/CardsContainer/CardArcher")

	if btn_knight == null: btn_knight = get_node_or_null("Control/Margin/VBox/CardsContainer/CardKnight/VBox/BtnKnight")
	if btn_mage == null: btn_mage = get_node_or_null("Control/Margin/VBox/CardsContainer/CardMage/VBox/BtnMage")
	if btn_archer == null: btn_archer = get_node_or_null("Control/Margin/VBox/CardsContainer/CardArcher/VBox/BtnArcher")

	if btn_start == null: btn_start = get_node_or_null("Control/Margin/VBox/BottomBox/BtnStart")
	if btn_back == null: btn_back = get_node_or_null("Control/Margin/VBox/BottomBox/BtnBack")
	if desc_label == null: desc_label = get_node_or_null("Control/Margin/VBox/DescLabel")


func _ready() -> void:
	_ensure_nodes()
	var gm = get_node_or_null("/root/GameManager")
	if gm and "selected_character_id" in gm:
		selected_class = gm.selected_character_id
	
	if btn_knight: btn_knight.pressed.connect(func(): _select_class("knight"))
	if btn_mage: btn_mage.pressed.connect(func(): _select_class("mage"))
	if btn_archer: btn_archer.pressed.connect(func(): _select_class("archer"))
	
	if card_knight: card_knight.gui_input.connect(func(ev): _on_card_gui_input(ev, "knight"))
	if card_mage: card_mage.gui_input.connect(func(ev): _on_card_gui_input(ev, "mage"))
	if card_archer: card_archer.gui_input.connect(func(ev): _on_card_gui_input(ev, "archer"))
	
	if btn_start: btn_start.pressed.connect(_on_start_pressed)
	if btn_back: btn_back.pressed.connect(_on_back_pressed)
	
	_select_class(selected_class)


func _on_card_gui_input(event: InputEvent, class_id: String) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_select_class(class_id)


func _select_class(class_id: String) -> void:
	selected_class = class_id
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.selected_character_id = class_id
	
	_update_ui_selection()


func _update_ui_selection() -> void:
	if desc_label and class_descriptions.has(selected_class):
		desc_label.text = class_descriptions[selected_class]
		
	_set_card_highlight(card_knight, selected_class == "knight")
	_set_card_highlight(card_mage, selected_class == "mage")
	_set_card_highlight(card_archer, selected_class == "archer")


func _set_card_highlight(card: PanelContainer, is_selected: bool) -> void:
	if card == null:
		return
	var tween = create_tween()
	if is_selected:
		card.modulate = Color(1.2, 1.2, 1.0, 1.0)
		tween.tween_property(card, "scale", Vector2(1.05, 1.05), 0.15)
	else:
		card.modulate = Color(0.7, 0.7, 0.7, 0.85)
		tween.tween_property(card, "scale", Vector2(1.0, 1.0), 0.15)


func _on_start_pressed() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.selected_character_id = selected_class
		if gm.has_method("restart"):
			gm.restart()
		else:
			get_tree().change_scene_to_file("res://Scenes/Levels/level_01.tscn")
	else:
		get_tree().change_scene_to_file("res://Scenes/Levels/level_01.tscn")


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/Levels/menu.tscn")
