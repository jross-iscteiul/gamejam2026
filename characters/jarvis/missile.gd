extends Hitbox
## Big homing missile fired out of the mech's shoulder pods. It climbs out of the pod for a
## moment, then turns after the player at a limited rate, so a well-timed dash or jump shakes it
## off. Where it slams into the ground it cracks open and drops a fresh minion. Shooting it down
## in the air (two hits) stops that.

const MINION := preload("res://ui/placeholder_enemy/robot.tscn")
const OUTLINE := Color("2b022a")
const STEEL := Color("537b8a")
const STEEL_LIGHT := Color("a9c1cb")
const STEEL_DARK := Color("3a5661")
const RED_SHADE := Color("b0202c")
const BLUE_SHADE := Color("2a5fc4")
const BLUE_DARK := Color("163a80")

@export var speed: float = 85.0
@export var turn_rate: float = 2.0 # radians per second
@export var arm_seconds: float = 0.4 # straight climb before it starts homing
@export var lifetime: float = 6.0
@export var size: float = 1.5 # half the original rocket size, including its hitboxes
@export var health_points: float = 2.0
## No new minion when this many units are already up, so the arena never floods.
@export var max_minions: int = 8
@export var minion_patrol_distance: float = 60.0
@export var minion_fire_interval: float = 2.2
# The yellow, red and blue paint ramps used by the level robots.
@export var hull_color: Color = Color("ffe119")
@export var hull_dark: Color = Color("ff6d05")
@export var nose_color: Color = Color("e63946")
@export var stripe_color: Color = Color("4d8dff")
@export var flame_color: Color = Color("ff6d05")

var direction := Vector2.UP
var target: Node2D
var _age: float = 0.0
var _done: bool = false


func _ready() -> void:
	collision_layer = 16
	collision_mask = 3 # world and the player
	monitorable = true
	_add_shape(self, 3.0 * size)
	add_to_group("enemy_projectile")
	super()
	body_entered.connect(_on_ground)
	area_entered.connect(func(area: Area2D) -> void:
		if area is Hurtbox:
			_explode(true))
	# Shootable: a small health pool on the enemy hurtbox layer.
	var health := Health.new()
	health.max_health = health_points
	health.invincibility_duration = 0.05
	add_child(health)
	health.damaged.connect(func(_amount: float, _source: Node) -> void:
		modulate = Color(2.0, 2.0, 2.0)
		create_tween().tween_property(self, "modulate", Color.WHITE, 0.12))
	health.died.connect(func(_source: Node) -> void: _explode())
	var hurtbox := Hurtbox.new()
	hurtbox.health = health
	hurtbox.collision_layer = 4
	hurtbox.collision_mask = 8
	_add_shape(hurtbox, 4.5 * size)
	add_child(hurtbox)
	rotation = snappedf(direction.angle(), TAU / 16.0)


func _add_shape(area: Area2D, radius: float) -> void:
	var collider := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = radius
	collider.shape = shape
	area.add_child(collider)


func _physics_process(delta: float) -> void:
	super(delta)
	if _done:
		return
	_age += delta
	if _age > arm_seconds and is_instance_valid(target):
		var wanted := global_position.direction_to(target.global_position + Vector2(0.0, -6.0))
		var turn := clampf(direction.angle_to(wanted), -turn_rate * delta, turn_rate * delta)
		direction = direction.rotated(turn)
	position += direction * speed * delta
	# Sixteen visible headings keep the pixel silhouette crisp; guidance stays continuous.
	rotation = snappedf(direction.angle(), TAU / 16.0)
	queue_redraw()
	if _age >= lifetime:
		_explode()


