extends Area2D
## Holo beacon: touch to make this the player's respawn point (for pits). Idles with a dim
## red LED blink and a soft halo; on first activation a cyan ring sweeps up once (~0.5 s),
## then it glows bright steady cyan with a halo and a subtle scanline flicker.

const SWEEP_SECONDS := 0.5
const PYLON := Color("1d2433")
const PYLON_EDGE := Color("3c4f6e")
const RED_DIM := Color("7a1a1a")
const RED_LIT := Color("ff5050")

var active := false

var _t := 0.0
var _sweep := 0.0 # 0..1 while the activation ring rises, then stays at 1


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_t += delta
	if active and _sweep < 1.0:
		_sweep = minf(_sweep + delta / SWEEP_SECONDS, 1.0)
	queue_redraw()


func _on_body_entered(body: Node2D) -> void:
	body.respawn_point = global_position
	active = true


func _draw() -> void:
	draw_rect(Rect2(-4, -24, 8, 40), PYLON) # pylon, base on the floor
	draw_rect(Rect2(-4, -24, 8, 3), PYLON_EDGE)
	draw_rect(Rect2(-8, 12, 16, 4), PYLON_EDGE) # base plate
	draw_rect(Rect2(-7, -30, 14, 7), PYLON) # emitter head
	var core := Vector2(0, -26)
	if not active:
		var lit := fmod(_t, 1.6) < 0.5
		draw_circle(core, 7.0, Color(RED_LIT, 0.25 if lit else 0.1)) # soft halo
		draw_circle(core, 3.0, RED_LIT if lit else RED_DIM)
		return
	var flicker := 0.75 + 0.25 * sin(_t * 20.0)
	draw_circle(core, 9.0, Color(GameUI.CYAN, 0.3 * flicker)) # soft halo
	draw_circle(core, 3.0, Color(GameUI.CYAN, 1.0))
	if _sweep < 1.0: # one-shot rising ring
		var y := core.y - _sweep * 44.0
		draw_arc(core + Vector2(0, y - core.y), 10.0, 0.0, TAU, 16, Color(GameUI.CYAN, 1.0 - _sweep), 2.0)
	draw_line(core, core + Vector2(0, -23), Color(GameUI.CYAN, 0.6 * flicker), 2.0)
	draw_rect(Rect2(core.x - 2.0, core.y - 23.0, 4.0, 23.0), Color(GameUI.CYAN, 0.2 * flicker)) # beam glow
