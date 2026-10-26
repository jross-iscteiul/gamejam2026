extends StaticBody2D
## 3-tile platform you can jump up through from below and then stand on. It lives on its own
## "platforms" physics layer (8), which only walkers (the player, JARVIS's mech) collide with:
## bullets and enemy shots fly straight through it, so you can shoot down at enemies below.

@export var texture: Texture2D ## tileset to take the 3-tile strip from (matches the level)


func _ready() -> void:
	if texture:
		$Sprite2D.texture = texture
