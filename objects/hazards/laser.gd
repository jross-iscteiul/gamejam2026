@tool
extends Hazard
## Timed laser beam between two emitters: off -> warning flicker (harmless) -> on (1 HP).
## A hit knocks the player back and stuns it until it lands (knockback/stun set in laser.tscn).
## Origin = first emitter; the beam runs `length` px right (or down if `vertical`).

@export var length := 128.0
@export var vertical := false
@export var off_time := 1.6
@export var warn_time := 0.5
@export var on_time := 1.0
## Seconds added to the cycle clock; the generator offsets lasers by position so rows fire as a wave.
@export var phase := 0.0

var _hitbox: Hitbox
var _state := "off"


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var along := Vector2(0, length) if vertical else Vector2(length, 0)
	var thickness := Vector2(6, length) if vertical else Vector2(length, 6)
	_hitbox = make_hitbox(rect(thickness), along / 2.0)
	_set_beam(false)


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var state := state_at(time)
	if state != _state:
		_state = state
		_set_beam(state == "on")


## "off", "warn" or "on" for a clock value; timings shrink with difficulty, warning never below 0.3 s.
func state_at(clock: float) -> String:
	var off := off_time / difficulty
	var warn := maxf(warn_time / difficulty, 0.3)
	var on := on_time / difficulty
	var t := fposmod(clock + phase, off + warn + on)
	return "off" if t < off else "warn" if t < off + warn else "on"


## A horizontal beam is crossed, not approached sideways: push back against the player's travel.
func knockback_impulse(target: Node2D) -> Vector2:
	if vertical:
		return super(target)
	var vx: float = target.get("velocity").x
	var side := -signf(vx) if absf(vx) > 5.0 else -float(target.get("facing"))
	return Vector2(side * knockback, -knockback * 0.45)


func _set_beam(active: bool) -> void:
	_hitbox.get_child(0).set_deferred("disabled", not active)


func _draw() -> void:
	var end := Vector2(0, length) if vertical else Vector2(length, 0)
	var state := state_at(time)
	if state == "on":
		draw_line(Vector2.ZERO, end, Color(1, 0.15, 0.2, 0.35), 10.0)
		draw_line(Vector2.ZERO, end, Color(1, 0.4, 0.45), 4.0)
		draw_line(Vector2.ZERO, end, Color(1, 0.95, 0.95), 1.5)
	elif state == "warn" and fmod(time, 0.12) < 0.07:
		draw_line(Vector2.ZERO, end, Color(1, 0.3, 0.3, 0.7), 1.0)
	for p in [Vector2.ZERO, end]:
		draw_rect(Rect2(p - Vector2(6, 6), Vector2(12, 12)), Color(0.2, 0.22, 0.26))
		draw_rect(Rect2(p - Vector2(3, 3), Vector2(6, 6)), Color(1, 0.3, 0.3) if state != "off" else Color(0.4, 0.15, 0.15))
