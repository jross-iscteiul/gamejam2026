extends Area2D
## While the player is inside, ease the camera to a different zoom/offset (e.g. zoom out and
## look down over a drop). Restores the previous values on exit.

const BLEND_TIME := 0.6

@export var zoom := Vector2(2, 2)
@export var offset := Vector2(0, 80)

var saved_zoom: Vector2
var saved_offset: Vector2


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2 # player
	body_entered.connect(_blend.bind(true))
	body_exited.connect(_blend.bind(false))


func _blend(_body: Node2D, entering: bool) -> void:
	var camera := get_viewport().get_camera_2d()
	if camera == null: # scene is being torn down
		return
	if entering:
		saved_zoom = camera.zoom
		saved_offset = camera.offset
	var tween := create_tween().set_parallel().set_trans(Tween.TRANS_SINE)
	tween.tween_property(camera, "zoom", zoom if entering else saved_zoom, BLEND_TIME)
	tween.tween_property(camera, "offset", offset if entering else saved_offset, BLEND_TIME)
