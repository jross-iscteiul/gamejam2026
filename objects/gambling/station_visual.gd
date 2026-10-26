extends MachineDrawing
## Placeholder art for the gambling cabinet, in the industrial tileset style.
## Sized for 32x32 tiles: about 1 tile wide, 1.75 tiles tall. Origin is at the feet.

## Off: beacon goes dark red and the screen shows an X.
var offline: bool = false

var _time := 0.0


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	# Body.
	var body := Rect2(-14, -42, 28, 42)
	draw_rect(body.grow(2), OUTLINE)
	draw_rect(body, STEEL)
	draw_rect(Rect2(body.position, Vector2(2, body.size.y)), STEEL_LIGHT)
	draw_rect(Rect2(body.end.x - 4, body.position.y, 4, body.size.y), STEEL_DARK)

	# Orange top cap, like the tileset's platform tops.
	var cap := Rect2(-17, -48, 34, 6)
	draw_rect(cap.grow(2), OUTLINE)
	draw_rect(cap, ORANGE)
	draw_rect(Rect2(cap.position, Vector2(cap.size.x, 2)), YELLOW)

	# Screen with a tiny spinning wheel.
	var screen := Rect2(-10, -38, 20, 14)
	draw_rect(screen.grow(2), OUTLINE)
	draw_rect(screen, CRT_BG)
	var c := screen.get_center()
	if offline:
		var red := Color(RED, 0.6 + 0.4 * sin(_time * 6.0))
		draw_line(c + Vector2(-4, -4), c + Vector2(4, 4), red, 2.0)
		draw_line(c + Vector2(4, -4), c + Vector2(-4, 4), red, 2.0)
	else:
		var colors: Array[Color] = [YELLOW, TEAL, RED, ORANGE]
		for k in 4:
			draw_line(c, c + Vector2.from_angle(_time * 2.0 + k * PI / 2.0) * 6.0, colors[k], 2.0)
		draw_rect(Rect2(c - Vector2(1, 1), Vector2(2, 2)), Color.WHITE)

	# Coin slot.
	draw_rect(Rect2(-6, -19, 12, 4), OUTLINE)
	draw_rect(Rect2(-4, -18, 8, 2), YELLOW)

	# Lever on the right.
	draw_line(Vector2(15, -22), Vector2(20, -32), OUTLINE, 2.0)
	draw_rect(Rect2(17, -37, 6, 6), OUTLINE)
	draw_rect(Rect2(18, -36, 4, 4), RED)

	# Hazard stripes at the base.
	draw_hazard(Rect2(-14, -8, 28, 6), 4.0)

	# Beacon.
	draw_rect(Rect2(-2, -53, 4, 5), OUTLINE)
	var on := not offline and fmod(_time, 1.0) < 0.5
	var lamp := YELLOW if on else (RED.darkened(0.5) if offline else ORANGE_DARK)
	if on:
		draw_circle(Vector2(0, -56), 6.0, Color(YELLOW, 0.25))
	draw_rect(Rect2(-4, -60, 8, 7), OUTLINE)
	draw_rect(Rect2(-3, -59, 6, 5), lamp)
