extends SceneTree
## Generates JARVIS's original pixel-art drone sprites from the ASCII maps below.
## Palette matches the industrial robot enemy so JARVIS fits the same world.
## Run:  godot --headless --path . -s res://assets/jarvis/generate_jarvis_sprites.gd
## Writes body.png (rotor + thruster animation frames) and faces.png (one face per frame,
## drawn on the body's screen). Edit the maps, re-run, commit the PNGs.

const OUT_DIR := "res://assets/jarvis/"
const FRAME := 32

const PALETTE := {
	".": Color(0, 0, 0, 0),
	"o": Color("2b022a"), # outline
	"y": Color("ffe119"), # body
	"r": Color("ff6d05"), # body shade
	"R": Color("ff0000"), # body deep shade
	"w": Color("ffffff"), # highlight
	"l": Color("a9c1cb"), # metal light
	"m": Color("537b8a"), # metal
	"d": Color("3a5661"), # metal dark
	"k": Color("112d38"), # screen
	"c": Color("0cffeb"), # eye
	"g": Color("00524b"), # eye shade (normal)
	"h": Color("5dff6b"), # happy eye
	"H": Color("1f7a2c"), # happy eye shade
	"a": Color("ffa31a"), # annoyed eye
	"f": Color("ff2a2a"), # furious eye
}

## Shell: rows 0..31, facing right (screen on the right). Rotor rows are added per frame.
const BODY := [
	"................................",
	"................................",
	"................................",
	"................................",
	"................................",
	"................................",
	"................................",
	"..............ooooo.............",
	"...............omo..............",
	"...............omo..............",
	"..........oooooooooooo..........",
	".........oywwyyyyyyyyyo.........",
	"........oywyyyyyyyyyyyyo........",
	".......oyyyyoooooooooooyo.......",
	".....o.oyyyyokkkkkkkkkoyo.......",
	"....omoryyyyokkkkkkkkkoyro......",
	"....olmryyyyokkkkkkkkkoyro......",
	"....omoryyyyokkkkkkkkkoyro......",
	".....ooRryyyokkkkkkkkkoyRo......",
	".......oRryyoooooooooooRo.......",
	".......odlllllllllllllldo.......",
	"........odmmmmmmmmmmmmdo........",
	".........oooooooooooooo.........",
	"............olllllo.............",
	"............omdddmo.............",
	".............ooooo..............",
	"................................",
	"................................",
	"................................",
	"................................",
	"................................",
	"................................",
]

## Rotor blade half-lengths per frame (spinning blade seen from the side) and thruster flame.
const ROTOR_HALF := [11, 6, 2, 6]
const FLAME := [
	["..............oRo..............", ".............................."],
	["..............oyo..............", "...............o..............."],
	["..............oRo..............", ".............................."],
	["..............oro..............", "...............o..............."],
]

## Faces drawn inside the screen (screen interior is x 13..21, y 14..18). Same size frames.
const FACES := {
	"neutral": [
		".........",
		"......cc.",
		"......wc.",
		"......cg.",
		".........",
	],
	"blink": [
		".........",
		".........",
		"......cc.",
		".........",
		".........",
	],
	"happy": [ # green, curved up like a smiling eye
		".........",
		"......hh.",
		".....h..h",
		".........",
		".........",
	],
	"annoyed": [ # orange, narrowed squint
		".........",
		".........",
		"......aaa",
		"......waa",
		".........",
	],
	"furious": [ # red, bigger eye under a brow slanting down toward the front
		"....f....",
		".....ff..",
		"......fff",
		"......wff",
		"......fff",
	],
}
const FACE_ORIGIN := Vector2i(13, 14)


func _init() -> void:
	var body := Image.create(FRAME * ROTOR_HALF.size(), FRAME, false, Image.FORMAT_RGBA8)
	for f in ROTOR_HALF.size():
		_paint(body, BODY, Vector2i(f * FRAME, 0))
		_rotor(body, f * FRAME, ROTOR_HALF[f])
		_paint(body, FLAME[f], Vector2i(f * FRAME, 26))
	body.save_png(OUT_DIR + "body.png")
	var names := FACES.keys()
	var faces := Image.create(FRAME * names.size(), FRAME, false, Image.FORMAT_RGBA8)
	for i in names.size():
		_paint(faces, FACES[names[i]], Vector2i(i * FRAME, 0) + FACE_ORIGIN)
	faces.save_png(OUT_DIR + "faces.png")
	print("JARVIS sprites written: body frames %d, faces %s" % [ROTOR_HALF.size(), names])
	quit()


## Blade: outline row, metal row with highlight, outline row, centred on the mast (x 16).
func _rotor(image: Image, x0: int, half: int) -> void:
	for x in range(16 - half, 16 + half + 1):
		image.set_pixel(x0 + x, 4, PALETTE["o"])
		image.set_pixel(x0 + x, 5, PALETTE["l"] if absi(x - 16) > 1 else PALETTE["m"])
		image.set_pixel(x0 + x, 6, PALETTE["o"])
	image.set_pixel(x0 + 16 - half - 1, 5, PALETTE["o"])
	image.set_pixel(x0 + 16 + half + 1, 5, PALETTE["o"])
	if half > 3:
		image.set_pixel(x0 + 16 + half - 1, 5, PALETTE["w"])


func _paint(image: Image, rows: Array, at: Vector2i) -> void:
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			var key := row[x]
			if key != "." and PALETTE.has(key):
				image.set_pixel(at.x + x, at.y + y, PALETTE[key])
