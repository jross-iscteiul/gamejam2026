extends MachineDrawing
## The machine around the game: steel panel, rivets, title plate, pipes,
## the stake side panel and hazard stripes.

@export var panel: Rect2 = Rect2(112, 6, 416, 292)
@export var wheel_center: Vector2 = Vector2(320, 162)
## Show the dark recess behind the wheel (off in higher-or-lower mode).
var show_recess: bool = true
@export var title: String = "J.A.R.V.I.S. PROBABILITY ENGINE"

var level: int = 1

var _time := 0.0


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	# Side plate behind the stake controls.
	draw_plate(Rect2(530, 60, 108, 222))
	draw_plate(panel)
	for p: Vector2 in [
		panel.position + Vector2(8, 8),
		Vector2(panel.end.x - 8, panel.position.y + 8),
		Vector2(panel.position.x + 8, panel.end.y - 26),
		Vector2(panel.end.x - 8, panel.end.y - 26),
	]:
		draw_rivet(p)

	if show_recess:
		draw_circle(wheel_center, 104.0, STEEL_DARK)
		draw_arc(wheel_center, 104.0, 0.0, TAU, 72, OUTLINE, 2.0)

	_draw_title()
	_draw_pipe(Rect2(panel.position.x + 16, 66, 12, 190))
	_draw_pipe(Rect2(panel.position.x + 34, 94, 12, 162))
	draw_hazard(Rect2(panel.position.x + 4, panel.end.y - 14, panel.size.x - 8, 10))


func _draw_title() -> void:
	var font := PixelFont.get_font()
	var plate := Rect2(panel.get_center().x - 150, panel.position.y + 8, 300, 16)
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
