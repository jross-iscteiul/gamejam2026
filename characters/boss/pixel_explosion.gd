extends Node2D
## A stationary pixel burst. The level owns it so it can outlive the defeated robot.

var radius: float = 32.0
var seconds: float = 0.7
var _age: float = 0.0


func _ready() -> void:
	z_index = 10
	add_to_group("boss_explosion")


func _process(delta: float) -> void:
	_age += delta
	if _age >= seconds:
		queue_free()
	else:
		queue_redraw()


func _draw() -> void:
	var progress := clampf(_age / seconds, 0.0, 1.0)
	var frame := floorf(progress * 6.0) / 6.0
	var extent := snappedf(radius * (0.4 + frame * 0.6), 2.0)
	var half := snappedf(extent * 0.5, 2.0)
	var alpha := 1.0 - progress
	draw_rect(Rect2(-extent, -half, extent * 2, half * 2), Color(Color("ff6d05"), alpha))
	draw_rect(Rect2(-half, -extent, half * 2, extent * 2), Color(Color("ff6d05"), alpha))
	var core := snappedf(extent * (1.0 - frame) * 0.65, 2.0)
	draw_rect(Rect2(-core, -core, core * 2, core * 2), Color(Color("ffe119"), alpha))
	var hot := snappedf(core * 0.5, 2.0)
	draw_rect(Rect2(-hot, -hot, hot * 2, hot * 2), Color(1, 1, 1, alpha))
	for i in 16:
		var offset := Vector2.from_angle(TAU * i / 16.0) * radius * (0.7 + frame)
		offset = offset.snapped(Vector2(2, 2))
		draw_rect(Rect2(offset, Vector2(4, 4)), Color(Color("ffe119"), alpha))
