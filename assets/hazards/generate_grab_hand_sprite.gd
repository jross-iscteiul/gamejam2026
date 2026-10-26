extends SceneTree
## Generates the grab hand hazard's pixel-art sprites from the ASCII maps below.
## Blitzcrank-inspired steam-golem fist: chunky brass fingers on riveted hinges, a riveted wrist
## cuff and a rocket-grab chain. Palette matches the industrial robot enemy and JARVIS.
## Run:  godot --headless --path . -s res://assets/hazards/generate_grab_hand_sprite.gd
## Writes grab_hand.png: 3 frames (open, half closed, fist), each W x H, hand rows above the
## shared cuff; palm top centre at (32, 36) — grab_hand.gd anchors there.
## Writes grab_hand_chain.png: one chain tile, repeated downwards below the cuff in game.
## Edit the maps, re-run, commit the PNGs.

const OUT := "res://assets/hazards/grab_hand.png"
const OUT_CHAIN := "res://assets/hazards/grab_hand_chain.png"
const W := 64
const H := 64

const PALETTE := {
	".": Color(0, 0, 0, 0),
	"o": Color("2b022a"), # outline
	"y": Color("ffe119"), # brass
	"r": Color("ff6d05"), # brass shade
	"R": Color("ff0000"), # brass deep shade / rivets
	"w": Color("ffffff"), # highlight
	"l": Color("a9c1cb"), # metal light
	"m": Color("537b8a"), # metal
	"d": Color("3a5661"), # metal dark
	"k": Color("112d38"), # deep shadow
}

const OPEN := [
	"................................................................",
	"................................................................",
	".............................oooooo.............................",
	"............................owwwyyyo............................",
	"...........................owyyyyyyyo...........................",
	"..........................oywyyyyyyyro..........................",
	"..........................oywyyyyyyyro..........................",
	"...............oooooo.....oywyyyyyyyro.....oooooo...............",
	"..............owwwyyyo....oywyyyyyyyro....owwwyyyo..............",
	".............owyyyyyyyo...oywyyyyyyyro...owyyyyyyyo.............",
	"............oywyyyyyyyro..oywyyyyyyyro..oywyyyyyyyro............",
	"............oywyyyyyyyro..oywyyyyyyyro..oywyyyyyyyro............",
	"............oywyyyyyyyro..oywyyyyyyyro..oywyyyyyyyro............",
	"............oywyyyyyyyro..oooooooooooo..oywyyyyyyyro............",
	"............oywyyyyyyyro...ollllllldo...oywyyyyyyyro............",
	"............oywyyyyyyyro...ommmmmmmdo...oywyyyyyyyro............",
	"............oywyyyyyyyro..oooooooooooo..oywyyyyyyyro............",
	"............oooooooooooo..oywyyyyyyyro..oooooooooooo............",
	".............ollllllldo...oywyyyyyyyro...ollllllldo.............",
	".............ommmmmmmdo...oywyyyyyyyro...ommmmmmmdo.............",
	"............oooooooooooo..oyyyyyyyyyro..oooooooooooo............",
	"............oywyyyyyyyro..oyyyyyyyyyro..oywyyyyyyyro............",
	"....oooo....oywyyyyyyyro..oyyyyyyyyyro..oywyyyyyyyro............",
	"...owwyyo...oyyyyyyyyyro..oyyyyyyyyyro..oyyyyyyyyyro............",
	"..owyyyyyo..oyyyyyyyyyro..oyyyyyyyyyro..oyyyyyyyyyro............",
	".oywyyyyyro.oyyyyyyyyyro..oooooooooooo..oyyyyyyyyyro............",
	".oywyyyyyro.oyyyyyyyyyro...ollllllldo...oyyyyyyyyyro............",
	".oywyyyyyro.oooooooooooo...ommmmmmmdo...oooooooooooo............",
	".oywyyyyyro..ollllllldo...oooooooooooo...ollllllldo.............",
	".oywyyyyyro..ommmmmmmdo...oyyyyyyyyyro...ommmmmmmdo.............",
	".oywyyyyyro.oooooooooooo..oyyyyyyyyyro..oooooooooooo............",
	".oooooooooo.oyyyyyyyyyro..oyyyyyyyyyro..oyyyyyyyyyro............",
	"..ollllldo..oyyyyyyyyyro..oyyyyyyyyyro..oyyyyyyyyyro............",
	"..ommmmmdo..oyyyyyyyyyro..oyyyyyyyyyro..oyyyyyyyyyro............",
	".oooooooooo.oyyyyyyyyyro..oyyyyyyyyyro..oyyyyyyyyyro............",
	".oyyyyyyyro.oyyyyyyyyyro..oyyyyyyyyyro..oyyyyyyyyyro............",
	".oyyyyyyyro.oooooooooooooooooooooooooooooooooooooooo............",
	".oyyyyyyyroowwwwwwwwwwwwwwwwwwwwyyyyyyyyyyyyyyyyyyyyo...........",
	".oyyyyyyyroywyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyro..........",
	".oyyyyyyyroywyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyro..........",
	".oyyyyyyyroywyyRyyyyyyyRyyyyyyyyyyyyyyyyRyyyyyyyRyyyro..........",
	".oyyyyyyyroywyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyro..........",
	"..oyyyyyyooywyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyro..........",
	"...oRRRRo.oywyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyro..........",
	"....oooo..oywyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyro..........",
	"..........oywyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyro..........",
	"..........oywyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyro..........",
	"..........oyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyro..........",
	"..........oyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyro..........",
	"..........oyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyro..........",
	"..........oyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyro..........",
	"..........oyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyro..........",
	"..........oyyyyRyyyyyyyRyyyyyyyyyyyyyyyyRyyyyyyyRyyyro..........",
	"..........oyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyro..........",
	"...........oyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyo...........",
	"............oyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyo............",
	".............oRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRo.............",
	"..............oooooooooooooooooooooooooooooooooooo..............",
]

