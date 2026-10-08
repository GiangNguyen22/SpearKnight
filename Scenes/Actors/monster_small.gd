extends Enemy

var walk_animation_name: String = ""

func _ready() -> void:
	super._ready()
	setup_monster_animations()

func setup_monster_animations() -> void:
	var anim_sprite = get_node_or_null("Sprite/AnimateSprite") as AnimatedSprite2D
	if not anim_sprite or not anim_sprite.sprite_frames:
		return
		
	var sf = anim_sprite.sprite_frames.duplicate() as SpriteFrames
	anim_sprite.sprite_frames = sf
	
	var anim_names = sf.get_animation_names()
	if anim_names.has("orc_walk"):
		walk_animation_name = "orc_walk"
		if not sf.has_animation("attack"):
			sf.add_animation("attack")
			sf.set_animation_loop("attack", false)
			sf.set_animation_speed("attack", 15.0)
			for i in range(10):
				var path = "res://Assets/Spritesheet/1_ORK/ORK_01_ATTAK_%03d.png" % i
				if ResourceLoader.exists(path):
					sf.add_frame("attack", load(path))
	elif anim_names.has("troll"):
		walk_animation_name = "troll"
		if not sf.has_animation("attack"):
			sf.add_animation("attack")
			sf.set_animation_loop("attack", false)
			sf.set_animation_speed("attack", 15.0)
			for i in range(10):
				var path = "res://Assets/Spritesheet/2_TROLL/Troll_02_1_ATTACK_%03d.png" % i
				if ResourceLoader.exists(path):
					sf.add_frame("attack", load(path))
					
	if walk_animation_name != "":
		anim_sprite.play(walk_animation_name)

func play_attack_animation() -> void:
	var anim_sprite = get_node_or_null("Sprite/AnimateSprite") as AnimatedSprite2D
	if anim_sprite and anim_sprite.sprite_frames and anim_sprite.sprite_frames.has_animation("attack"):
		anim_sprite.play("attack")
		anim_sprite.animation_finished.connect(func():
			if is_instance_valid(anim_sprite) and alive:
				if walk_animation_name != "":
					anim_sprite.play(walk_animation_name)
		, CONNECT_ONE_SHOT)
