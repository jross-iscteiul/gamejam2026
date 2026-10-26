class_name PixelFont
extends RefCounted
## Crisp copy of the team pixel font (Package 3, ui/shared/press_start_2p.ttf)
## for text drawn inside scaled canvases (zoom 3 camera, 3x UI layers).
##
## Press Start 2P is an 8 px font. This copy always renders at 8 px without
## antialiasing and only scales by whole numbers, so glyph pixels stay sharp.
## Use size 8 (or 16, 24...) in the scaled space.

const SOURCE := preload("res://ui/shared/press_start_2p.ttf")
const SIZE := 8

static var _font: FontFile


static func get_font() -> FontFile:
	if _font == null:
		_font = SOURCE.duplicate()
		_font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		_font.hinting = TextServer.HINTING_NONE
		_font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
		_font.fixed_size = SIZE
		_font.fixed_size_scale_mode = TextServer.FIXED_SIZE_SCALE_INTEGER_ONLY
	return _font
