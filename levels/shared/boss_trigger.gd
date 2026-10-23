extends Area2D
## Boss room trigger: slams the gate shut behind the player, eases the camera into the arena,
## shakes the screen on impact, then shows the banner.

@export var gate: Gate
@export var arena: Rect2


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(_body: Node2D) -> void:
	set_deferred("monitoring", false)
	gate.closed = true
	get_tree().current_scene.lock_camera(arena)
	await get_tree().create_timer(Gate.SLIDE_TIME).timeout
	_shake(get_viewport().get_camera_2d())
	$Banner.show()


func _shake(camera: Camera2D) -> void:
	var tween := create_tween()
	for i in 6:
		tween.tween_property(camera, "offset", Vector2(randf_range(-4, 4), randf_range(-3, 3)), 0.04)
	tween.tween_property(camera, "offset", Vector2.ZERO, 0.06)
