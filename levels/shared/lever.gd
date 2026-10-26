extends Area2D
## Wall terminal: stand near and press E (interact) to open the linked gate (one-shot).
## The slide switch slams across (~0.15 s) and the screen flips from a lock glyph to an
## unlock glyph.

const SLAM_SECONDS := 0.15
const BODY := Color("1d2433")
const BODY_EDGE := Color("3c4f6e")
const SCREEN_BG := Color("05060a")
const RED := Color("ff4d4d")
const GREEN := Color("39ff6a")

@export var gate: Gate

var on := false

var _switch := 0.0 # 0 = locked (left) .. 1 = open (right)


func _process(delta: float) -> void:
	var near := has_overlapping_bodies()
	$Hint.visible = near and not on
	if not on and Input.is_action_just_pressed("interact") and near:
		on = true
		gate.closed = false
	_switch = move_toward(_switch, 1.0 if on else 0.0, delta / SLAM_SECONDS)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(-9, -2, 18, 18), BODY) # console body, base on the floor
	draw_rect(Rect2(-9, -2, 18, 3), BODY_EDGE)
	draw_rect(Rect2(-7, 0, 14, 7), SCREEN_BG) # mini screen
	if on: # unlock glyph: two bars apart
		draw_rect(Rect2(-4, 2, 3, 3), GREEN)
		draw_rect(Rect2(2, 2, 3, 3), GREEN)
	else: # lock glyph: shackle + body
		draw_rect(Rect2(-2, 0, 5, 2), RED)
		draw_rect(Rect2(-1, 2, 3, 3), RED)
	draw_rect(Rect2(-6, 10, 12, 4), SCREEN_BG) # switch track
	var knob_x := lerpf(-5.0, 3.0, _switch)
	draw_rect(Rect2(knob_x, 9, 5, 6), GREEN if on else RED)
	draw_circle(Vector2(6, 12), 1.3, GREEN if on else RED) # status LED
	if $Hint.visible:
		draw_rect(Rect2(-8, -24, 16, 14), BODY)
		draw_rect(Rect2(-8, -24, 16, 14), Color(GameUI.CYAN, 0.8), false, 1.0)
