extends Node2D

@export var enemy_scenes : Array[PackedScene] = []
@export var speed_range : Array[int] = [50,60,70]
@export var respawn_time : Array[int] = [10,5]
@export var respawn_onstart = true
@export var max_instance = 2

var trespawn = 10
var tsec = 0
var instance_count = 0
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$icon.queue_free()
	if respawn_onstart :
		trespawn = 0
	else:
		trespawn = respawn_time.pick_random()

func respawn():
	tsec = 0
	if enemy_scenes.size()>0 && instance_count < max_instance:
		var enemyscene = enemy_scenes.pick_random()
		var obj :Enemy = enemyscene.instantiate() 
		instance_count += 1
		obj.position = Vector2.ZERO
		obj.speed = speed_range.pick_random()
		obj.direction = [-1,1].pick_random()
		obj.velocity.y = -200
		self.add_child(obj)
		trespawn = respawn_time.pick_random()
		
func _on_timer_timeout() -> void:
	tsec += 1
	if tsec > trespawn:
		respawn()


func _on_child_exiting_tree(node: Node) -> void:
	if node is Enemy:
		instance_count -= 1