## Fingers bending toward the viewer: shorter, dark fingertip undersides on top.
const HALF := [
	"................................................................",
	"................................................................",
	"................................................................",
	"................................................................",
	"................................................................",
	"................................................................",
	"................................................................",
	"................................................................",
	"................................................................",
	"................................................................",
	"................................................................",
	"................................................................",
	"................................................................",
	"................................................................",
	"................................................................",
	".............................oooooo.............................",
	"............................owwwyyyo............................",
	"...........................owyyyyyyyo...........................",
	"..........................oykkkkkkkkro..........................",
	"...............oooooo.....oywyyyyyyyro.....oooooo...............",
	"..............owwwyyyo....oywyyyyyyyro....owwwyyyo..............",
	".............owyyyyyyyo...oooooooooooo...owyyyyyyyo.............",
	"............oykkkkkkkkro...ollllllldo...oykkkkkkkkro............",
	"............oywyyyyyyyro...ommmmmmmdo...oywyyyyyyyro............",
	"............oooooooooooo..oooooooooooo..oooooooooooo............",
	".............ollllllldo...oywyyyyyyyro...ollllllldo.............",
	".............ommmmmmmdo...oywyyyyyyyro...ommmmmmmdo.............",
	"............oooooooooooo..oyyyyyyyyyro..oooooooooooo............",
	"............oywyyyyyyyro..oyyyyyyyyyro..oywyyyyyyyro............",
	"............oyyyyyyyyyro..oooooooooooo..oyyyyyyyyyro............",
	".....oooo...oyyyyyyyyyro...ollllllldo...oyyyyyyyyyro............",
	"....owwyyo..oooooooooooo...ommmmmmmdo...oooooooooooo............",
	"...owyyyyyo..ollllllldo...oooooooooooo...ollllllldo.............",
	"..oywyyyyyro.ommmmmmmdo...oyyyyyyyyyro...ommmmmmmdo.............",
	"..oywyyyyyrooooooooooooo..oyyyyyyyyyro..oooooooooooo............",
	"..oywyyyyyrooyyyyyyyyyro..oyyyyyyyyyro..oyyyyyyyyyro............",
	"..oywyyyyyrooooooooooooooooooooooooooooooooooooooooo............",
	"..oooooooooowwwwwwwwwwwwwwwwwwwwyyyyyyyyyyyyyyyyyyyyo...........",
	"...ollllldoywyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyro..........",
	"...ommmmmdoywyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyro..........",
	"..oooooooooywyyRyyyyyyyRyyyyyyyyyyyyyyyyRyyyyyyyRyyyro..........",
	"..oyyyyyyyoywyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyro..........",
	"..oyyyyyyyoywyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyro..........",
	"..oyyyyyyyoywyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyro..........",
	"...oyyyyyyoywyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyro..........",
	"....oRRRRooywyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyro..........",
	".....oooo.oywyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyro..........",
	"..........oyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyro..........",
	"..........oyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyro..........",
	"..........oyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyro..........",
	"..........oyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyro..........",
	"..........oyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyro..........",
	"..........oyyyyRyyyyyyyRyyyyyyyyyyyyyyyyRyyyyyyyRyyyro..........",
	"..........oyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyro..........",
	"...........oyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyo...........",
	"............oyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyo............",
	".............oRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRo.............",
	"..............oooooooooooooooooooooooooooooooooooo..............",
]

