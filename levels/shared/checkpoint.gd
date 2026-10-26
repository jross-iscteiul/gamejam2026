extends Area2D
## Holo beacon: touch to make this the player's respawn point (for pits). Idles with a dim
## red LED blink; on first activation a cyan ring sweeps up once (~0.5 s), then it glows
## steady cyan with a subtle scanline flicker.

const SWEEP_SECONDS := 0.5
const PYLON := Color("1d2433")
const PYLON_EDGE := Color("3c4f6e")
const RED_DIM := Color("5a1414")
const RED_LIT := Color("ff4d4d")

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
	draw_rect(Rect2(-4, -14, 8, 30), PYLON) # pylon, base on the floor
	draw_rect(Rect2(-4, -14, 8, 3), PYLON_EDGE)
	draw_rect(Rect2(-7, 12, 14, 4), PYLON_EDGE) # base plate
	draw_rect(Rect2(-6, -20, 12, 6), PYLON) # emitter head
	if not active:
		var lit := fmod(_t, 1.6) < 0.5
		draw_circle(Vector2(0, -17), 2.5, RED_LIT if lit else RED_DIM)
		return
	draw_circle(Vector2(0, -17), 2.5, Color(GameUI.CYAN, 0.9))
	if _sweep < 1.0: # one-shot rising ring
		var y := -17.0 - _sweep * 40.0
		draw_arc(Vector2(0, y), 9.0, 0.0, TAU, 16, Color(GameUI.CYAN, 1.0 - _sweep), 2.0)
	var flicker := 0.75 + 0.25 * sin(_t * 20.0)
	draw_line(Vector2(0, -17), Vector2(0, -40), Color(GameUI.CYAN, 0.5 * flicker), 1.5)
	draw_rect(Rect2(-1.5, -40, 3, 23), Color(GameUI.CYAN, 0.18 * flicker)) # beam glow
