extends Node2D
## JARVIS speech bubble, drawn in world space above him. Text types out, stays a moment, then
## hides. A new line replaces the current one. The border colour follows the mood.

signal finished # the line was fully shown and the bubble hid

@export var font: Font = preload("res://ui/shared/press_start_2p.ttf")
@export var font_size: int = 6
@export var max_text_width: float = 80.0
@export var padding: Vector2 = Vector2(4.0, 4.0)
@export var line_spacing: float = 2.0
@export var tail_size: float = 4.0
@export var chars_per_second: float = 40.0
@export var hold_seconds: float = 1.0 # after the line finishes typing
@export var hold_per_char: float = 0.01 # longer lines stay a bit longer
## Off: the line stays up until replaced or clear() (tap-through dialogue).
@export var auto_hide: bool = true
@export var background: Color = Color("131c2e")
@export var text_color: Color = Color("edf5ed")
## Border colour per mood; matches JARVIS's eye colours.
@export var mood_colors: Dictionary[String, Color] = {
	"neutral": Color("0cffeb"),
	"happy": Color("5dff6b"),
	"annoyed": Color("ffa31a"),
	"furious": Color("ff2a2a"),
	"offline": Color("6b7280"),
}

var text: String = ""
var mood: String = "neutral"
var _lines: PackedStringArray = []
var _shown: float = 0.0 # characters revealed (fractional while typing)
var _hold_left: float = 0.0


func _ready() -> void:
	hide()


## Shows a new line, replacing whatever is on screen.
func say(new_text: String, new_mood: String = "neutral") -> void:
	mood = new_mood
	_lines = _wrap(new_text.strip_edges())
	text = " ".join(_lines) # same characters the typewriter walks through
	_shown = 0.0
	_hold_left = hold_seconds + hold_per_char * text.length()
	visible = not text.is_empty()
	queue_redraw()


func is_talking() -> bool:
	return visible


func is_typing() -> bool:
	return visible and _shown < text.length()


## Reveals the rest of the line at once.
func skip_typing() -> void:
	_shown = text.length()
	queue_redraw()


func clear() -> void:
	hide()
	text = ""


func _process(delta: float) -> void:
	if not visible:
		return
	if _shown < text.length():
		_shown = minf(_shown + chars_per_second * delta, text.length())
		queue_redraw()
	elif auto_hide:
		_hold_left -= delta
		if _hold_left <= 0.0:
			clear()
			finished.emit()


func _draw() -> void:
	if text.is_empty():
		return
	# Draw in screen pixels and scale back down by the camera zoom, so glyphs are rasterized at
	# their on-screen size (8 px * zoom 3 = 24 px) instead of being blown up and blurred.
	var k := _render_scale()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE / k)
	var size_px := font_size * roundi(k)
	var pad := padding * k
	var tail := tail_size * k
	var line_height := font.get_height(size_px) + line_spacing * k
	var text_width := 0.0
	for line in _lines:
		text_width = maxf(text_width, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x)
	var box_size := Vector2(text_width, line_height * _lines.size() - line_spacing * k) + pad * 2.0
	# Bubble sits above the origin with its tail pointing down at JARVIS.
	var box := Rect2(Vector2(-box_size.x * 0.5, -box_size.y - tail), box_size)
	box.position = box.position.round()
	var border: Color = mood_colors.get(mood, mood_colors.get("neutral", Color.WHITE))
	draw_rect(box.grow(k), border)
	draw_rect(box, background)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-tail, box.end.y), Vector2(tail, box.end.y), Vector2(0.0, box.end.y + tail)]), border)
	# Typewriter: draw only the revealed characters, line by line.
	var left := int(_shown)
	var ascent := font.get_ascent(size_px)
	for i in _lines.size():
		if left <= 0:
			break
		var line := _lines[i]
		var part := line.substr(0, left)
		left -= line.length() + 1 # +1 for the space eaten by wrapping
		var at := (box.position + pad + Vector2(0.0, ascent + i * line_height)).round()
		draw_string(font, at, part, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, text_color)


## World-to-screen scale from the active camera (zoom 3 in levels); 1 without a camera.
func _render_scale() -> float:
	var camera := get_viewport().get_camera_2d() if is_inside_tree() else null
	return maxf(camera.zoom.x, 1.0) if camera else 1.0


## Greedy word wrap at max_text_width. Wrapping the whole line up front keeps words from
## jumping between lines while the text types out.
func _wrap(value: String) -> PackedStringArray:
	var lines: PackedStringArray = []
	var current := ""
	for word in value.split(" ", false):
		var candidate := word if current.is_empty() else current + " " + word
		if current.is_empty() or font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= max_text_width:
			current = candidate
		else:
			lines.append(current)
			current = word
	if not current.is_empty():
		lines.append(current)
	return lines
