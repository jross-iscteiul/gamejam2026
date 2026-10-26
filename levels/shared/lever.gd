extends Area2D
## Wall terminal: stand near and press E (interact) to open the linked gate (one-shot).
## The slide switch slams across (~0.15 s) and the screen flips from a lock glyph to a
## solid green fill.

const SLAM_SECONDS := 0.15
const BODY := Color("1d2433")
const BODY_EDGE := Color("3c4f6e")
const RIM := Color("6fd8ff")
const SCREEN_BG := Color("05060a")
const RED := Color("ff5050")
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
	draw_rect(Rect2(-12, -8, 24, 24), BODY) # console body, base on the floor
	draw_rect(Rect2(-12, -8, 24, 3), BODY_EDGE)
	draw_rect(Rect2(-12, -8, 24, 24), Color(RIM, 0.9 if on else 0.6), false, 1.5) # bright rim light
	draw_rect(Rect2(-9, -4, 18, 10), SCREEN_BG) # mini screen
	if on: # unlocked: screen fills solid green
		draw_rect(Rect2(-9, -4, 18, 10), GREEN)
	else: # lock glyph: shackle + body
		draw_rect(Rect2(-3, -3, 6, 3), RED, false, 1.0)
		draw_rect(Rect2(-3, 0, 6, 5), RED)
	draw_rect(Rect2(-8, 8, 16, 5), SCREEN_BG) # switch track
	var knob_x := lerpf(-7.0, 4.0, _switch)
	draw_rect(Rect2(knob_x, 7, 6, 7), GREEN if on else RED)
	draw_circle(Vector2(8, 13), 1.8, GREEN if on else RED) # status LED
	if $Hint.visible:
		draw_rect(Rect2(-8, -34, 16, 14), BODY)
		draw_rect(Rect2(-8, -34, 16, 14), Color(GameUI.CYAN, 0.8), false, 1.0)
