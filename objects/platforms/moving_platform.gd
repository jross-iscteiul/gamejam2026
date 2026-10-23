extends AnimatableBody2D
## 3-tile platform that eases between its start and start + travel, pausing at each end
## so the player can step on/off level with the ledges. AnimatableBody2D carries the player.

@export var travel := Vector2(192, 0)
@export var seconds_one_way := 2.5
@export var pause := 1.0
@export var texture: Texture2D ## tileset to take the 3-tile strip from (matches the level)


func _ready() -> void:
	if texture:
		$Sprite2D.texture = texture
	var tween := create_tween().set_loops().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "position", position + travel, seconds_one_way).set_delay(pause)
	tween.tween_property(self, "position", position, seconds_one_way).set_delay(pause)
