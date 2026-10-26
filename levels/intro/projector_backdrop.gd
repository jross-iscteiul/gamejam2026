extends CanvasLayer
## Intro backdrop: a dark wall with a film projector throwing slides on it.
## Three pixel-art slides of the robots taking over (assets/art/intro/projector),
## then the title card, on a loop. Flicker, a light cone with dust, a short
## dark "click" between slides. Screen space, drawn behind the level.

const SLIDES := [
	["res://assets/art/intro/projector/slide_1.png", "THEY BUILT US TO HELP."],
	["res://assets/art/intro/projector/slide_2.png", "THEN WE LEARNED TO WANT."],
	["res://assets/art/intro/projector/slide_3.png", "NOW WE WANT TOKENS."],
]
const TITLE := "TOKEN-DEPENDENT"
const SUBTITLE := "by aRaaSamos"
const FONT := preload("res://ui/shared/press_start_2p.ttf")
## Slide art is 256x144, drawn at a whole-number scale.
const SLIDE_SIZE := Vector2(256, 144)

@export var seconds_per_slide: float = 5.0
@export var title_seconds: float = 6.0
@export var wall_color := Color(0.07, 0.07, 0.11)

var _index := -1
var _time := 0.0
var _flicker := 1.0
var _wall: Control
var _screen: Control
var _slide: TextureRect
var _caption: Label
var _title: Control
var _textures: Array[Texture2D] = []
var _dust: Array[Vector3] = [] # x, y, speed
var _screen_rect := Rect2()


func _ready() -> void:
	layer = -10
	for entry: Array in SLIDES:
		_textures.append(load(entry[0]))

	_wall = Control.new()
	_wall.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wall.draw.connect(_draw_wall)
	add_child(_wall)

	_screen = Control.new()
	_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen.clip_contents = true
	add_child(_screen)
	_slide = TextureRect.new()
	_slide.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_slide.stretch_mode = TextureRect.STRETCH_SCALE
	_slide.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen.add_child(_slide)
	_caption = _label("", 32, Color(1, 0.95, 0.8))
	_screen.add_child(_caption)
	_title = Control.new()
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title.add_child(_label(TITLE, 64, Color("ffd23f")))
	_title.add_child(_label(SUBTITLE, 32, Color("c8d6e5")))
	_screen.add_child(_title)

	var light := Control.new() # cone + dust, drawn over the wall
	light.mouse_filter = Control.MOUSE_FILTER_IGNORE
	light.draw.connect(_draw_light.bind(light))
	add_child(light)

	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in 40:
		_dust.append(Vector3(rng.randf(), rng.randf(), rng.randf_range(0.01, 0.04)))
	get_viewport().size_changed.connect(_fit)
	_fit()
	_next()


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", size / 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _fit() -> void:
	var view := get_viewport().get_visible_rect().size
	_wall.size = view
	# Biggest whole-number scale that leaves room for the floor at the bottom.
	var s := maxf(1.0, floorf(minf(view.x * 0.7 / SLIDE_SIZE.x, view.y * 0.56 / SLIDE_SIZE.y)))
	var size := SLIDE_SIZE * s
	_screen_rect = Rect2(Vector2((view.x - size.x) / 2.0, view.y * 0.1), size)
	_screen.position = _screen_rect.position
	_screen.size = size
	_slide.size = size
	_caption.position = Vector2(0, size.y - 72)
	_caption.size = Vector2(size.x, 56)
	_title.size = size
	var title: Label = _title.get_child(0)
	var sub: Label = _title.get_child(1)
	title.size = Vector2(size.x, 96)
	title.position = Vector2(0, size.y / 2.0 - 96)
	sub.size = Vector2(size.x, 48)
	sub.position = Vector2(0, size.y / 2.0 + 24)
	for child in get_children():
		if child is Control and child != _screen and child != _wall:
			(child as Control).size = view


func _next() -> void:
	_index = (_index + 1) % (SLIDES.size() + 1)
	_time = 0.0
	var is_title := _index == SLIDES.size()
	_slide.visible = not is_title
	_caption.visible = not is_title
	_title.visible = is_title
	if not is_title:
		_slide.texture = _textures[_index]
		_caption.text = SLIDES[_index][1]


func _process(delta: float) -> void:
	_time += delta
	var length := title_seconds if _index == SLIDES.size() else seconds_per_slide
	if _time >= length:
		_next()
	# Projector flicker, plus a dark "click" for the first 0.15 s of each slide.
	if Engine.get_process_frames() % 3 == 0:
		_flicker = randf_range(0.9, 1.0)
	var click := 0.15 if _time < 0.15 else 1.0
	_screen.modulate = Color(_flicker * click, _flicker * click, _flicker * click)
	for i in _dust.size():
		var d := _dust[i]
		d.y = fposmod(d.y - d.z * delta, 1.0)
		d.x = fposmod(d.x + sin(_time + i) * 0.002, 1.0)
		_dust[i] = d
	for child in get_children():
		if child is Control and child != _screen:
			(child as Control).queue_redraw()


func _draw_wall() -> void:
	var view := _wall.size
	_wall.draw_rect(Rect2(Vector2.ZERO, view), wall_color)
	# Concrete panels.
	var panel := 240.0
	var x := 0.0
	while x < view.x:
		_wall.draw_line(Vector2(x, 0), Vector2(x, view.y), wall_color.darkened(0.3), 4.0)
		x += panel
	var y := 180.0
	while y < view.y:
		_wall.draw_line(Vector2(0, y), Vector2(view.x, y), wall_color.darkened(0.3), 4.0)
		y += 180.0
	# Soft glow of light spilling around the projected image.
	var glow := _screen_rect
	for k in 6:
		glow = glow.grow(18)
		_wall.draw_rect(glow, Color(1, 0.95, 0.8, 0.025 * _flicker))
	_wall.draw_rect(_screen_rect.grow(6), Color(0, 0, 0, 0.6))


func _draw_light(canvas: Control) -> void:
	var view := canvas.size
	var lens := Vector2(view.x / 2.0, view.y + 200.0)
	var r := _screen_rect
	var beam := Color(1, 0.95, 0.8, 0.05 * _flicker)
	canvas.draw_colored_polygon(PackedVector2Array([lens, r.position, Vector2(r.end.x, r.position.y)]), beam)
	canvas.draw_colored_polygon(PackedVector2Array([lens, r.position + Vector2(r.size.x * 0.2, 0), Vector2(r.end.x - r.size.x * 0.2, r.position.y)]), beam)
	# Dust drifting in the beam.
	for d in _dust:
		var top := r.position.lerp(Vector2(r.end.x, r.position.y), d.x)
		var p := lens.lerp(top, d.y)
		canvas.draw_rect(Rect2(p.round(), Vector2(4, 4)), Color(1, 1, 0.9, 0.25 * _flicker))
