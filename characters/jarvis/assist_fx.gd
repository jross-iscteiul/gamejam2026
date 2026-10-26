extends Node2D
## Effects for JARVIS's assists, drawn under the drone (parent is the Jarvis node):
## shield = projector beam down onto the player's bubble, dash = thruster flame behind him,
## boost = blue energy platform projected above him for the player to jump off.

@export var beam_color: Color = Color(0.05, 1.0, 0.92, 0.22)
@export var beam_edge_color: Color = Color(0.05, 1.0, 0.92, 0.55)
@export var beam_source: Vector2 = Vector2(0.0, 9.0) # JARVIS's nozzle, from his centre
@export var beam_spread: float = 14.0 # half-width where the beam meets the shield bubble
@export var shield_radius: float = 20.0 # matches the player's ShieldBubble
@export var flame_outer: Color = Color("ff6d05")
@export var flame_inner: Color = Color("ffe119")
@export var flame_length: Vector2 = Vector2(10.0, 18.0) # min/max flicker
@export var nozzle_distance: float = 9.0
@export var platform_color: Color = Color("2f8cff")
@export var platform_edge_color: Color = Color("a8e4ff") # bright top surface
@export var platform_offset: Vector2 = Vector2(0.0, -18.0) # centre, above the drone's rotor
@export var platform_size: Vector2 = Vector2(30.0, 4.0)
## The platform stays fixed where it was created, outlasting JARVIS's boost pose (0.45 s)
## by 0.2 s; projector beams show only while he is still underneath.
@export var platform_seconds: float = 0.65
@export var platform_beam_seconds: float = 0.45
@export var platform_fade: float = 0.3 # last part of the time spent fading out

var kind: StringName = &""
var _dir: int = 1
var _time: float = 0.0
var _platform_world := Vector2.ZERO # platform centre, fixed in the world


func start(new_kind: StringName, direction: int = 1) -> void:
	kind = new_kind
	_dir = direction
	_time = 0.0
	if new_kind == &"boost":
		_platform_world = global_position + platform_offset
	queue_redraw()


func stop() -> void:
	if kind != &"":
		kind = &""
		queue_redraw()


func _process(delta: float) -> void:
	if kind == &"":
		return
	_time += delta
	if kind == &"boost" and _time > platform_seconds:
		stop()
	queue_redraw()


func _draw() -> void:
	match kind:
		&"shield": _draw_beam()
		&"dash": _draw_flame()
		&"boost": _draw_platform()


func _draw_beam() -> void:
	var jarvis := get_parent()
	var target: Node2D = jarvis.get("player")
	if target == null:
		return
	# Where the beam meets the top of the bubble, in this node's space.
	var centre := to_local(target.global_position)
	var top := centre.y - shield_radius * 0.7
	var flicker := 0.85 + 0.15 * sin(_time * 30.0)
	var left := Vector2(centre.x - beam_spread, top)
	var right := Vector2(centre.x + beam_spread, top)
	var source_left := beam_source + Vector2(-2.0, 0.0)
	var source_right := beam_source + Vector2(2.0, 0.0)
	draw_colored_polygon(PackedVector2Array([source_left, source_right, right, left]),
		Color(beam_color, beam_color.a * flicker))
	draw_line(source_left, left, beam_edge_color, 1.0)
	draw_line(source_right, right, beam_edge_color, 1.0)


func _draw_flame() -> void:
	var back := Vector2(-_dir, 0.0)
	var base := back * nozzle_distance
	var length := lerpf(flame_length.x, flame_length.y, 0.5 + 0.5 * sin(_time * 60.0))
	var side := Vector2(0.0, 3.0)
	draw_colored_polygon(PackedVector2Array([base - side, base + side, base + back * length]), flame_outer)
	draw_colored_polygon(PackedVector2Array([base - side * 0.5, base + side * 0.5, base + back * length * 0.6]), flame_inner)


func _draw_platform() -> void:
	var t := clampf(_time / platform_seconds, 0.0, 1.0)
	var fade := clampf((1.0 - t) / maxf(platform_fade, 0.01), 0.0, 1.0)
	var flicker := 0.85 + 0.15 * sin(_time * 40.0)
	var alpha := fade * flicker
	var rect := Rect2(to_local(_platform_world) - platform_size * 0.5, platform_size)
	if _time < platform_beam_seconds: # projector lines from the drone up to the platform's ends
		var source := Vector2(0.0, -12.0)
		var line := Color(platform_color, 0.5 * alpha)
		draw_line(source, Vector2(rect.position.x + 2.0, rect.end.y), line, 1.0)
		draw_line(source, Vector2(rect.end.x - 2.0, rect.end.y), line, 1.0)
	draw_rect(rect.grow(1.0), Color(platform_color, 0.35 * alpha)) # glow
	draw_rect(rect, Color(platform_color, 0.85 * alpha))
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, 1.0)), Color(platform_edge_color, alpha))
