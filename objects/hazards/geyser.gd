@tool
extends Hazard
## Lava geyser over a lava pool: idle for a random idle_min..idle_max seconds, bubbles as a warning
## (harmless), then shoots a column of lava up to the ceiling (instant death, like lava).
## Origin = top-left of the pool cell; the generator sets `width` and `height` (pool top to ceiling).

const SURFACE: float = preload("res://objects/hazards/pool.gd").SURFACE

@export var width := 32.0
@export var height := 128.0
@export var idle_min := 3.0
@export var idle_max := 4.0
@export var warn_time := 0.6
@export var erupt_time := 1.0

var state := "idle"
var time_left := 0.0
var _hitbox: Hitbox


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var column := Vector2(width - 8.0, height + SURFACE)
	_hitbox = make_hitbox(rect(column), Vector2(width / 2.0, SURFACE - column.y / 2.0), self, true)
	_enter("idle")


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	time_left -= delta
	if time_left <= 0.0:
		_enter({"idle": "warn", "warn": "erupt", "erupt": "idle"}[state])


func _enter(next: String) -> void:
	state = next
	time_left = {"idle": randf_range(idle_min, idle_max), "warn": warn_time, "erupt": erupt_time}[state]
	_hitbox.get_child(0).set_deferred("disabled", state != "erupt")


func _draw_bounds() -> Rect2:
	return Rect2(-2.0, -height, width + 4.0, height + SURFACE + 4.0)


func _draw() -> void:
	if state == "warn": # bubbles and spatter jumping off the surface
		for i in 4:
			var hop := absf(sin(time * 9.0 + i * 1.7)) * 14.0
			draw_circle(Vector2(5.0 + i * (width - 10.0) / 3.0, SURFACE - hop), 2.5, Color(1.0, 0.7, 0.2))
	elif state == "erupt":
		var top := -height
		draw_rect(Rect2(-2.0, top, width + 4.0, height + SURFACE), Color(1.0, 0.45, 0.1, 0.3)) # glow
		draw_rect(Rect2(4.0, top, width - 8.0, height + SURFACE), Color(1.0, 0.36, 0.08))
		for i in int(height / 8.0): # wobbling bright core
			var y := top + i * 8.0
			var x := width / 2.0 + sin(y * 0.2 + time * 14.0) * 3.0
			draw_line(Vector2(x, y), Vector2(x, y + 8.0), Color(1.0, 0.8, 0.25), 4.0)
