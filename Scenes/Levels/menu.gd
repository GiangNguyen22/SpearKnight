extends Node2D

const GROUND_RATIO := 0.93
const TROOPER_SCALE := 5.4
const BASE_HEIGHT := 648.0

# mode "cover": phu het man hinh | mode "band": phai kin chieu rong, doi day theo ty le
const LAYOUT := {
	"SkyFar": {"mode": "cover", "offset": Vector2(0.0, -0.012)},
	"SkyNear": {"mode": "cover", "offset": Vector2(0.0, 0.016)},
	"HillsFar": {"mode": "band", "bottom": 0.95, "height": 0.44},
	"Mist": {"mode": "band", "bottom": 0.72, "height": 0.3},
	"HillsNear": {"mode": "band", "bottom": 1.0, "height": 0.5},
}

const STARS := {
	"StarA": Vector2(0.13, 0.17),
	"StarB": Vector2(0.55, 0.1),
	"StarC": Vector2(0.87, 0.23),
}

const DRIFT := {
	"SkyFar": {"amp": Vector2(10.0, 3.0), "period": 9.0, "phase": 0.0},
	"SkyNear": {"amp": Vector2(20.0, 5.0), "period": 11.0, "phase": 1.7},
	"HillsFar": {"amp": Vector2(8.0, 0.0), "period": 13.0, "phase": 3.1},
	"Mist": {"amp": Vector2(64.0, 0.0), "period": 27.0, "phase": 0.9},
	"HillsNear": {"amp": Vector2(16.0, 0.0), "period": 9.5, "phase": 4.6},
}

const TWINKLE := {
	"StarA": {"amp": 0.35, "period": 2.3, "phase": 0.0},
	"StarB": {"amp": 0.25, "period": 3.1, "phase": 1.4},
	"StarC": {"amp": 0.3, "period": 2.7, "phase": 2.6},
}

@onready var btn_continue: Button = $UI/MenuPanel/btnContinue
@onready var trooper: AnimatedSprite2D = $Trooper if has_node("Trooper") else null
@onready var stars_root: Node2D = $Background/Stars

var _drifters: Array = []
var _twinklers: Array = []
var _elapsed := 0.0


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		btn_continue.disabled = !gm.has_gamesaved()
		btn_continue.text = "Continue"
		gm.load_option()
	else:
		btn_continue.disabled = true
	_layout()
	get_viewport().size_changed.connect(_layout)
	_setup_button_effects()


func _setup_button_effects() -> void:
	var menu_panel = get_node_or_null("UI/MenuPanel")
	if menu_panel == null: return
	for child in menu_panel.get_children():
		if child is Button:
			child.mouse_entered.connect(func():
				child.pivot_offset = child.size / 2.0
				var t = child.create_tween()
				t.tween_property(child, "scale", Vector2(1.04, 1.04), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			)
			child.mouse_exited.connect(func():
				child.pivot_offset = child.size / 2.0
				var t = child.create_tween()
				t.tween_property(child, "scale", Vector2(1.0, 1.0), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	_elapsed += delta
	for d: Dictionary in _drifters:
		var t: float = float(d["phase"]) + _elapsed * float(d["speed"])
		var amp: Vector2 = d["amp"]
		var sprite: Sprite2D = d["sprite"]
		sprite.position = (d["base"] as Vector2) + Vector2(sin(t) * amp.x, sin(t * 0.63) * amp.y)
	for k: Dictionary in _twinklers:
		var wave := sin(float(k["phase"]) + _elapsed * float(k["speed"]))
		var sprite: Sprite2D = k["sprite"]
		sprite.modulate.a = clampf(float(k["base"]) + wave * float(k["amp"]), 0.05, 1.0)


func _layout() -> void:
	var vp := get_viewport_rect().size
	$UI.size = vp
	_drifters.clear()
	_twinklers.clear()
	var bgl = get_node_or_null("/root/BgLayout")
	if bgl and bgl.has_method("apply"):
		bgl.apply($Background, LAYOUT)

	for key in DRIFT:
		var layer_name := String(key)
		var sprite := $Background.get_node_or_null(layer_name) as Sprite2D
		if sprite == null:
			continue
		var drift: Dictionary = DRIFT[layer_name]
		_drifters.append({
			"sprite": sprite,
			"base": sprite.position,
			"amp": drift["amp"] as Vector2,
			"speed": TAU / float(drift["period"]),
			"phase": float(drift["phase"]),
		})

	for key in STARS:
		var star_name := String(key)
		var sprite := stars_root.get_node_or_null(star_name) as Sprite2D
		if sprite == null:
			continue
		sprite.position = (STARS[star_name] as Vector2) * vp
		var tw: Dictionary = TWINKLE.get(star_name, {})
		_twinklers.append({
			"sprite": sprite,
			"base": sprite.modulate.a,
			"amp": float(tw.get("amp", 0.3)),
			"speed": TAU / float(tw.get("period", 2.5)),
			"phase": float(tw.get("phase", 0.0)),
		})

	if trooper:
		var unit := maxf(vp.y / BASE_HEIGHT, 0.5)
		var s := TROOPER_SCALE * unit
		trooper.scale = Vector2(s, s)
		trooper.position = Vector2(vp.x * 0.8, vp.y * GROUND_RATIO - 16.0 * s)


func _on_btn_start_pressed() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	var select_scene := "res://Scenes/UI/character_select.tscn"
	if ResourceLoader.exists(select_scene):
		get_tree().change_scene_to_file(select_scene)
	else:
		var gm = get_node_or_null("/root/GameManager")
		if gm and gm.has_method("restart"):
			gm.restart()


func _on_btn_option_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/Levels/options.tscn")


func _on_btn_continue_pressed() -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.has_method("load_game"):
		gm.load_game()


func _on_btn_level_select_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/UI/level_select.tscn")


func _on_btn_story_pressed() -> void:
	var dm = get_node_or_null("/root/DialogueManager")
	if dm and dm.has_method("start_dialogue"):
		dm.start_dialogue([
			"Vương quốc từng là miền đất thanh bình được bảo hộ bởi Cổ Vật Thần Thánh và nguồn Năng Lượng Nguyên Tố.",
			"Một ngày nọ, phong ấn cổ xưa vỡ vụn. Hầm Ngục Hắc Ám trỗi dậy cùng bầy quái vật Orc và Quái Nấm khổng lồ.",
			"Báu vật và các Chìa Khóa Cổ bị phân tán khắp các tầng hầm ngục u tối, phong tỏa cánh cổng qua màn.",
			"Là những dũng sĩ tinh anh được vương quốc tuyển chọn (Hiệp Sĩ Quả Cảm, Phù Thủy Uyên Bác, Cung Thủ Thiện Xạ), bạn gánh vác sứ mệnh tiến sâu vào sào huyệt hầm ngục...",
			"Hãy vận dụng vũ khí, làm chủ các nguyên tố (Lửa, Băng, Quang Ma Pháp), thu thập đủ chìa khóa và đánh bại Chúa Tể Hầm Ngục để cứu rỗi vương quốc!"
		], "Sử Gia Hoàng Gia")


func _on_btn_exit_pressed() -> void:
	get_tree().quit()
