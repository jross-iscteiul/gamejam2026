extends Node2D
## An evolved industrial robot: the enemies' warm armour, dark outlines, steel jaw and
## piston limbs, built into a heavy walking chassis. JARVIS pilots the open cockpit.
## The three inset units remain visible as the chest and shoulder shield generators.
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
## Tip of the forward cannon, shared with the projectile spawn point.
const MUZZLE_POINT := Vector2(52.0, 12.0)

const OUTLINE := Color("2b022a")
const STEEL := Color("537b8a")
const STEEL_LIGHT := Color("a9c1cb")
const STEEL_DARK := Color("3a5661")
## Reuse the level robots' paint jobs so every armour panel belongs to the same palette.
const ENEMY_ART := preload("res://ui/placeholder_enemy/robot.gd")

# Palette shared with the original industrial robot and JARVIS's sprite generator.
@export var plate: Color = Color("ffe119")
@export var plate_dark: Color = Color("ff6d05")
@export var plate_light: Color = Color("ffffff")
@export var cavity: Color = Color("112d38")
@export var glow: Color = Color("0cffeb")
@export var stripe: Color = Color("ff0000")
@export var stride_speed: float = 7.0

## Set by the fight controller so the legs stride while the machine is moving.
var walking: bool = false
## In the air the legs tuck up, like the player's jump pose.
var airborne: bool = false
var _stride: float = 0.0
var _front: Node2D # plating drawn over the slotted units
var _generators: Array[bool] = [false, false, false]


func _ready() -> void:
	_front = Node2D.new()
	_front.name = "Plating"
	add_child(_front)
	_front.draw.connect(_draw_front)


## Drops a conscripted unit into the next free pod. Returns its slot position.
func slot(unit: Node2D, index: int) -> Vector2:
	move_child(_front, get_child_count() - 1) # the plating always covers the pods
	var socket := index % SLOTS.size()
	unit.set_meta("mech_slot", socket)
	_generators[socket] = false
	return SLOTS[socket]


## Visual state only: damage and shield regeneration stay in JarvisBoss.
func set_generator_active(unit: Node2D, active: bool) -> void:
	var socket: int = unit.get_meta("mech_slot", 0)
	_generators[socket] = active
	_front.queue_redraw()


func _process(delta: float) -> void:
	_stride += delta * (stride_speed if walking else stride_speed * 0.25)
	queue_redraw()
	_front.queue_redraw()


func _draw() -> void:
	_draw_legs()
	# Ribbed steel waist under the armour, like the minions' exposed metal jaw.
	draw_rect(Rect2(-22, 0, 44, 16), OUTLINE)
	draw_rect(Rect2(-20, 2, 40, 12), STEEL_DARK)
	for y in [2, 6, 10]:
		draw_rect(Rect2(-18, y, 36, 2), STEEL_LIGHT)
	_draw_arms()
	_armour(self, Rect2(-24, -26, 48, 38))
	# A broad bevelled collar and inset cooling vents evolve the robot's head shell.
	_armour(self, Rect2(-36, -30, 72, 12), ENEMY_ART.Paint.RED_STAR)
	for side in [-1, 1]:
		for vent in 3:
			draw_rect(Rect2(side * (16 + vent * 4) - 1, -24, 2, 4), OUTLINE)
	# The openings are centred on the actual pod hurtboxes.
	for socket in SLOTS:
		var paint := ENEMY_ART.Paint.RED_STAR
		if socket.x < 0:
			paint = ENEMY_ART.Paint.BLUE
		elif socket.x > 0:
			paint = ENEMY_ART.Paint.PURPLE
		_armour(self, Rect2(socket - Vector2(13, 14), Vector2(26, 28)), paint)
		draw_rect(Rect2(socket - Vector2(10, 10), Vector2(20, 20)), OUTLINE)
		draw_rect(Rect2(socket - Vector2(8, 8), Vector2(16, 16)), cavity)
	_draw_cradle()


## Stepped armour and rectangular pistons keep the same hard pixel edges as the sprites.
func _draw_legs() -> void:
	for side in [-1.0, 1.0]:
		var phase := _stride + (0.0 if side < 0.0 else PI)
		var swing := snappedf(sin(phase) * (7.0 if walking else 1.0), 2.0)
		var lift := snappedf(maxf(0.0, cos(phase)) * (4.0 if walking else 0.0), 2.0)
		if airborne:
			swing = side * 4.0
			lift = 6.0
		var hip := Vector2(side * 12.0, 10.0)
		var knee := hip + Vector2(swing, 14.0 - lift)
		var foot := knee + Vector2(swing, 16.0 - lift)
		_piston(hip, knee, 10.0)
		_piston(knee, foot, 8.0)
		var paint := ENEMY_ART.Paint.BLUE if side < 0 else ENEMY_ART.Paint.GREEN
		_armour(self, Rect2(knee - Vector2(8, 6), Vector2(16, 14)), paint)
		draw_rect(Rect2(knee - Vector2(4, 2), Vector2(8, 4)), STEEL_DARK)
		_armour(self, Rect2(foot.x - 10, foot.y - 4, 24, 10))
		draw_rect(Rect2(foot.x - 8, foot.y + 2, 20, 4), OUTLINE)


