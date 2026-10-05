class_name PauseMenu
extends Control

signal pause_toggled(is_paused: bool)

@onready var main_panel: Panel = $Panel if has_node("Panel") else null
@onready var options_panel: Panel = $OptionsPanel if has_node("OptionsPanel") else null

# Main Pause Buttons
@onready var btn_resume: Button = %BtnResume if has_node("%BtnResume") else null
@onready var btn_restart: Button = %BtnRestart if has_node("%BtnRestart") else null
@onready var btn_options: Button = %BtnOptions if has_node("%BtnOptions") else null
@onready var btn_menu: Button = %BtnMenu if has_node("%BtnMenu") else null

# Option Sliders inside Pause Options Panel
@onready var slider_master: HSlider = %SliderMaster if has_node("%SliderMaster") else null
@onready var slider_music: HSlider = %SliderMusic if has_node("%SliderMusic") else null
@onready var slider_sfx: HSlider = %SliderSfx if has_node("%SliderSfx") else null
@onready var btn_back_options: Button = %BtnBackOptions if has_node("%BtnBackOptions") else null

func _ready() -> void:
	visible = false
	if options_panel:
		options_panel.visible = false
		
	if btn_resume:
		btn_resume.pressed.connect(close_pause_menu)
	if btn_restart:
		btn_restart.pressed.connect(_on_btn_restart_pressed)
	if btn_options:
		btn_options.pressed.connect(_on_btn_options_pressed)
	if btn_menu:
		btn_menu.pressed.connect(_on_btn_menu_pressed)
	if btn_back_options:
		btn_back_options.pressed.connect(_on_btn_back_options_pressed)
		
	if slider_master:
		slider_master.value_changed.connect(_on_slider_master_changed)
	if slider_music:
		slider_music.value_changed.connect(_on_slider_music_changed)
	if slider_sfx:
		slider_sfx.value_changed.connect(_on_slider_sfx_changed)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE):
		var current_scene = get_tree().current_scene
		if current_scene and current_scene.scene_file_path.to_lower().contains("menu"):
			return # Do not trigger pause on main menu
		
		# If options panel is open inside pause menu, back to main pause panel
		if visible and options_panel and options_panel.visible:
			_on_btn_back_options_pressed()
			get_viewport().set_input_as_handled()
			return

		toggle_pause()
		get_viewport().set_input_as_handled()

func toggle_pause() -> void:
	if visible:
		close_pause_menu()
	else:
		open_pause_menu()

func open_pause_menu() -> void:
	visible = true
	get_tree().paused = true
	if main_panel: main_panel.visible = true
	if options_panel: options_panel.visible = false
	sync_sliders_with_gamemanager()
	pause_toggled.emit(true)

func close_pause_menu() -> void:
	visible = false
	get_tree().paused = false
	if options_panel: options_panel.visible = false
	pause_toggled.emit(false)

func sync_sliders_with_gamemanager() -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		if "master_volume" in gm and slider_master:
			slider_master.value = gm.master_volume * 100.0
		if "music_volume" in gm and slider_music:
			slider_music.value = gm.music_volume * 100.0
		if "sfx_volume" in gm and slider_sfx:
			slider_sfx.value = gm.sfx_volume * 100.0

func _on_btn_options_pressed() -> void:
	if main_panel: main_panel.visible = false
	if options_panel: options_panel.visible = true
	sync_sliders_with_gamemanager()

func _on_btn_back_options_pressed() -> void:
	if options_panel: options_panel.visible = false
	if main_panel: main_panel.visible = true

func _on_btn_restart_pressed() -> void:
	get_tree().paused = false
	visible = false
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.has_method("restart"):
		gm.restart()

func _on_btn_menu_pressed() -> void:
	get_tree().paused = false
	visible = false
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.has_method("save_checkpoint"):
		gm.save_checkpoint()
	get_tree().change_scene_to_file("res://Scenes/Levels/menu.tscn")

func _on_slider_master_changed(val: float) -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.set("master_volume", val / 100.0)
		if gm.has_method("update_option"):
			gm.update_option()
		if gm.has_method("save_option"):
			gm.save_option()

func _on_slider_music_changed(val: float) -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.set("music_volume", val / 100.0)
		if gm.has_method("update_option"):
			gm.update_option()
		if gm.has_method("save_option"):
			gm.save_option()

func _on_slider_sfx_changed(val: float) -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.set("sfx_volume", val / 100.0)
		if gm.has_method("update_option"):
			gm.update_option()
		if gm.has_method("save_option"):
			gm.save_option()
