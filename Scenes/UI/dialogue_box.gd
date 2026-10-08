extends CanvasLayer

signal dialogue_started
signal dialogue_ended
signal line_finished(index: int)

@export var type_speed: float = 0.025
@export var default_knight_portrait: Texture2D
@export var default_elder_portrait: Texture2D
@export var default_mage_portrait: Texture2D
@export var default_archer_portrait: Texture2D

@onready var root_control: Control = $Control
@onready var dialogue_panel: Panel = $Control/DialoguePanel
@onready var speaker_label: Label = $Control/DialoguePanel/SpeakerLabel
@onready var content_label: RichTextLabel = $Control/DialoguePanel/ContentLabel
@onready var portrait_rect: TextureRect = $Control/DialoguePanel/PortraitFrame/PortraitRect
@onready var btn_next: Button = $Control/DialoguePanel/BtnNext
@onready var indicator: Label = $Control/DialoguePanel/Indicator
@onready var type_sfx: AudioStreamPlayer = $TypeSfx

var lines: Array[String] = []
var current_line_index: int = 0
var speaker_name: String = ""
var is_typing: bool = false
var is_active: bool = false
var _skip_requested: bool = false


func _ensure_nodes() -> void:
	if root_control == null:
		root_control = get_node_or_null("Control")
	if dialogue_panel == null:
		dialogue_panel = get_node_or_null("Control/DialoguePanel")
	if speaker_label == null:
		speaker_label = get_node_or_null("Control/DialoguePanel/SpeakerLabel")
	if content_label == null:
		content_label = get_node_or_null("Control/DialoguePanel/ContentLabel")
	if portrait_rect == null:
		portrait_rect = get_node_or_null("Control/DialoguePanel/PortraitFrame/PortraitRect")
	if btn_next == null:
		btn_next = get_node_or_null("Control/DialoguePanel/BtnNext")
	if indicator == null:
		indicator = get_node_or_null("Control/DialoguePanel/Indicator")
	if type_sfx == null:
		type_sfx = get_node_or_null("TypeSfx")


func _ready() -> void:
	_ensure_nodes()
	if default_knight_portrait == null:
		default_knight_portrait = load("res://Assets/UI/portrait_knight.jpg")
	if default_elder_portrait == null:
		default_elder_portrait = load("res://Assets/UI/portrait_elder.jpg")
	if default_mage_portrait == null:
		default_mage_portrait = load("res://Assets/UI/portrait_mage.jpg")
	if default_archer_portrait == null:
		default_archer_portrait = load("res://Assets/UI/portrait_archer.jpg")
	if root_control:
		root_control.visible = false
	if indicator:
		indicator.visible = false
	if btn_next and not btn_next.pressed.is_connected(advance_dialogue):
		btn_next.pressed.connect(advance_dialogue)


func is_dialogue_active() -> bool:
	return is_active


func start_dialogue(new_lines: Array, speaker: String = "Hiệp Sĩ", portrait: Texture2D = null) -> void:
	_ensure_nodes()
	if new_lines.is_empty():
		return
	
	lines.clear()
	for line_item in new_lines:
		lines.append(str(line_item))
		
	speaker_name = speaker
	current_line_index = 0
	is_active = true
	_skip_requested = false
	
	# Khóa di chuyển người chơi nếu có
	var gm = get_node_or_null("/root/GameManager")
	if gm and "player" in gm and gm.player != null and is_instance_valid(gm.player):
		gm.player.movement_enabled = false
		gm.player.velocity = Vector2.ZERO
	
	# Chọn portrait phù hợp nếu không truyền
	if portrait != null:
		if portrait_rect:
			portrait_rect.texture = portrait
	elif speaker.to_lower().contains("trưởng làng") or speaker.to_lower().contains("sử gia") or speaker.to_lower().contains("elder") or speaker.to_lower().contains("già"):
		if portrait_rect:
			portrait_rect.texture = default_elder_portrait
	elif speaker.to_lower().contains("phù thủy") or speaker.to_lower().contains("mage") or speaker.to_lower().contains("sorceress"):
		if portrait_rect:
			portrait_rect.texture = default_mage_portrait
	elif speaker.to_lower().contains("cung thủ") or speaker.to_lower().contains("archer") or speaker.to_lower().contains("ranger"):
		if portrait_rect:
			portrait_rect.texture = default_archer_portrait
	else:
		if portrait_rect:
			portrait_rect.texture = default_knight_portrait
	
	if root_control:
		root_control.visible = true
	if dialogue_panel:
		dialogue_panel.modulate.a = 0.0
		var tween := create_tween()
		tween.tween_property(dialogue_panel, "modulate:a", 1.0, 0.2)
	
	dialogue_started.emit()
	_display_current_line()


func _display_current_line() -> void:
	_ensure_nodes()
	if current_line_index >= lines.size():
		end_dialogue()
		return
	
	if indicator:
		indicator.visible = false
	_skip_requested = false
	if speaker_label:
		speaker_label.text = speaker_name
	
	var full_text: String = lines[current_line_index]
	if content_label:
		content_label.text = full_text
		content_label.visible_characters = 0
	is_typing = true
	
	var total_chars: int = content_label.get_total_character_count() if content_label else full_text.length()
	var char_idx: int = 0
	
	while char_idx < total_chars:
		if _skip_requested:
			if content_label:
				content_label.visible_characters = -1
			break
		
		char_idx += 1
		if content_label:
			content_label.visible_characters = char_idx
		
		# Phát âm thanh gõ nhẹ (bỏ qua ký tự khoảng trắng)
		if char_idx % 2 == 0 and type_sfx:
			type_sfx.pitch_scale = randf_range(0.92, 1.08)
			type_sfx.play()
		
		await get_tree().create_timer(type_speed, false, false, true).timeout
	
	is_typing = false
	_skip_requested = false
	if indicator:
		indicator.visible = true
	line_finished.emit(current_line_index)


func advance_dialogue() -> void:
	if not is_active:
		return
	
	if is_typing:
		# Nhấn lần 1 khi đang gõ -> hiển thị toàn bộ chữ ngay lập tức
		_skip_requested = true
	else:
		# Nhấn lần 2 khi đã gõ xong -> chuyển câu tiếp theo
		current_line_index += 1
		if current_line_index < lines.size():
			_display_current_line()
		else:
			end_dialogue()


func end_dialogue() -> void:
	_ensure_nodes()
	is_active = false
	is_typing = false
	if indicator:
		indicator.visible = false
	
	if dialogue_panel:
		var tween := create_tween()
		tween.tween_property(dialogue_panel, "modulate:a", 0.0, 0.15)
		await tween.finished
	if root_control:
		root_control.visible = false
	
	# Trả lại quyền di chuyển cho người chơi
	var gm = get_node_or_null("/root/GameManager")
	if gm and "player" in gm and gm.player != null and is_instance_valid(gm.player):
		gm.player.movement_enabled = true
	
	dialogue_ended.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not is_active or get_tree().paused:
		return
	
	# Bấm Space, Enter hoặc Click chuột để qua câu
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("Jump") or event.is_action_pressed("Shoot"):
		advance_dialogue()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		advance_dialogue()
		get_viewport().set_input_as_handled()
