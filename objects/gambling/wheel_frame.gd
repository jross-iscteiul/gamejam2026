extends MachineDrawing
## Static part of the wheel, drawn on top of it: steel ring with chasing bulbs,
## the yellow pointer and a bolted hub with JARVIS's lens (it watches, it doesn't spin).

@export var radius: float = 84.0
@export var bulb_count: int = 16

## Faster bulb chase while spinning.
var spinning: bool = false
## Lens color: teal idle, yellow on wins, red on trolls.
var eye_color: Color = TEAL

var _time := 0.0
var _phase := 0.0


func _process(delta: float) -> void:
	_time += delta
	_phase += delta * (20.0 if spinning else 3.0)
	queue_redraw()


func _draw() -> void:
	var outer := radius + 14.0

	# Steel ring with bevel.
	draw_arc(Vector2.ZERO, radius + 7.0, 0.0, TAU, 72, STEEL, 14.0)
	draw_arc(Vector2.ZERO, outer - 3.0, PI * 0.85, PI * 1.65, 24, STEEL_LIGHT, 2.0)
	draw_arc(Vector2.ZERO, radius + 3.0, -PI * 0.15, PI * 0.65, 24, STEEL_DARK, 3.0)
	draw_arc(Vector2.ZERO, outer, 0.0, TAU, 72, OUTLINE, 2.0)
	draw_arc(Vector2.ZERO, radius + 1.0, 0.0, TAU, 72, OUTLINE, 2.0)

	# Bulbs.
	var head := int(_phase) % bulb_count
	for i in bulb_count:
		var angle := TAU * (i + 0.5) / bulb_count - PI / 2.0
		var pos := (Vector2.from_angle(angle) * (radius + 7.0)).round()
		var lit := (i % 4 == head % 4) if spinning else (i % 2 == head % 2)
		draw_circle(pos, 3.5, OUTLINE)
		if lit:
			draw_circle(pos, 5.0, Color(YELLOW, 0.25))
			draw_circle(pos, 2.5, YELLOW)
			draw_rect(Rect2(pos - Vector2(1, 1), Vector2(1, 1)), Color.WHITE)
		else:
			draw_circle(pos, 2.5, ORANGE_DARK)

	# Pointer: steel mount + yellow arrow.
	var top := -outer
	var mount := Rect2(-9, top - 8, 18, 8)
	draw_rect(mount.grow(1), OUTLINE)
	draw_rect(mount, STEEL_MID)
	draw_rect(Rect2(mount.position, Vector2(mount.size.x, 2)), HIGHLIGHT)
	var arrow := PackedVector2Array([Vector2(-8, top), Vector2(8, top), Vector2(0, top + 20)])
	draw_colored_polygon(arrow, YELLOW)
	draw_line(arrow[0] + Vector2(2, 1), arrow[2] + Vector2(0, -3), YELLOW_LIGHT, 2.0)
	draw_polyline(PackedVector2Array([arrow[0], arrow[1], arrow[2], arrow[0]]), OUTLINE, 2.0)

	# Bolted hub.
	draw_circle(Vector2.ZERO, inner_hub(), OUTLINE)
	draw_circle(Vector2.ZERO, inner_hub() - 2.0, STEEL)
	draw_arc(Vector2.ZERO, inner_hub() - 4.0, PI * 0.9, PI * 1.6, 12, STEEL_LIGHT, 2.0)
	for k in 4:
		draw_rivet((Vector2.from_angle(PI / 4.0 + k * PI / 2.0) * (inner_hub() - 5.0)).round())

	# JARVIS lens.
	draw_circle(Vector2.ZERO, 10.0, OUTLINE)
	draw_circle(Vector2.ZERO, 9.0, Color("1a0d10"))
	var pulse := 5.0 + sin(_time * 4.0)
	draw_circle(Vector2.ZERO, pulse + 2.0, Color(eye_color, 0.35))
	draw_circle(Vector2.ZERO, pulse, eye_color)
	draw_rect(Rect2(-3, -3, 2, 2), Color.WHITE)


func inner_hub() -> float:
	return 21.0
