extends "res://Scenes/Prefabs/screen_bg.gd"


func _ready() -> void:
	super()
	var panel := get_node_or_null("UI/Panel")
	if panel:
		var lbl_score = panel.get_node_or_null("LblScore")
		if lbl_score:
			lbl_score.text = str(GameManager.score)
		var lbl_time = panel.get_node_or_null("LblTime")
		if lbl_time:
			lbl_time.text = GameManager.play_time_text()
		var lbl_lives = panel.get_node_or_null("LblLives")
		if lbl_lives:
			lbl_lives.text = str(GameManager.lives_lost)
	var music_player = get_node_or_null("MusicPlayer")
	if music_player:
		music_player.play()


func _on_music_player_finished() -> void:
	var music_player = get_node_or_null("MusicPlayer")
	if music_player:
		music_player.play(0)