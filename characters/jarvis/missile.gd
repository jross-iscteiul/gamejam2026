extends Hitbox
## Big homing missile fired out of the mech's shoulder pods. It climbs out of the pod for a
## moment, then turns after the player at a limited rate, so a well-timed dash or jump shakes it
## off. Where it slams into the ground it cracks open and drops a fresh minion. Shooting it down
## in the air (two hits) stops that.

const MINION := preload("res://ui/placeholder_enemy/robot.tscn")

@export var speed: float = 85.0
@export var turn_rate: float = 2.0 # radians per second
@export var arm_seconds: float = 0.4 # straight climb before it starts homing
@export var lifetime: float = 6.0
@export var size: float = 3.0 # the missile is drawn at this multiple of a bullet-sized dart
@export var health_points: float = 2.0
## No new minion when this many units are already up, so the arena never floods.
@export var max_minions: int = 8
@export var minion_patrol_distance: float = 60.0
@export var minion_fire_interval: float = 2.2
@export var hull_color: Color = Color("9aa6bd")
@export var hull_dark: Color = Color("5f6b82")
@export var nose_color: Color = Color("ff5555")
@export var stripe_color: Color = Color("e0a53c")
@export var flame_color: Color = Color("ffb347")

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
	rotation = direction.angle()


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
	rotation = direction.angle()
	queue_redraw()
	if _age >= lifetime:
		_explode()


## Slammed into the level: a minion climbs out of the wreck, unless the arena is already full.
func _on_ground(_body: Node2D) -> void:
	if _done:
		return
	if _minion_count() < max_minions:
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


## Fireball, shock ring and sparks, left in the level so they outlive the missile.
func _blast(strength: float) -> void:
	var blast := Node2D.new()
	blast.z_index = 5
	var radius := 7.0 * size * strength
	var age := [0.0]
	blast.draw.connect(func() -> void:
		var t: float = age[0] / 0.35
		blast.draw_circle(Vector2.ZERO, radius * (0.5 + t), Color(flame_color, 0.8 * (1.0 - t)))
		blast.draw_circle(Vector2.ZERO, radius * 0.6 * (1.0 - t), Color(1.0, 0.95, 0.75, 1.0 - t))
		blast.draw_arc(Vector2.ZERO, radius * (0.7 + t * 1.2), 0.0, TAU, 32,
			Color(1.0, 1.0, 1.0, 0.7 * (1.0 - t)), 2.0))
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
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * size)
	var flicker := 0.6 + 0.4 * sin(_age * 50.0)
	draw_circle(Vector2(-7.0, 0.0), 2.8 * flicker, flame_color)
	draw_circle(Vector2(-6.0, 0.0), 1.4 * flicker, Color("fff0b0"))
	draw_rect(Rect2(-5.0, -2.0, 9.0, 4.0), hull_color)
	draw_rect(Rect2(-5.0, 1.0, 9.0, 1.0), hull_dark)
	draw_rect(Rect2(-1.0, -2.0, 1.5, 4.0), stripe_color)
	draw_colored_polygon(PackedVector2Array([Vector2(4.0, -2.0), Vector2(7.0, 0.0), Vector2(4.0, 2.0)]), nose_color)
	draw_colored_polygon(PackedVector2Array([Vector2(-5.0, -2.0), Vector2(-3.0, -2.0), Vector2(-6.0, -4.0)]), hull_dark)
	draw_colored_polygon(PackedVector2Array([Vector2(-5.0, 2.0), Vector2(-3.0, 2.0), Vector2(-6.0, 4.0)]), hull_dark)
