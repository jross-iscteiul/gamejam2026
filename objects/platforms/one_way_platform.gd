extends StaticBody2D
## Tiled platform you can jump up through from below and then stand on. It lives on its own
## "platforms" physics layer (8), which only walkers (the player, JARVIS's mech) collide with:
## bullets and enemy shots fly straight through it, so you can shoot down at enemies below.

@export var texture: Texture2D ## tileset containing the left, middle and right platform tiles
@export_range(1, 8) var tiles_wide: int = 3


func _ready() -> void:
	if texture:
		$Sprite2D.texture = texture
	var shape := RectangleShape2D.new()
	shape.size = Vector2(tiles_wide * 32, 32)
	$CollisionShape2D.shape = shape
	$Sprite2D.hide()
	queue_redraw()


func _draw() -> void:
	if not is_node_ready():
		return
	var atlas: Texture2D = $Sprite2D.texture
	for i in tiles_wide:
		var source := 0 if i == 0 else 2 if i == tiles_wide - 1 else 1
		var destination := Rect2(-tiles_wide * 16 + i * 32, -16, 32, 32)
		draw_texture_rect_region(atlas, destination, Rect2(source * 32, 0, 32, 32))
