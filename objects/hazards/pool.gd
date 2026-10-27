@tool
extends Hazard
## Liquid pool: lava (instant death) or toxic waste (`damage` HP each time invincibility runs out;
## toxic.tscn uses 2 and draws in front of the player, who wades through it).
## Origin = top-left of the pool; the generator sets `size` from a run of map cells.

enum Kind { LAVA, TOXIC }

const SURFACE := 10.0 # liquid surface sits this far below the top of the cells
## Pixel-art palettes, light -> dark: [foam, surface, mid, deep, crust/bubble, glow].
const PALETTES := {
	Kind.LAVA: [Color("fff3a0"), Color("ffd23f"), Color("ff8a1f"), Color("c8401c"), Color("5a1a10"), Color(1.0, 0.45, 0.1, 0.18)],
	Kind.TOXIC: [Color("eaffb0"), Color("9be84a"), Color("4fbf2a"), Color("2a7a24"), Color("c8ff7a"), Color(0.45, 1.0, 0.25, 0.14)],
}
const PX := 2.0 # pixel size: everything snaps to a 2 px grid like the tileset art

@export var kind := Kind.LAVA
@export var size := Vector2(128, 32)
## Off = looks only (pit bottoms, where the Pit trigger already resets the player).
@export var damaging := true
## HP per hit for toxic waste (lava always kills).
@export var damage := 1.0


func _ready() -> void:
	if Engine.is_editor_hint() or not damaging:
		return
	var liquid := Vector2(size.x - 4.0, size.y - SURFACE)
	var hitbox := make_hitbox(rect(liquid), Vector2(size.x / 2.0, SURFACE + liquid.y / 2.0), self, kind == Kind.LAVA)
	hitbox.damage = damage


func _draw_bounds() -> Rect2:
	return Rect2(-4, 0, size.x + 8, size.y)


func _draw() -> void:
	var c: Array = PALETTES[kind]
	var depth := size.y - SURFACE
	# Heat haze just above lava (toxic gets none: it reads as a dark box on the walls).
	if kind == Kind.LAVA:
		var glow: Color = c[5]
		draw_rect(Rect2(0, SURFACE - 4.0, size.x, 4.0), Color(glow, glow.a))
	# Body: horizontal bands getting darker with depth, dithered at the seams.
	var bands := [c[2], c[3], c[3].darkened(0.25)]
	var band_h := snappedf(depth / bands.size(), PX)
	for b in bands.size():
		var y := SURFACE + 4.0 + b * band_h
		draw_rect(Rect2(0, y, size.x, size.y - y), bands[b])
		if b > 0: # checker dither between bands
			var x := 0.0
			while x < size.x:
				draw_rect(Rect2(x + fmod(y / PX, 2.0) * PX, y - PX, PX, PX), bands[b - 1])
				x += PX * 2.0
	# Surface: a pixel-stepped wave, bright top line and foam caps.
	var x := 0.0
	while x < size.x:
		var wave := sin(x * 0.12 + time * 2.5) * PX * 1.5
		var top := SURFACE + snappedf(wave, PX)
		draw_rect(Rect2(x, top, PX * 2.0, SURFACE + 6.0 - top), c[1])
		draw_rect(Rect2(x, top, PX * 2.0, PX), c[0] if fmod(x / 4.0 + floorf(time * 4.0), 5.0) < 1.0 else c[1].lightened(0.25))
		x += PX * 2.0
	if kind == Kind.LAVA:
		_draw_lava(c)
	else:
		_draw_toxic(c)
	# Dark rim at the pool's sides so it sits in the floor.
	draw_rect(Rect2(0, SURFACE, PX, depth), c[4])
	draw_rect(Rect2(size.x - PX, SURFACE, PX, depth), c[4])


## Drifting crust plates on the surface and embers rising out of it.
func _draw_lava(c: Array) -> void:
	var count := int(size.x / 40.0) + 1
	for i in count:
		var px := snappedf(fposmod(i * 41.0 + time * (6.0 + i % 3 * 3.0), size.x - 12.0), PX)
		var py := SURFACE + 6.0 + (i % 2) * PX * 2.0
		draw_rect(Rect2(px, py + PX, 12.0, PX * 2.0), c[4])
		draw_rect(Rect2(px + PX * 2.0, py, 6.0, PX), c[4])
		draw_rect(Rect2(px + PX, py + PX, 4.0, PX), c[3])
	for i in count * 2:
		var life := fposmod(time * 0.8 + i * 0.37, 1.0)
		var ex := snappedf(fposmod(i * 29.0, size.x - 4.0) + sin(time * 3.0 + i) * 2.0, PX)
		var ey := snappedf(SURFACE - life * 22.0, PX)
		draw_rect(Rect2(ex, ey, PX, PX), Color(c[0] if life < 0.5 else c[2], 1.0 - life))


## Bubbles that rise, swell at the surface and pop.
func _draw_toxic(c: Array) -> void:
	var depth := size.y - SURFACE
	for i in int(size.x / 18.0):
		var life := fposmod(time * 0.6 + i * 0.29, 1.0)
		var bx := snappedf(8.0 + fposmod(i * 23.0, size.x - 16.0), PX)
		var by := snappedf(SURFACE + depth - life * (depth - 2.0), PX)
		var r := PX * 2.0 if life < 0.75 else PX * 3.0
		if life > 0.93: # pop: droplets flying off the surface
			for d in [-1, 1]:
				draw_rect(Rect2(bx + d * PX * 3.0, SURFACE - PX * 3.0, PX, PX), c[0])
				draw_rect(Rect2(bx + d * PX * 2.0, SURFACE - PX, PX, PX), c[4])
			continue
		draw_rect(Rect2(bx - r / 2.0 - PX, by - r / 2.0, r + PX * 2.0, r), c[3]) # ring
		draw_rect(Rect2(bx - r / 2.0, by - r / 2.0 - PX, r, r + PX * 2.0), c[3])
		draw_rect(Rect2(bx - r / 2.0, by - r / 2.0, r, r), c[4])
		draw_rect(Rect2(bx - r / 2.0, by - r / 2.0, PX, PX), c[0])
