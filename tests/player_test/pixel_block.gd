@tool
extends Control
## Test-scene block in the character art style: black outline, lit top-left edges, shaded bottom-right.

@export var color: Color = Color(0.35, 0.37, 0.45):
	set(value):
		color = value
		queue_redraw()
## Distance between panel seams in pixels; 0 disables them.
@export var seam_spacing: int = 0:
	set(value):
		seam_spacing = value
		queue_redraw()


func _draw() -> void:
	var light := color.lightened(0.25)
	var dark := color.darkened(0.35)
	draw_rect(Rect2(Vector2.ZERO, size), Color.BLACK)
	var inner := Rect2(Vector2.ONE, size - Vector2(2, 2))
	draw_rect(inner, color)

	if seam_spacing > 0:
		var x := inner.position.x + seam_spacing
		while x < inner.end.x - 2:
			draw_rect(Rect2(x, inner.position.y, 1, inner.size.y), dark)
			draw_rect(Rect2(x + 1, inner.position.y, 1, inner.size.y), light)
			x += seam_spacing

	draw_rect(Rect2(inner.position.x, inner.end.y - 2, inner.size.x, 2), dark)
	draw_rect(Rect2(inner.end.x - 1, inner.position.y, 1, inner.size.y), dark)
	draw_rect(Rect2(inner.position, Vector2(inner.size.x, 1)), color.lightened(0.45))
	draw_rect(Rect2(inner.position, Vector2(1, inner.size.y - 2)), light)
