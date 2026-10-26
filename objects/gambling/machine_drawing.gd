class_name MachineDrawing
extends Node2D
## Shared colors for the gambling machine, matched to the industrial tileset
## (steel-blue panels, black outlines, orange/yellow accents).

const OUTLINE := Color("0d0f1a")
const STEEL_DARK := Color("2a3a5c")
const STEEL := Color("3f5f8f")
const STEEL_MID := Color("6f93c4")
const STEEL_LIGHT := Color("9fc0e8")
const HIGHLIGHT := Color("d8ecff")
const YELLOW := Color("ffd23f")
const YELLOW_LIGHT := Color("fff3a0")
const ORANGE := Color("ff8a1f")
const ORANGE_DARK := Color("6b3410")
const RED := Color("e8402a")
const TEAL := Color("2bbfa0")
const CRT_BG := Color("0a1612")
const CRT_GREEN := Color("6dff8a")
## Text drawn in the 3x-scaled machine canvas: size 8 = 24 screen px.
## Draw with draw_small_string for 16 screen px.
const TEXT_SIZE := PixelFont.SIZE
## Scale that turns 8 px text into 16 screen px when the canvas is scaled 3x.
const SMALL_TEXT := 2.0 / 3.0


## Draws 8 px pixel text at 2/3 scale (16 screen px under a 3x canvas), with
## an optional outline. [param pos] is the baseline-left in the space rotated
## by [param angle] around this node's origin.
func draw_small_string(pos: Vector2, text: String, color: Color, width: float = -1.0,
		align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, angle: float = 0.0,
		outline: Color = Color(0, 0, 0, 0)) -> void:
	var font := PixelFont.get_font()
	var s := SMALL_TEXT
	draw_set_transform(Vector2.ZERO, angle, Vector2(s, s))
	var p := pos / s
	var w := width / s if width > 0.0 else -1.0
	if outline.a > 0.0:
		draw_string_outline(font, p, text, align, w, TEXT_SIZE, 3, outline)
	draw_string(font, p, text, align, w, TEXT_SIZE, color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Draws diagonal black/yellow hazard stripes inside [param rect].
func draw_hazard(rect: Rect2, stripe: float = 6.0) -> void:
	draw_rect(rect.grow(1), OUTLINE)
	draw_rect(rect, YELLOW)
	var clip := PackedVector2Array([
		rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y),
	])
	var h := rect.size.y
	var x := rect.position.x - h
	while x < rect.end.x:
		var band := PackedVector2Array([
			Vector2(x, rect.end.y), Vector2(x + h, rect.position.y),
			Vector2(x + h + stripe, rect.position.y), Vector2(x + stripe, rect.end.y),
		])
		for piece: PackedVector2Array in Geometry2D.intersect_polygons(band, clip):
			draw_colored_polygon(piece, OUTLINE)
		x += stripe * 2.0


func draw_rivet(pos: Vector2) -> void:
	draw_circle(pos, 3.0, OUTLINE)
	draw_circle(pos, 2.0, STEEL_LIGHT)
	draw_rect(Rect2(pos - Vector2(1, 1), Vector2(1, 1)), HIGHLIGHT)


## Beveled steel plate with a black outline.
func draw_plate(rect: Rect2, color: Color = STEEL) -> void:
	draw_rect(rect.grow(2), OUTLINE)
	draw_rect(rect, color)
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, 2)), color.lightened(0.35))
	draw_rect(Rect2(rect.position, Vector2(2, rect.size.y)), color.lightened(0.35))
	draw_rect(Rect2(rect.position + Vector2(0, rect.size.y - 2), Vector2(rect.size.x, 2)), color.darkened(0.35))
	draw_rect(Rect2(rect.position + Vector2(rect.size.x - 2, 0), Vector2(2, rect.size.y)), color.darkened(0.35))