## Arena impacts call in a ceiling reinforcement. Standalone scenes without a spawner retain
## a minion emerging from the wreck. Neither route can exceed its population limit.
func _on_ground(_body: Node2D) -> void:
	if _done:
		return
	if _minion_count() < max_minions:
		var spawner := get_tree().get_first_node_in_group("minion_spawner")
		if spawner != null:
			spawner.call_deferred("drop_minion")
			_explode()
			return
		var minion := MINION.instantiate()
		minion.patrol_distance = minion_patrol_distance
		minion.fire_interval = minion_fire_interval
		# Set before the tree sees it: the minion patrols around its spawn point. Backed off
		# along the flight path so it lands on top of the surface, not inside it.
		minion.position = global_position - direction * 4.0 * size + Vector2(0.0, -12.0)
		get_tree().current_scene.add_child.call_deferred(minion)
	_explode()


func _minion_count() -> int:
	return get_tree().get_nodes_in_group("enemy").filter(func(node: Variant) -> bool:
		var unit: bool = not node.is_in_group("boss") and not node.is_in_group("jarvis")
		return unit and not ("_dead" in node and node._dead)).size()


## [param big]: a direct hit on the player gets the full blast and a screen shake.
func _explode(big: bool = false) -> void:
	if _done:
		return
	_done = true
	_blast(1.6 if big else 1.0)
	if big:
		_shake(5.0)
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	for child in get_children():
		if child is Area2D:
			child.set_deferred("monitoring", false)
			child.set_deferred("monitorable", false)
	hide()
	queue_free.call_deferred()


## Stepped pixel blast and square sparks, left in the level so they outlive the missile.
func _blast(strength: float) -> void:
	var blast := Node2D.new()
	blast.z_index = 5
	var radius := 7.0 * size * strength
	var age := [0.0]
	var pixel := maxf(1.0, size * 0.5)
	var blast_color := flame_color # capture values: the missile is freed before the blast ends
	var hot_color := hull_color
	blast.draw.connect(func() -> void:
		var t: float = age[0] / 0.35
		var frame := floorf(t * 5.0) / 5.0
		var reach := snappedf(radius * (0.5 + frame), pixel)
		var outer := Color(blast_color, 0.9 * (1.0 - t))
		var inner := Color(hot_color, 1.0 - t)
		# Overlapping bars make an eight-cornered fireball on a fixed pixel grid.
		var half_reach := snappedf(reach * 0.5, pixel)
		blast.draw_rect(Rect2(-reach, -half_reach, reach * 2, half_reach * 2), outer)
		blast.draw_rect(Rect2(-half_reach, -reach, half_reach * 2, reach * 2), outer)
		var core := snappedf(radius * 0.5 * (1.0 - frame), pixel)
		blast.draw_rect(Rect2(-core, -core, core * 2, core * 2), inner)
		var hot_core := snappedf(core * 0.5, pixel)
		blast.draw_rect(Rect2(-hot_core, -hot_core, hot_core * 2, hot_core * 2), Color(1, 1, 1, 1.0 - t))
		for i in 12:
			var offset := Vector2.from_angle(TAU * i / 12.0) * radius * (0.8 + frame * 1.5)
			offset = offset.snapped(Vector2.ONE * pixel)
			blast.draw_rect(Rect2(offset, Vector2.ONE * pixel * 2), inner))
	var sparks := CPUParticles2D.new()
	sparks.one_shot = true
	sparks.explosiveness = 1.0
	sparks.amount = int(16 * strength)
	sparks.lifetime = 0.5
	sparks.spread = 180.0
	sparks.initial_velocity_min = 50.0
	sparks.initial_velocity_max = 140.0 * strength
	sparks.gravity = Vector2(0.0, 250.0)
	sparks.scale_amount_min = 1.5
	sparks.scale_amount_max = 3.0
	sparks.color = flame_color
	blast.add_child(sparks)
	get_tree().current_scene.add_child(blast)
	blast.global_position = global_position
	sparks.emitting = true
	var tween := blast.create_tween()
	tween.tween_method(func(value: float) -> void:
		age[0] = value
		blast.queue_redraw(), 0.0, 0.35, 0.35)
	tween.tween_interval(0.3) # let the sparks land
	tween.tween_callback(blast.queue_free)


