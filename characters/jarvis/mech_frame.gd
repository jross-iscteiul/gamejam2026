extends Node2D
## The walking chassis the conscripted units build for the final phase. It has a cockpit cradle
## on top: the JARVIS drone drops into it and drives the thing from there, so the silhouette
## reads as "small smug drone piloting a big machine" instead of a pile of bolted-on robots.
## The units are slotted into the chest and the two shoulder pods, where they stay visible.
##
## Local space: origin at the hips, feet around y = 46, cockpit seat at `seat_point`.

## Where the drone sits once the machine is built, in local space.
const SEAT_POINT := Vector2(0.0, -40.0)
## Chest and shoulder pods, in the order the units fill them.
const SLOTS: Array[Vector2] = [Vector2(0.0, 2.0), Vector2(-28.0, -8.0), Vector2(28.0, -8.0)]
## Bottom of the feet, in local space: the physics body stands the machine on this line.
const FEET_Y := 46.0
## Units are machine parts now, not characters: they ride the frame at this size.
const SLOT_SCALE := 0.55

@export var plate: Color = Color("55617a")
@export var plate_dark: Color = Color("333b4d")
@export var plate_light: Color = Color("7b8aa6")
@export var cavity: Color = Color("141a26")
@export var glow: Color = Color("ff5555")
@export var stripe: Color = Color("e0a53c")
@export var stride_speed: float = 7.0

## Set by the fight controller so the legs stride while the machine is moving.
var walking: bool = false
## In the air the legs tuck up, like the player's jump pose.
var airborne: bool = false
var _stride: float = 0.0
var _front: Node2D # plating drawn over the slotted units


func _ready() -> void:
	_front = Node2D.new()
	_front.name = "Plating"
	add_child(_front)
	_front.draw.connect(_draw_front)


## Drops a conscripted unit into the next free pod. Returns its slot position.
func slot(unit: Node2D, index: int) -> Vector2:
	move_child(_front, get_child_count() - 1) # the plating always covers the pods
	return SLOTS[index % SLOTS.size()]


func _process(delta: float) -> void:
	_stride += delta * (stride_speed if walking else stride_speed * 0.25)
	queue_redraw()
	_front.queue_redraw()


func _draw() -> void:
	_draw_legs()
	draw_rect(Rect2(-20.0, 0.0, 40.0, 14.0), plate_dark) # hips
	_draw_arms()
	draw_rect(Rect2(-24.0, -22.0, 48.0, 26.0), plate) # torso
	draw_rect(Rect2(-24.0, -22.0, 48.0, 3.0), plate_light)
	draw_rect(Rect2(-36.0, -28.0, 72.0, 11.0), plate_dark) # shoulder bar
	# Cavities the units sit in: chest and the two shoulder pods.
	draw_rect(Rect2(-14.0, -18.0, 28.0, 20.0), cavity)
	for side in [-1.0, 1.0]:
		draw_rect(Rect2(side * 28.0 - 11.0, -22.0, 22.0, 20.0), cavity)
	_draw_cradle()


## Two legs that stride out of phase; they idle with a slow sway when he is holding position.
func _draw_legs() -> void:
	for side in [-1.0, 1.0]:
		var phase := _stride + (0.0 if side < 0.0 else PI)
		var swing := sin(phase) * (7.0 if walking else 2.0)
		var lift := maxf(0.0, cos(phase)) * (4.0 if walking else 0.0)
		if airborne:
			swing = side * 4.0
			lift = 6.0
		var hip := Vector2(side * 13.0, 10.0)
		var knee := hip + Vector2(swing * 0.5, 18.0 - lift)
		var foot := knee + Vector2(swing, 18.0 - lift)
		draw_line(hip, knee, plate_dark, 12.0)
		draw_line(knee, foot, plate, 9.0)
		draw_circle(knee, 5.0, plate_light)
		draw_rect(Rect2(foot.x - 11.0, foot.y - 3.0, 22.0, 8.0), plate_dark)


## Heavy arms hanging off the shoulder bar, ending in clamp fists.
func _draw_arms() -> void:
	for side in [-1.0, 1.0]:
		var swing := sin(_stride + (PI if side < 0.0 else 0.0)) * (3.0 if walking else 1.0)
		var shoulder := Vector2(side * 33.0, -18.0)
		var elbow := shoulder + Vector2(side * 4.0 + swing, 18.0)
		var fist := elbow + Vector2(side * 2.0 + swing, 15.0)
		draw_line(shoulder, elbow, plate, 11.0)
		draw_line(elbow, fist, plate_dark, 9.0)
		draw_circle(fist, 6.0, plate_light)


## The cockpit: a cradle of two posts and a seat pan, open at the top so the drone drops in.
func _draw_cradle() -> void:
	draw_rect(Rect2(-13.0, -34.0, 26.0, 8.0), plate_dark) # seat pan
	draw_rect(Rect2(-13.0, -34.0, 26.0, 2.0), plate_light)
	for side in [-1.0, 1.0]:
		draw_line(Vector2(side * 12.0, -26.0), Vector2(side * 16.0, -44.0), plate, 4.0)


## Drawn after the units so the pod rims, the chest glow and the hazard stripes stay on top.
func _draw_front() -> void:
	for side in [-1.0, 1.0]: # shoulder pod rims
		var pod := Rect2(side * 28.0 - 11.0, -22.0, 22.0, 20.0)
		_front.draw_rect(pod, plate_light, false, 2.0)
		_front.draw_rect(Rect2(pod.position.x, pod.end.y - 2.0, pod.size.x, 2.0), plate_dark)
	_front.draw_rect(Rect2(-14.0, -18.0, 28.0, 20.0), plate_light, false, 2.0) # chest rim
	var pulse := 0.6 + 0.4 * sin(_stride * 2.0)
	_front.draw_circle(Vector2(0.0, -20.0), 3.0, Color(glow, pulse))
	# Hazard stripes along the hip beam, so the thing reads as factory equipment.
	var x := -20.0
	while x < 18.0:
		_front.draw_rect(Rect2(x, 10.0, 3.0, 4.0), stripe)
		x += 7.0
