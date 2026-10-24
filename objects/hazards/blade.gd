@tool
extends Hazard
## Spinning saw blade (1 HP). Fixed when `travel` is zero, otherwise eases back and forth
## between its origin and origin + travel, pausing at each end. The track is drawn as a line.

const RADIUS := 13.0
const TEETH := 10

@export var travel := Vector2.ZERO
@export var seconds_one_way := 2.5
@export var pause := 0.3
@export var spin_speed := 9.0

var _hitbox: Hitbox


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var circle := CircleShape2D.new()
	circle.radius = RADIUS - 2.0
	_hitbox = make_hitbox(circle)


## Saw offset from the origin at a given clock: pause, ease out, pause, ease back.
func offset_at(clock: float) -> Vector2:
	if travel == Vector2.ZERO:
		return Vector2.ZERO
	var move := seconds_one_way / difficulty
	var t := fposmod(clock, 2.0 * (move + pause))
	var f := 0.0
	if t < pause:
		f = 0.0
	elif t < pause + move:
		f = 0.5 - 0.5 * cos(PI * (t - pause) / move)
	elif t < 2.0 * pause + move:
		f = 1.0
	else:
		f = 0.5 + 0.5 * cos(PI * (t - 2.0 * pause - move) / move)
	return travel * f


func _physics_process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		_hitbox.position = offset_at(time)


func _draw() -> void:
	if travel != Vector2.ZERO:
		draw_line(Vector2.ZERO, travel, Color(0.15, 0.15, 0.18), 3.0)
		for p in [Vector2.ZERO, travel]:
			draw_circle(p, 3.0, Color(0.3, 0.3, 0.34))
	var at := offset_at(time)
	var spin := time * spin_speed * difficulty
	var teeth := PackedVector2Array()
	for i in TEETH * 2:
		var r := RADIUS if i % 2 == 0 else RADIUS - 4.0
		teeth.append(at + Vector2(r, 0).rotated(spin + i * PI / TEETH))
	draw_colored_polygon(teeth, Color(0.75, 0.78, 0.82))
	draw_circle(at, 5.0, Color(0.35, 0.36, 0.4))
	draw_circle(at, 2.0, Color(0.9, 0.2, 0.2))