func _shake(strength: float) -> void:
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return
	var tween := camera.create_tween()
	for i in 5:
		var falloff := strength * (1.0 - i / 5.0)
		tween.tween_property(camera, "offset",
			Vector2(randf_range(-falloff, falloff), randf_range(-falloff, falloff)), 0.04)
	tween.tween_property(camera, "offset", Vector2.ZERO, 0.05)


func _draw() -> void:
	# Half-size cells add 16-bit detail without enlarging the projectile or its hitboxes.
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * size * 0.5)
	_draw_exhaust()
	# Blue swept fins, built from rectangular pixel steps.
	for side in [-1, 1]:
		var top := -8.0 if side < 0 else 3.0
		draw_rect(Rect2(-12, top, 8, 5), OUTLINE)
		draw_rect(Rect2(-10, top + 1, 5, 3), BLUE_DARK)
		draw_rect(Rect2(-10, top + 1, 3, 2), stripe_color)
		draw_rect(Rect2(-12, -6 if side < 0 else 4, 2, 2), OUTLINE)
	# Dark outline, warm armour and a narrow white highlight, like the robot shells.
	draw_rect(Rect2(-12, -4, 24, 8), OUTLINE)
	draw_rect(Rect2(-10, -5, 18, 10), OUTLINE)
	draw_rect(Rect2(-10, -3, 20, 6), hull_dark)
	draw_rect(Rect2(-9, -4, 16, 6), hull_color)
	draw_rect(Rect2(-8, -3, 14, 1), Color.WHITE)
	draw_rect(Rect2(-8, 3, 16, 1), Color("ff0000"))
	# Steel nozzle and blue retaining band.
	draw_rect(Rect2(-13, -3, 4, 6), OUTLINE)
	draw_rect(Rect2(-12, -2, 2, 4), STEEL)
	draw_rect(Rect2(-12, -2, 2, 1), STEEL_LIGHT)
	draw_rect(Rect2(-4, -4, 3, 8), BLUE_SHADE)
	draw_rect(Rect2(-4, -4, 2, 5), stripe_color)
	draw_rect(Rect2(-4, -3, 1, 1), Color.WHITE)
	# Stepped red warhead: no smooth polygons or circles.
	draw_rect(Rect2(9, -4, 3, 8), OUTLINE)
	draw_rect(Rect2(12, -3, 2, 6), OUTLINE)
	draw_rect(Rect2(14, -1, 2, 2), OUTLINE)
	draw_rect(Rect2(9, -3, 2, 6), RED_SHADE)
	draw_rect(Rect2(9, -3, 2, 4), nose_color)
	draw_rect(Rect2(11, -2, 2, 4), nose_color)
	draw_rect(Rect2(13, -1, 1, 2), nose_color)
	draw_rect(Rect2(10, -2, 1, 1), Color.WHITE)
	# Inset guidance lens and two small metal rivets.
	draw_rect(Rect2(2, -1, 4, 3), OUTLINE)
	draw_rect(Rect2(3, 0, 2, 1), Color("0cffeb"))
	draw_rect(Rect2(-7, 1, 1, 1), STEEL_DARK)
	draw_rect(Rect2(7, 1, 1, 1), STEEL_DARK)


func _draw_exhaust() -> void:
	var frame := int(_age * 14.0) % 3
	var length := 6 + frame * 2
	draw_rect(Rect2(-13 - length, -2, length, 4), OUTLINE)
	draw_rect(Rect2(-12 - length, -1, length - 1, 2), Color("ff0000"))
	draw_rect(Rect2(-17 - frame, -2, 5 + frame, 4), flame_color)
	draw_rect(Rect2(-16 - frame, -1, 4 + frame, 2), hull_color)
	draw_rect(Rect2(-14, -1, 2, 2), Color.WHITE)
	if frame != 1:
		draw_rect(Rect2(-23 - frame * 2, -1, 2, 2), flame_color)