## Oversized gauntlets, with a forward arm cannon at the fight controller's muzzle.
func _draw_arms() -> void:
	for side in [-1.0, 1.0]:
		var swing := snappedf(sin(_stride + (PI if side < 0.0 else 0.0)) * (2.0 if walking else 0.0), 2.0)
		var shoulder := Vector2(side * 32.0, -16.0)
		var elbow := Vector2(side * 38.0, 0.0)
		var fist := Vector2(side * 38.0, 12.0 + swing)
		_piston(shoulder, elbow, 12.0)
		_piston(elbow, fist, 8.0)
		var paint := ENEMY_ART.Paint.GREEN if side < 0 else ENEMY_ART.Paint.PURPLE
		_armour(self, Rect2(fist - Vector2(10, 6), Vector2(20, 18)), paint)
		draw_rect(Rect2(fist.x - 6, fist.y + 4, 12, 4), OUTLINE)
		for finger in 3:
			draw_rect(Rect2(fist.x - 6 + finger * 4, fist.y + 8, 2, 2), STEEL_LIGHT)
	# The muzzle stays fixed at MUZZLE_POINT while the gauntlet animates behind it.
	draw_rect(Rect2(36, 6, 16, 12), OUTLINE)
	draw_rect(Rect2(36, 8, 12, 8), STEEL)
	draw_rect(Rect2(38, 8, 10, 2), STEEL_LIGHT)
	draw_rect(Rect2(46, 10, 6, 4), cavity)
	draw_rect(Rect2(48, 10, 2, 4), glow)


## The cockpit: a cradle of two posts and a seat pan, open at the top so the drone drops in.
func _draw_cradle() -> void:
	_armour(self, Rect2(-14, -36, 28, 10))
	draw_rect(Rect2(-10, -36, 20, 4), cavity)
	for side in [-1, 1]:
		draw_rect(Rect2(side * 16 - 2, -44, 4, 16), OUTLINE)
		draw_rect(Rect2(side * 16 - 1, -42, 2, 12), STEEL_LIGHT)
		draw_rect(Rect2(side * 16 - 2, -44, 4, 2), glow)


## Drawn over the units: cyan brackets identify exactly three targets. Broken sockets
## retain a dark rim and severed leads until replacement units rebuild the shield.
func _draw_front() -> void:
	for i in SLOTS.size():
		var socket := SLOTS[i]
		var active := _generators[i]
		var light := glow if active else STEEL_DARK
		var rim := Rect2(socket - Vector2(10, 10), Vector2(20, 20))
		_front.draw_rect(rim, OUTLINE, false, 2.0)
		for side in [-1, 1]:
			for vertical in [-1, 1]:
				var corner := socket + Vector2(side * 8, vertical * 8)
				_front.draw_rect(Rect2(corner - Vector2(2, 1), Vector2(4, 2)), light)
				_front.draw_rect(Rect2(corner - Vector2(1, 2), Vector2(2, 4)), light)
		# An inset emitter over the unit's chest, rather than another enemy face.
		_front.draw_rect(Rect2(socket - Vector2(4, 4), Vector2(8, 8)), OUTLINE)
		_front.draw_rect(Rect2(socket - Vector2(2, 2), Vector2(4, 4)), light)
		if active:
			_front.draw_rect(Rect2(socket - Vector2(2, 2), Vector2(2, 2)), plate_light)
		else:
			_front.draw_rect(Rect2(socket + Vector2(-6, 4), Vector2(4, 2)), stripe)
	# High-contrast factory markings and small rivets, all on the same two-pixel grid.
	for side in [-1, 1]:
		_front.draw_rect(Rect2(side * 18 - 2, -14, 4, 4), OUTLINE)
		_front.draw_rect(Rect2(side * 18 - 2, -14, 2, 2), STEEL_LIGHT)
		for mark in 2:
			_front.draw_rect(Rect2(side * (16 + mark * 4) - 1, 8, 2, 6), stripe)


## Bevels use rectangular steps instead of smooth primitives or antialiased outlines.
func _armour(canvas: Node2D, box: Rect2, paint: int = -1) -> void:
	var colors: Array = [plate, plate_dark, stripe] if paint < 0 else ENEMY_ART.PAINTS[paint]
	canvas.draw_rect(Rect2(box.position + Vector2(2, 0), box.size - Vector2(4, 0)), OUTLINE)
	canvas.draw_rect(Rect2(box.position + Vector2(0, 2), box.size - Vector2(0, 4)), OUTLINE)
	canvas.draw_rect(Rect2(box.position + Vector2(2, 2), box.size - Vector2(4, 4)), colors[1])
	canvas.draw_rect(Rect2(box.position + Vector2(2, 2), box.size - Vector2(6, 6)), colors[0])
	canvas.draw_rect(Rect2(box.position + Vector2(4, 2), Vector2(box.size.x - 10, 2)), plate_light)
	canvas.draw_rect(Rect2(box.position + Vector2(4, box.size.y - 4), Vector2(box.size.x - 6, 2)), colors[2])


func _piston(start: Vector2, end: Vector2, width: float) -> void:
	draw_line(start, end, OUTLINE, width + 4.0)
	draw_line(start, end, STEEL_DARK, width)
	draw_line(start + Vector2(-2, 0), end + Vector2(-2, 0), STEEL_LIGHT, 2.0)
