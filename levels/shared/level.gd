extends Node2D
## Level root: sky colour + camera limits clamped to the tile map.

@export var number := 1
@export var sky := Color(0.835, 0.902, 0.961)

@onready var camera: Camera2D = $Player/Camera2D


func _ready() -> void:
	GameState.current_level = number
	RenderingServer.set_default_clear_color(sky)
	var used: Rect2i = $Tiles.get_used_rect()
	var size: Vector2i = $Tiles.tile_set.tile_size
	lock_camera(Rect2(used.position * size, used.size * size))
	camera.reset_smoothing()


func lock_camera(rect: Rect2) -> void:
	camera.limit_left = int(rect.position.x)
	camera.limit_top = int(rect.position.y)
	camera.limit_right = int(rect.end.x)
	camera.limit_bottom = int(rect.end.y)
