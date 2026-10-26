extends MachineDrawing
## Draws the rotating part of the wheel: bold colored segments with bevels and
## black outlines. Slice i is centered at angle i * step (local space).

@export var radius: float = 84.0
@export var inner_radius: float = 20.0

var slices: Array = []:
	set(value):
		slices = value
		queue_redraw()
## Slice to highlight (-1 = none). Used to blink the result.
var highlight_index: int = -1:
	set(value):
		highlight_index = value
		queue_redraw()
var highlight_on: bool = false:
	set(value):
		highlight_on = value
		queue_redraw()

var _drawn_rotation := INF


func _process(_delta: float) -> void:
	# Labels flip depending on rotation, so redraw while the wheel moves.
	if not is_equal_approx(rotation, _drawn_rotation):
		_drawn_rotation = rotation
		queue_redraw()


func get_step() -> float:
	return TAU / maxi(slices.size(), 1)


func _draw() -> void:
	if slices.is_empty():
		return
	var step := get_step()

	draw_circle(Vector2.ZERO, radius + 1.0, OUTLINE)
	for i in slices.size():
		var slice: Dictionary = slices[i]
		var color: Color = slice.color
		if i == highlight_index and highlight_on:
			color = color.lightened(0.45)
		var start := i * step - step / 2.0
		_ring_segment(inner_radius, radius, start, step, color.darkened(0.1))
		_ring_segment(radius - 7.0, radius - 2.0, start, step, color.lightened(0.25))
		_ring_segment(inner_radius, inner_radius + 7.0, start, step, color.darkened(0.4))

	for i in slices.size():
		var start := i * step - step / 2.0
		draw_line(Vector2.from_angle(start) * inner_radius, Vector2.from_angle(start) * radius, OUTLINE, 2.0)

	# Labels: 8 px pixel font at 2/3 scale, so up to 10 characters fit.
	var text_start := inner_radius + 6.0
	var text_width := radius - 4.0 - text_start
	var baseline := TEXT_SIZE * SMALL_TEXT * 0.5
	for i in slices.size():
		var slice: Dictionary = slices[i]
		var angle := i * step
		var pos := Vector2(text_start, baseline)
		var align := HORIZONTAL_ALIGNMENT_LEFT
		# Keep labels upright: flip the ones currently pointing left on screen.
		if cos(rotation + angle) < 0.0:
			angle += PI
			pos = Vector2(-(radius - 4.0), baseline)
			align = HORIZONTAL_ALIGNMENT_RIGHT
		draw_small_string(pos, slice.label, Color.WHITE, text_width, align, angle, OUTLINE)


func _ring_segment(r0: float, r1: float, start: float, sweep: float, color: Color) -> void:
	var points := PackedVector2Array()
	var steps := 10
	for k in steps + 1:
		points.append(Vector2.from_angle(start + sweep * k / steps) * r1)
	for k in range(steps, -1, -1):
		points.append(Vector2.from_angle(start + sweep * k / steps) * r0)
	draw_colored_polygon(points, color)
