class_name NPCVillageHead
extends CharacterBody2D

signal quest_given
signal dialogue_completed

@export var npc_name: String = "Trưởng Làng"
@export var npc_portrait: Texture2D

@onready var sprite: Sprite2D = $Sprite2D
@onready var prompt_ui: Node2D = $PromptUI
@onready var prompt_btn: Button = $PromptUI/PromptButton
@onready var quest_marker: Label = $QuestMarker
@onready var interaction_area: Area2D = $InteractionArea

var has_talked_once: bool = false
var is_player_near: bool = false
var _idle_tween: Tween
var _bob_time: float = 0.0


func _ready() -> void:
	if npc_portrait == null:
		npc_portrait = load("res://Assets/UI/portrait_elder.jpg")
	
	prompt_ui.visible = false
	prompt_ui.scale = Vector2.ZERO
	
	interaction_area.body_entered.connect(_on_body_entered)
	interaction_area.body_exited.connect(_on_body_exited)
	
	if prompt_btn:
		prompt_btn.pressed.connect(interact)
	
	_start_idle_animation()


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
		move_and_slide()


func _process(delta: float) -> void:
	_bob_time += delta * 3.5
	if quest_marker and quest_marker.visible:
		quest_marker.position.y = -95.0 + sin(_bob_time) * 4.0


func _input_event(_viewport: Viewport, event: InputEvent, _shape_idx: int) -> void:
	if not is_player_near:
		return
	var dm = get_node_or_null("/root/DialogueManager")
	if dm and dm.has_method("is_dialogue_active") and dm.is_dialogue_active():
		return
	if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed):
		interact()
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if not is_player_near:
		return
	
	var dm = get_node_or_null("/root/DialogueManager")
	if dm and dm.has_method("is_dialogue_active") and dm.is_dialogue_active():
		return
	
	if event.is_action_pressed("Interact") or (event is InputEventKey and event.pressed and event.keycode == KEY_E):
		interact()
		get_viewport().set_input_as_handled()


func interact() -> void:
	var dm = get_node_or_null("/root/DialogueManager")
	if dm and dm.has_method("is_dialogue_active") and dm.is_dialogue_active():
		return
	
	var gm = get_node_or_null("/root/GameManager")
	var char_id: String = gm.selected_character_id if gm and "selected_character_id" in gm else "knight"
	
	var char_greeting := "dũng sĩ Hiệp Sĩ"
	var char_weapon_advice := "Hãy dùng [color=cyan]Chiến Thương[/color] dũng mãnh và những đòn cận chiến liên hoàn để tiêu diệt quái vật."
	var char_title := "Hiệp Sĩ"
	
	match char_id:
		"mage":
			char_greeting = "nhà pháp thuật Phù Thủy"
			char_weapon_advice = "Hãy dùng [color=magenta]Ma Pháp Nguyên Tố[/color] uy lực cùng thuật [color=magenta]Tốc Biến[/color] huyền bí để thanh trừng quái vật."
			char_title = "Phù Thủy"
		"archer":
			char_greeting = "thiện xạ Cung Thủ"
			char_weapon_advice = "Hãy dùng [color=green]Cung Tên Thần Tốc[/color] bắn xuyên bầy quái vật và giữ cự ly an toàn."
			char_title = "Cung Thủ"
		_:
			char_greeting = "dũng sĩ Hiệp Sĩ"
			char_weapon_advice = "Hãy dùng [color=cyan]Chiến Thương[/color] dũng mãnh và những đòn cận chiến liên hoàn để tiêu diệt quái vật."
			char_title = "Hiệp Sĩ"
	
	var lines: Array[String] = []
	if not has_talked_once:
		lines = [
			"Chào %s! Ta là Trưởng Làng kiêm Sử Gia của vương quốc." % char_greeting,
			"Hầm Ngục Hắc Ám phía trước vô cùng hiểm ác, tràn ngập quái Nấm độc và quái Orc khát máu.",
			"Cánh cổng thần thánh đã bị phong ấn. Hãy tìm đủ [color=gold]3 Chìa Khóa Cổ[/color] được cất giấu để mở cổng hầm ngục!",
			"%s Vương quốc trông cậy cả vào ngươi!" % char_weapon_advice
		]
		has_talked_once = true
		if quest_marker:
			quest_marker.text = "[?]"
			quest_marker.modulate = Color(0.4, 0.8, 1.0)
		quest_given.emit()
	else:
		lines = [
			"Hãy cẩn trọng từng bước đi, %s!" % char_title,
			"Thu thập đủ [color=gold]3 Chìa Khóa Cổ[/color] rồi tiến về cánh cổng phong ấn ở cuối hầm ngục nhé!"
		]
	
	if dm and dm.has_method("start_dialogue"):
		dm.start_dialogue(lines, npc_name, npc_portrait)
		if "dialogue_ended" in dm:
			await dm.dialogue_ended
	dialogue_completed.emit()


func _on_body_entered(body: Node2D) -> void:
	if body is Player or body.is_in_group("Player"):
		is_player_near = true
		_show_prompt()


func _on_body_exited(body: Node2D) -> void:
	if body is Player or body.is_in_group("Player"):
		is_player_near = false
		_hide_prompt()


func _show_prompt() -> void:
	prompt_ui.visible = true
	var tween := create_tween()
	tween.tween_property(prompt_ui, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _hide_prompt() -> void:
	var tween := create_tween()
	tween.tween_property(prompt_ui, "scale", Vector2.ZERO, 0.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	await tween.finished
	if not is_player_near:
		prompt_ui.visible = false


func _start_idle_animation() -> void:
	_idle_tween = create_tween().set_loops()
	_idle_tween.tween_property(sprite, "scale", Vector2(0.12, 0.123), 1.6).set_trans(Tween.TRANS_SINE)
	_idle_tween.tween_property(sprite, "scale", Vector2(0.12, 0.117), 1.6).set_trans(Tween.TRANS_SINE)
