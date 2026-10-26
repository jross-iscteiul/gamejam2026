@tool
extends Node2D
## Debug drawing of JARVIS's spray_sectors as a polar chart (facing right in the editor).
## Each slice is a coloured wedge; its outline bulges outward where shots are more likely,
## so wedge size = chance of that slice and the bump = its peak. Updates live in the editor.

@export var visible_in_game: bool = false
@export var radius: float = 24.0 # length of the outline at average density
@export var max_radius: float = 70.0
@export var colors: Array[Color] = [Color(1.0, 0.8, 0.2), Color(0.3, 1.0, 0.5), Color(1.0, 0.4, 0.4), Color(0.6, 0.5, 1.0)]
@export var steps_per_slice: int = 24

var _last_sectors: Array = []
var _last_facing: int = 1


func _ready() -> void:
	if not Engine.is_editor_hint() and not visible_in_game:
		hide()
		set_process(false)


func _process(_delta: float) -> void:
	var sectors: Array = _sectors()
	var facing := _facing()
	if sectors != _last_sectors or facing != _last_facing:
		_last_sectors = sectors.duplicate()
		_last_facing = facing
		queue_redraw()


func _draw() -> void:
	var sectors := _sectors()
	var total := 0.0
	for s: Vector4 in sectors:
		total += maxf(s.z, 0.0)
	if total <= 0.0:
		return
	var facing := _facing()
	draw_line(Vector2.ZERO, Vector2(radius * facing, 0.0), Color(1, 1, 1, 0.4), 1.0)
	for i in sectors.size():
		var s: Vector4 = sectors[i]
		var width := s.y - s.x
		if s.z <= 0.0 or width <= 0.0:
			continue
		var color: Color = colors[i % colors.size()]
		var peak := clampf(s.w, s.x, s.y)
		# Probability per degree, scaled so a flat 360 deg spread would sit at `radius`.
		var height := (s.z / total) * 2.0 / width * 360.0
		var points := PackedVector2Array([Vector2.ZERO])
		for step in steps_per_slice + 1:
			var deg := lerpf(s.x, s.y, float(step) / steps_per_slice)
			var shape := _triangle(deg, s.x, s.y, peak)
			var r := minf(radius * 0.25 + radius * height * shape, max_radius)
			points.append(Vector2(cos(deg_to_rad(deg)) * facing, sin(deg_to_rad(deg))) * r)
		draw_colored_polygon(points, Color(color, 0.35))
		points.append(Vector2.ZERO)
		draw_polyline(points, color, 1.0)
		var mid := deg_to_rad(peak)
		var label_at := Vector2(cos(mid) * facing, sin(mid)) * (max_radius * 0.6)
		draw_string(ThemeDB.fallback_font, label_at, "%d%%" % roundi(s.z / total * 100.0),
			HORIZONTAL_ALIGNMENT_CENTER, -1, 8, color)


## 0..1 shape of the triangular curve: 1 at peak, 0 at the slice edges.
func _triangle(deg: float, low: float, high: float, peak: float) -> float:
	if deg <= peak:
		return 1.0 if peak == low else (deg - low) / (peak - low)
	return 1.0 if peak == high else (high - deg) / (high - peak)


func _sectors() -> Array:
	var value: Variant = get_parent().get("spray_sectors") if get_parent() else null
	return value if value is Array else []


func _facing() -> int:
	if Engine.is_editor_hint():
		return 1
	var value: Variant = get_parent().get("facing")
	return value if value is int else 1
