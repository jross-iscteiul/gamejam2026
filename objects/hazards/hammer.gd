@tool
extends Hazard
## Pendulum hammer hanging from its origin (the pivot). The head deals 1 HP and knocks the
## player away from the pivot (knockback set in hammer.tscn).

@export var length := 96.0
@export_range(10.0, 85.0) var max_angle := 60.0
@export var period := 2.4
## Seconds added to the swing clock so neighbouring hammers swing out of step.
@export var phase := 0.0

const HEAD := Vector2(26, 20)

var _arm: Node2D


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_arm = Node2D.new()
	_arm.name = "Arm"
	add_child(_arm)
	make_hitbox(rect(HEAD), Vector2(0, length), _arm)


func angle_at(clock: float) -> float:
	return deg_to_rad(max_angle) * sin(TAU * (clock + phase) / (period / difficulty))


func _physics_process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		_arm.rotation = angle_at(time)


func knockback_impulse(target: Node2D) -> Vector2:
	var side := signf(target.global_position.x - global_position.x)
	if absf(target.global_position.x - global_position.x) < 4.0: # right under the pivot: follow the swing
		side = signf(cos(TAU * (time + phase) / (period / difficulty)))
	return Vector2(side * knockback, -knockback * 0.45)


func _draw() -> void:
	var a := angle_at(time)
	var head := Vector2(0, length).rotated(a)
	draw_line(Vector2.ZERO, head, Color(0.45, 0.47, 0.5), 4.0)
	draw_circle(Vector2.ZERO, 5.0, Color(0.25, 0.27, 0.3))
	draw_set_transform(head, a)
	draw_rect(Rect2(-HEAD / 2.0, HEAD), Color(0.22, 0.23, 0.27))
	draw_rect(Rect2(-HEAD / 2.0 + Vector2(2, 2), HEAD - Vector2(4, 12)), Color(0.4, 0.42, 0.47))
	draw_set_transform(Vector2.ZERO)