## Raised robot fist seen from the palm side: knuckle caps on top, curled finger segments facing
## out with their tips tucked in, thumb wrapped across the first two fingers from the palm's side.
const FIST := [
	"................................................................",
	"................................................................",
	"................................................................",
	"................................................................",
	"................................................................",
	"................................................................",
	"................................................................",
	"................................................................",
	"................................................................",
	"................................................................",
	"................................................................",
	"................................................................",
	"................................................................",
	"................................................................",
	"................................................................",
	"................................................................",
	"................................................................",
	"................................................................",
	"................................................................",
	"................................................................",
	"................oooo..........oooo..........oooo................",
	"...............owwyyo........owwyyo........owwyyo...............",
	"..............oyyyyyyo......oyyyyyyo......oyyyyyyo..............",
	"............kowyyyyyyyokkkkowyyyyyyyokkkkowyyyyyyyok............",
	"............oywyyyyyyyrokkoywyyyyyyyrokkoywyyyyyyyro............",
	"............oywyyyyyyyrokkoywyyyyyyyrokkoywyyyyyyyro............",
	"............oywyyyyyyyrokkoywyyyyyyyrokkoywyyyyyyyro............",
	"............oywyyyyyyyrokkoywyyyyyyyrokkoywyyyyyyyro............",
	"............oywyyyyyyyrokkoywyyyyyyyrokkoywyyyyyyyro............",
	"............oywyyyyyyyrokkoywyyyyyyyrokkoywyyyyyyyro............",
	"............ooooooooooookkooooooooooookkoooooooooooo............",
	"............kollllllldokkkkollllllldokkkkollllllldok............",
	"............kommmmmmmdokkkkommmmmmmdokkkkommmmmmmdok............",
	"............ooooooooooookkooooooooooookkoooooooooooo............",
	"............oyyyyyyyyyrokkoyyyyyyyyyrokkoyyyyyyyyyro............",
	"............oyyyyyyyyyrokkoyyyyyyyyyrokkoyyyyyyyyyro............",
	"............oyyyyyyyyyrokkoyyyyyyyyyrokkoyyyyyyyyyro............",
	".........oooooooooooooooooooooooooooookkoyyyyyyyyyroo...........",
	"........owwwwwwwwoooowwwwwwwwyyyyyyyyyokoyyyyyyyyyroro..........",
	".......oyyyyyyyyyolmoyyyyyyyyyyyyyyyyyyooyyyyyyyyyroro..........",
	"......oyyyyyyyyyyolmoyyyyyyyyyyyyyyyyyyroyyyyyyyyyroro..........",
	"......oyyyyyyyyyyolmoyyyyyyyyyyyyyyyyyyroyyyyyyyyyroro..........",
	"......oyyyyyyyyyyolmoyyyyyyyyyyyyyyyyyyroyyyyyyyyyroro..........",
	"......oyyyyyyyyyyolmoyyyyyyyyyyyyyyyyyyroyyyyyyyyyroro..........",
	"......oyyyyyyyyyyolmoyyyyyyyyyyyyyyyyyyroyyyyyyyyyroro..........",
	".......orrrrrrrrroddorrrrrrrrrrrrrrrrrrooRkkkkkkkkRoro..........",
	"........oRRRRRRRRooooRRRRRRRRRRRRRRRRRoyooooooooooooro..........",
	".........oooooooooooooooooooooooooooooyyyyyyyyyyyyyyro..........",
	"..........oyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyro..........",
	"..........oyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyro..........",
	"..........oyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyro..........",
	"..........oyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyro..........",
	"..........oyyyyRyyyyyyyRyyyyyyyyyyyyyyyyRyyyyyyyRyyyro..........",
	"..........oyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyro..........",
	"...........oyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyo...........",
	"............oyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyo............",
	".............oRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRo.............",
	"..............oooooooooooooooooooooooooooooooooooo..............",
]

const CUFF := [
	"..............oooooooooooooooooooooooooooooooooooo..............",
	"..............ollllllllllllllllllllllllllllllllllo..............",
	"..............ommymmmmmymmmmmymmmmmymmmmmymmmmmymo..............",
	"..............ommmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmo..............",
	"..............oddddddddddddddddddddddddddddddddddo..............",
	"..............oooooooooooooooooooooooooooooooooooo..............",
]

## Rocket-grab chain tile: edge-on link through a face-on link. Tiles seamlessly vertically.
const CHAIN := [
	".....olmmdo.....",
	".....olmmdo.....",
	".....olmmdo.....",
	"...oooooooooo...",
	"..ollllllmmddo..",
	".olmooooooomddo.",
	".olmokkkkkomddo.",
	".olmokkkkkomddo.",
	".olmooooooomddo.",
	"..odmmmmmmmddo..",
	"...oooooooooo...",
	".....olmmdo.....",
]


func _init() -> void:
	var frames := [OPEN, HALF, FIST]
	var image := Image.create(W * frames.size(), H, false, Image.FORMAT_RGBA8)
	for f in frames.size():
		_paint(image, frames[f] + CUFF, Vector2i(f * W, 0))
	image.save_png(OUT)
	var chain := Image.create(CHAIN[0].length(), CHAIN.size(), false, Image.FORMAT_RGBA8)
	_paint(chain, CHAIN, Vector2i.ZERO)
	chain.save_png(OUT_CHAIN)
	print("Grab hand sprites written: %d frames of %dx%d + chain tile" % [frames.size(), W, H])
	quit()


func _paint(image: Image, rows: Array, at: Vector2i) -> void:
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			var key := row[x]
			if key != "." and PALETTE.has(key):
				image.set_pixel(at.x + x, at.y + y, PALETTE[key])
