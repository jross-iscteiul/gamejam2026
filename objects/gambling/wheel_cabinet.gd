extends MachineDrawing
## The machine around the wheel: steel panel, rivets, title plate, pipes,
## an "odds" gauge that drifts towards RIGGED, a CRT screen and hazard stripes.

@export var panel: Rect2 = Rect2(112, 6, 416, 346)
@export var screen: Rect2 = Rect2(140, 250, 360, 72)
@export var wheel_center: Vector2 = Vector2(320, 142)
@export var title: String = "J.A.R.V.I.S. PROBABILITY ENGINE"

## Higher level = gauge needle closer to RIGGED.
var level: int = 1

var _time := 0.0


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	draw_plate(panel)
	for p: Vector2 in [
		panel.position + Vector2(8, 8),
		Vector2(panel.end.x - 8, panel.position.y + 8),
		Vector2(panel.position.x + 8, panel.end.y - 26),
		Vector2(panel.end.x - 8, panel.end.y - 26),
	]:
		draw_rivet(p)

	# Dark recess behind the wheel.
	draw_circle(wheel_center, 104.0, STEEL_DARK)
	draw_arc(wheel_center, 104.0, 0.0, TAU, 72, OUTLINE, 2.0)

	_draw_title()
	_draw_pipe(Rect2(panel.position.x + 16, 46, 12, 190))
	_draw_pipe(Rect2(panel.position.x + 34, 74, 12, 162))
	_draw_gauge(Vector2(panel.end.x - 50, 112))
	_draw_screen()
	draw_hazard(Rect2(panel.position.x + 4, panel.end.y - 14, panel.size.x - 8, 10))


func _draw_title() -> void:
	var font := PixelFont.get_font()
	var plate := Rect2(wheel_center.x - 150, panel.position.y + 8, 300, 16)
	draw_rect(plate.grow(2), OUTLINE)
	draw_rect(plate, YELLOW)
	draw_rect(Rect2(plate.position, Vector2(plate.size.x, 2)), YELLOW_LIGHT)
	draw_rect(Rect2(plate.position + Vector2(0, plate.size.y - 2), Vector2(plate.size.x, 2)), ORANGE)
	draw_string(font, plate.position + Vector2(0, 12), title, HORIZONTAL_ALIGNMENT_CENTER, plate.size.x, TEXT_SIZE, OUTLINE)


func _draw_pipe(rect: Rect2) -> void:
	draw_rect(rect.grow(1), OUTLINE)
	draw_rect(rect, STEEL_MID)
	draw_rect(Rect2(rect.position + Vector2(2, 0), Vector2(2, rect.size.y)), HIGHLIGHT)
	draw_rect(Rect2(rect.position + Vector2(rect.size.x - 3, 0), Vector2(3, rect.size.y)), STEEL_DARK)
	var y := rect.position.y + 24.0
	while y < rect.end.y - 12.0:
		var band := Rect2(rect.position.x, y, rect.size.x, 5)
		draw_rect(band.grow(1), OUTLINE)
		draw_rect(band, ORANGE)
		draw_rect(Rect2(band.position, Vector2(band.size.x, 1)), YELLOW)
		y += 44.0
	for end_y: float in [rect.position.y - 3.0, rect.end.y - 3.0]:
		var flange := Rect2(rect.position.x - 2, end_y, rect.size.x + 4, 6)
		draw_rect(flange.grow(1), OUTLINE)
		draw_rect(flange, STEEL_LIGHT)


func _draw_gauge(center: Vector2) -> void:
	var r := 28.0
	draw_small_string(center + Vector2(-r, -r - 8), "ODDS", YELLOW, r * 2, HORIZONTAL_ALIGNMENT_CENTER, 0.0, OUTLINE)
	draw_circle(center, r + 3.0, OUTLINE)
	draw_circle(center, r + 1.0, STEEL_LIGHT)
	draw_circle(center, r - 1.0, Color("e8e4d0"))

	var start := PI * 0.75
	var sweep := PI * 1.5
	draw_arc(center, r - 5.0, start, start + sweep * 0.4, 16, TEAL, 4.0)
	draw_arc(center, r - 5.0, start + sweep * 0.4, start + sweep * 0.7, 12, YELLOW, 4.0)
	draw_arc(center, r - 5.0, start + sweep * 0.7, start + sweep, 12, RED, 4.0)

	draw_small_string(center + Vector2(-r - 12, r + 14), "FAIR", HIGHLIGHT, -1.0, HORIZONTAL_ALIGNMENT_LEFT, 0.0, OUTLINE)
	draw_small_string(center + Vector2(r - 20, r + 14), "RIGGED", HIGHLIGHT, -1.0, HORIZONTAL_ALIGNMENT_LEFT, 0.0, OUTLINE)

	var value := clampf(0.3 + level * 0.15 + sin(_time * 3.0) * 0.04, 0.0, 1.0)
	var tip := center + Vector2.from_angle(start + sweep * value) * (r - 6.0)
	draw_line(center, tip, RED, 2.0)
	draw_circle(center, 3.0, OUTLINE)


func _draw_screen() -> void:
	draw_rect(screen.grow(6), OUTLINE)
	draw_rect(screen.grow(4), STEEL_DARK)
	draw_rect(Rect2(screen.position - Vector2(4, 4), Vector2(screen.size.x + 8, 2)), STEEL)
	draw_rect(screen.grow(1), OUTLINE)
	draw_rect(screen, CRT_BG)
	var y := screen.position.y + 1.0
	while y < screen.end.y:
		draw_line(Vector2(screen.position.x, y), Vector2(screen.end.x, y), Color(0, 0, 0, 0.35), 1.0)
		y += 2.0
