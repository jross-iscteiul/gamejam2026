extends MachineDrawing
## Draws the higher-or-lower table: previous cards small on the left, the
## current card big in the middle and a face-down "next" card on the right.

const RANKS := ["", "A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]
const CARD := Vector2(52, 74)
const SMALL := Vector2(26, 37)

var cards: Array[int] = []:
	set(value):
		cards = value
		queue_redraw()
## Show the face-down card to the right (a round is running).
var show_next: bool = false:
	set(value):
		show_next = value
		queue_redraw()
## Color of the current card's border (yellow on a win, red on a loss).
var accent: Color = YELLOW:
	set(value):
		accent = value
		queue_redraw()
## 0..1 flip progress of the newest card (animation).
var flip: float = 1.0:
	set(value):
		flip = value
		queue_redraw()


func _draw() -> void:
	# Green felt.
	var felt := Rect2(-150, -56, 300, 112)
	draw_rect(felt.grow(2), OUTLINE)
	draw_rect(felt, Color("1f5a3c"))
	draw_rect(felt.grow(-4), Color("246b47"), false, 1.0)

	if cards.is_empty():
		_draw_back(Vector2.ZERO, CARD, "DEAL")
		return

	# History (last 3), oldest left.
	var history := cards.slice(maxi(0, cards.size() - 4), cards.size() - 1)
	for i in history.size():
		var pos := Vector2(-140 + i * 24, -18) + SMALL / 2.0
		_draw_card(pos, SMALL, history[i], STEEL_LIGHT, 1.0)

	_draw_card(Vector2.ZERO, CARD, cards.back(), accent, flip)
	if show_next:
		_draw_back(Vector2(96, 0), CARD * 0.8, "?")


func _draw_card(center: Vector2, size: Vector2, rank: int, border: Color, squash: float) -> void:
	var w := size.x * maxf(squash, 0.05)
	var rect := Rect2(center - Vector2(w, size.y) / 2.0, Vector2(w, size.y))
	draw_rect(rect.grow(2), OUTLINE)
	draw_rect(rect.grow(1), border)
	draw_rect(rect, Color("f4f1e6"))
	if squash < 0.5:
		return
	var red := rank % 2 == 1
	var ink := RED if red else OUTLINE
	var font := PixelFont.get_font()
	var big := size.x >= CARD.x
	var font_size := TEXT_SIZE * (2 if big else 1)
	draw_string(font, Vector2(rect.position.x, center.y + font_size * 0.5), RANKS[rank],
		HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, font_size, ink)
	# Corner pip (diamond for red, spade-ish triangle for black).
	var c := rect.position + Vector2(7, 8) if big else rect.position + Vector2(5, 6)
	var r := 4.0 if big else 2.5
	if red:
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)]), ink)
	else:
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, r), c + Vector2(-r, r)]), ink)


func _draw_back(center: Vector2, size: Vector2, text: String) -> void:
	var rect := Rect2(center - size / 2.0, size)
	draw_rect(rect.grow(2), OUTLINE)
	draw_rect(rect, STEEL_DARK)
	draw_rect(rect.grow(-4), ORANGE, false, 2.0)
	draw_small_string(Vector2(rect.position.x, center.y + 3), text, YELLOW, rect.size.x,
		HORIZONTAL_ALIGNMENT_CENTER, 0.0, OUTLINE)
