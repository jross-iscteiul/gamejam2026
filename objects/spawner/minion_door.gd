class_name MinionDoor
extends Node2D
## Arena maintenance hatch. While the boss fight runs it cycles open every `interval` seconds and
## walks a fresh minion out, up to `max_alive` at a time. It goes dark with the rest of the
## network when JARVIS is shot down (see shut_down()).

const MINION := preload("res://ui/placeholder_enemy/robot.tscn")

@export var active: bool = false:
	set(value):
		active = value
		if is_node_ready():
			_left = first_delay if active else 0.0
		queue_redraw()
@export var interval: float = 5.0
@export var first_delay: float = 2.5
## Minions that walk out each time the hatch opens.
@export var per_release: int = 2
@export var max_alive: int = 6
@export var open_seconds: float = 0.35
@export var minion_patrol_distance: float = 72.0
@export var minion_fire_interval: float = 2.2
## Lifts the minion off the floor line so it does not spawn inside the ground tiles.
@export var minion_spawn_offset: Vector2 = Vector2(0.0, -16.0)
@export_group("Look")
@export var size: Vector2 = Vector2(28.0, 44.0)
@export var frame_color: Color = Color("3b4a63")
@export var frame_light: Color = Color("5f7696")
@export var inside_color: Color = Color("0b1018")
@export var panel_color: Color = Color("6c7d99")
@export var panel_shade: Color = Color("4a5c78")
@export var stripe_color: Color = Color("e0a53c")
@export var light_on: Color = Color("ff5555")
@export var light_off: Color = Color("3a2430")

var _left: float = 0.0
var _open: float = 0.0 # 0 = shut, 1 = fully retracted
var _pulse: float = 0.0 # drives the warning lamp
var _busy: bool = false # a release cycle is already running
var _offline: bool = false
var _spawned: Array[Node] = []


func _ready() -> void:
	add_to_group("minion_door")
	_left = first_delay if active else 0.0


## The boss switches its doors on when the arena fight starts.
func set_active(value: bool) -> void:
	active = value


func _process(delta: float) -> void:
	_pulse += delta
	queue_redraw()
	if not active or _offline or _busy:
		return
	_left -= delta
	if _left <= 0.0:
		_left = interval
		_release()


## One open-spawn-close cycle. `_busy` keeps the hatch from starting a second one on top of it.
func _release() -> void:
	_busy = true
	# The lambda takes a Variant (a freed instance cannot convert to Node) and assign() keeps
	# the typed Array[Node], which filter() alone would drop.
	_spawned.assign(_spawned.filter(func(node: Variant) -> bool: return is_instance_valid(node)))
	if _spawned.size() < max_alive:
		await _slide(1.0)
		for i in mini(per_release, max_alive - _spawned.size()):
			if _offline:
				break
			var minion := MINION.instantiate()
			minion.patrol_distance = minion_patrol_distance
			minion.fire_interval = minion_fire_interval
			minion.position = position + minion_spawn_offset # set before the tree sees it: the minion patrols around its spawn
			get_parent().add_child(minion)
			_spawned.append(minion)
			await get_tree().create_timer(open_seconds).timeout
		await _slide(0.0)
	_busy = false


func _slide(to: float) -> void:
	var tween := create_tween()
	tween.tween_property(self, "_open", to, open_seconds).set_trans(Tween.TRANS_QUAD)
	await tween.finished


## The network went dark: the hatch seals, its light dies and it stops producing.
func shut_down() -> void:
	if _offline:
		return
	_offline = true
	active = false
	_slide(0.0)


func _draw() -> void:
	# Set into the wall: the origin is the doorway's bottom centre, flush with the floor.
	var door := Rect2(-size.x * 0.5, -size.y, size.x, size.y)
	var frame := door.grow(3.0)
	draw_rect(frame, frame_color)
	# Bevel: lit along the top and left, shaded along the bottom and right.
	draw_rect(Rect2(frame.position, Vector2(frame.size.x, 2.0)), frame_light)
	draw_rect(Rect2(frame.position, Vector2(2.0, frame.size.y)), frame_light)
	draw_rect(Rect2(frame.position.x + frame.size.x - 2.0, frame.position.y, 2.0, frame.size.y), inside_color)
	_draw_stripes(Rect2(frame.position.x, frame.position.y - 6.0, frame.size.x, 5.0))
	draw_rect(door, inside_color)
	if _open > 0.01: # light spills out of the shaft while it is open
		var spill := Color(light_on, 0.12 * _open)
		draw_rect(Rect2(door.position.x, door.end.y - 10.0, door.size.x, 10.0), spill)
	_draw_panels(door)
	var lamp := Vector2(0.0, frame.position.y - 10.0)
	var lit: bool = active and not _offline
	draw_circle(lamp, 3.0, frame_color)
	draw_circle(lamp, 2.0, light_off if not lit else light_on.lerp(light_off, 0.5 + 0.5 * sin(_pulse * 4.0)))


## The two halves part sideways, each sliding into its side of the frame.
func _draw_panels(door: Rect2) -> void:
	var width := door.size.x * 0.5 * (1.0 - _open)
	if width < 1.0:
		return
	for panel in [
			Rect2(door.position.x, door.position.y, width, door.size.y),
			Rect2(door.end.x - width, door.position.y, width, door.size.y)]:
		draw_rect(panel, panel_color)
		draw_rect(Rect2(panel.position.x, panel.position.y, panel.size.x, 2.0), frame_light)
		# A seam down the middle of each half so the metal reads as panelled.
		draw_rect(Rect2(panel.position.x + panel.size.x * 0.5 - 1.0, panel.position.y + 4.0,
			2.0, panel.size.y - 8.0), panel_shade)


## Hazard chevrons on the lintel above the doorway.
func _draw_stripes(bar: Rect2) -> void:
	draw_rect(bar, inside_color)
	var step := 6.0
	var x := bar.position.x
	while x < bar.end.x - 1.0:
		var width := minf(step * 0.5, bar.end.x - x)
		draw_rect(Rect2(x, bar.position.y, width, bar.size.y), stripe_color)
		x += step
