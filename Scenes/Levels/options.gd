extends Node2D

const LAYOUT := {
	"SkyFar": {"mode": "cover", "offset": Vector2(0.0, -0.012)},
	"SkyNear": {"mode": "cover", "offset": Vector2(0.0, 0.016)},
	"HillsFar": {"mode": "band", "bottom": 0.95, "height": 0.44},
	"HillsNear": {"mode": "band", "bottom": 1.0, "height": 0.5},
}

@onready var slider_master: HSlider = %SliderMaster if has_node("%SliderMaster") else null
@onready var slider_music: HSlider = %SliderMusic if has_node("%SliderMusic") else null
@onready var slider_sfx: HSlider = %SliderSfx if has_node("%SliderSfx") else null

func _ready() -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.load_option()
		gm.update_option()
		if slider_master and "master_volume" in gm:
			slider_master.value = gm.master_volume * 100.0
		if slider_music and "music_volume" in gm:
			slider_music.value = gm.music_volume * 100.0
		if slider_sfx and "sfx_volume" in gm:
			slider_sfx.value = gm.sfx_volume * 100.0

	_layout()
	get_viewport().size_changed.connect(_layout)

	if slider_master: slider_master.value_changed.connect(_on_slider_master_changed)
	if slider_music: slider_music.value_changed.connect(_on_slider_music_changed)
	if slider_sfx: slider_sfx.value_changed.connect(_on_slider_sfx_changed)

func _layout() -> void:
	$UI.size = get_viewport_rect().size
	var bgl = get_node_or_null("/root/BgLayout")
	if bgl and bgl.has_method("apply"):
		bgl.apply($Background, LAYOUT)

func _on_slider_master_changed(val: float) -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.set("master_volume", val / 100.0)
		if gm.has_method("update_option"): gm.update_option()
		if gm.has_method("save_option"): gm.save_option()

func _on_slider_music_changed(val: float) -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.set("music_volume", val / 100.0)
		if gm.has_method("update_option"): gm.update_option()
		if gm.has_method("save_option"): gm.save_option()

func _on_slider_sfx_changed(val: float) -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.set("sfx_volume", val / 100.0)
		if gm.has_method("update_option"): gm.update_option()
		if gm.has_method("save_option"): gm.save_option()