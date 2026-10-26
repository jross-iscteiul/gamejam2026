extends Area2D
## Boss room trigger: slams the gate shut behind the player, eases the camera into the arena,
## shakes the screen on impact, then shows the banner.

@export var gate: Gate
@export var arena: Rect2
## Camera zoom inside the arena: eased out from the normal 3x (like level 2's CameraZone) so
## more of the fight is on screen. 2.7 still keeps the view inside a 704 px wide arena.
@export var arena_zoom := Vector2(2.7, 2.7)
@export var zoom_seconds: float = 0.6


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	set_deferred("monitoring", false)
	gate.closed = true
	# Dying in here must not send the player back behind the sealed gate, outside the locked
	# camera: from now on they respawn just inside the arena.
	if "respawn_point" in body:
		body.respawn_point = global_position
	get_tree().current_scene.lock_camera(arena)
	var camera := get_viewport().get_camera_2d()
	if camera != null:
		create_tween().tween_property(camera, "zoom", arena_zoom, zoom_seconds) \
			.set_trans(Tween.TRANS_SINE)
	await get_tree().create_timer(Gate.SLIDE_TIME).timeout
	_shake(get_viewport().get_camera_2d())
	$Banner.show()


func _shake(camera: Camera2D) -> void:
	var tween := create_tween()
	for i in 6:
		tween.tween_property(camera, "offset", Vector2(randf_range(-4, 4), randf_range(-3, 3)), 0.04)
	tween.tween_property(camera, "offset", Vector2.ZERO, 0.06)
