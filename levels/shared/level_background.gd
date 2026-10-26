extends CanvasLayer
## Parallax city background drawn behind the level (CC0 art by Ansimuz, see credits/ASSETS.md).
## Layers are scaled by a whole number so they fill the screen height with crisp pixels,
## stay put vertically (tall levels never run out of background) and scroll horizontally
## slower than the camera, far layers slowest.

const SETS := {
	"city_skyline": ["back.png", "buildings.png", "front.png"],
	"neon_night": ["far_buildings.png", "back_buildings.png", "foreground.png"],
	"neon_street": ["back.png", "middle.png", "foreground.png"],
	"intro_pixel": ["background.png"], # downscaled assets/art/intro/background.png
}
## Horizontal scroll per layer as a fraction of camera movement (far -> near).
const SCROLL := [0.04, 0.12, 0.25]

@export_enum("city_skyline", "neon_night", "neon_street", "intro_pixel") var art := "city_skyline"
@export var tint := Color.WHITE

var _layers: Array[TextureRect] = []
var _pixel := 1.0


func _ready() -> void:
	layer = -10
	for file: String in SETS[art]:
		var rect := TextureRect.new()
		rect.texture = load("res://assets/art/backgrounds/%s/%s" % [art, file])
		rect.stretch_mode = TextureRect.STRETCH_TILE
		rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		rect.modulate = tint
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(rect)
		_layers.append(rect)
	get_viewport().size_changed.connect(_fit)
	_fit()


## Size every layer to the screen: whole-number pixel scale that covers the height, bottoms aligned.
func _fit() -> void:
	var view := get_viewport().get_visible_rect().size
	var art_height := float(_layers[0].texture.get_height())
	_pixel = ceilf(view.y / art_height)
	for rect in _layers:
		var tile_w := rect.texture.get_width() * _pixel
		rect.scale = Vector2(_pixel, _pixel)
		rect.size = Vector2(ceilf(view.x / tile_w + 1.0) * rect.texture.get_width(), art_height)
		rect.position.y = view.y - art_height * _pixel


func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return
	var zoom := camera.zoom.x
	for i in _layers.size():
		var tile_w := _layers[i].texture.get_width() * _pixel
		# screen-space shift = world camera x * zoom * parallax factor, wrapped to one tile
		_layers[i].position.x = -fposmod(camera.get_screen_center_position().x * zoom * SCROLL[i], tile_w)
