extends Enemy

func _ready() -> void:
	super._ready()
	var types = Array($Sprite/AnimateSprite.sprite_frames.get_animation_names())
	$Sprite/AnimateSprite.animation = types.pick_random()
	$Sprite/AnimateSprite.play()
