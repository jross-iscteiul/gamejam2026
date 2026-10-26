@tool
extends Hazard
## Giant rolling ball: waits `delay` seconds, speeds up over `accel_time` to `speed` and rolls right,
## crushing the player (instant death), until it reaches `distance` (the generator stops it at the
## boss gate). Too big to jump in the level 4 corridor. Restarts when the player respawns, unless
## `gate` has already closed. Origin = start centre of the ball.

const RADIUS := 48.0

@export var delay := 2.0
@export var speed := 115.0
@export var accel_time := 1.0
@export var distance := 640.0
@export var gate: Gate

var _clock := 0.0
var _start := Vector2.ZERO


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_start = position
	var circle := CircleShape2D.new()
	circle.radius = RADIUS - 4.0
	make_hitbox(circle, Vector2.ZERO, self, true)
	GameState.player_respawned.connect(_on_player_respawned)


## Distance rolled `clock` seconds after the level starts: wait, ease up to speed, roll, stop at the end.
func offset_at(clock: float) -> float:
	var t := clock - delay
	if t <= 0.0:
		return 0.0
	var rolled := 0.5 * speed * t * t / accel_time if t < accel_time else speed * (t - accel_time / 2.0)
	return minf(rolled, distance)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_clock += delta
	position = _start + Vector2(offset_at(_clock), 0.0)


func _on_player_respawned() -> void:
	if gate == null or not gate.closed:
		_clock = 0.0


func _draw() -> void:
	var roll := (position.x - _start.x) / RADIUS
	draw_circle(Vector2.ZERO, RADIUS, Color(0.3, 0.27, 0.25))
	draw_circle(Vector2(-6, -6), RADIUS - 8.0, Color(0.42, 0.38, 0.34))
	for i in 3: # cracks turn with the roll
		var a := roll + i * TAU / 3.0
		draw_line(Vector2.from_angle(a) * 10.0, Vector2.from_angle(a + 0.3) * (RADIUS - 6.0), Color(0.2, 0.18, 0.16), 3.0)
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 48, Color(0.15, 0.13, 0.12), 2.0)
