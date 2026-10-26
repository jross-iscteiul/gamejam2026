@tool
extends Hazard
## Liquid pool: lava (instant death) or toxic waste (`damage` HP each time invincibility runs out;
## toxic.tscn uses 2 and draws in front of the player, who wades through it).
## Origin = top-left of the pool; the generator sets `size` from a run of map cells.

enum Kind { LAVA, TOXIC }

const SURFACE := 10.0 # liquid surface sits this far below the top of the cells
const COLORS := {
	Kind.LAVA: [Color(1.0, 0.36, 0.08), Color(1.0, 0.78, 0.2), Color(1.0, 0.45, 0.1, 0.25)],
	Kind.TOXIC: [Color(0.35, 0.85, 0.1), Color(0.75, 1.0, 0.35), Color(0.4, 1.0, 0.2, 0.2)],
}

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
	var c: Array = COLORS[kind]
	draw_rect(Rect2(-4, SURFACE - 10, size.x + 8, size.y - SURFACE + 10), c[2]) # glow
	draw_rect(Rect2(0, SURFACE, size.x, size.y - SURFACE), c[0])
	# moving surface wave (lava) or rising bubbles (toxic)
	var points := PackedVector2Array()
	for i in int(size.x / 4.0) + 1:
		var x := i * 4.0
		points.append(Vector2(x, SURFACE + sin(x * 0.15 + time * 3.0) * 2.0))
	draw_polyline(points, c[1], 2.0)
	if kind == Kind.TOXIC:
		for i in int(size.x / 24.0):
			var y := SURFACE + fposmod(-time * 12.0 + i * 7.0, size.y - SURFACE)
			draw_circle(Vector2(12.0 + i * 24.0 + sin(time * 2.0 + i) * 3.0, y), 2.5, c[1])
