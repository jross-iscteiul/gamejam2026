extends Hitbox
## Homing missile fired out of the mech's shoulder pods. It climbs out of the pod for a moment,
## then turns after the player at a limited rate, so a well-timed dash or jump shakes it off.
## One player shot destroys it.

@export var speed: float = 105.0
@export var turn_rate: float = 2.4 # radians per second
@export var arm_seconds: float = 0.35 # straight climb before it starts homing
@export var lifetime: float = 5.0
@export var hull_color: Color = Color("9aa6bd")
@export var nose_color: Color = Color("ff5555")
@export var flame_color: Color = Color("ffb347")

var direction := Vector2.UP
var target: Node2D
var _age: float = 0.0


func _ready() -> void:
	collision_layer = 16
	collision_mask = 3 # world and the player
	monitorable = true
	_add_shape(self, 3.0)
	add_to_group("enemy_projectile")
	super()
	body_entered.connect(func(_body: Node2D) -> void: queue_free())
	area_entered.connect(func(area: Area2D) -> void:
		if area is Hurtbox:
			queue_free())
	# Shootable: a one-hit health on the enemy hurtbox layer.
	var health := Health.new()
	health.max_health = 1.0
	health.invincibility_duration = 0.0
	add_child(health)
	health.died.connect(func(_source: Node) -> void: queue_free())
	var hurtbox := Hurtbox.new()
	hurtbox.health = health
	hurtbox.collision_layer = 4
	hurtbox.collision_mask = 8
	_add_shape(hurtbox, 5.0)
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
	_age += delta
	if _age > arm_seconds and is_instance_valid(target):
		var wanted := global_position.direction_to(target.global_position + Vector2(0.0, -6.0))
		var turn := clampf(direction.angle_to(wanted), -turn_rate * delta, turn_rate * delta)
		direction = direction.rotated(turn)
	position += direction * speed * delta
	rotation = direction.angle()
	queue_redraw()
	if _age >= lifetime:
		queue_free()


func _draw() -> void:
	var flicker := 0.6 + 0.4 * sin(_age * 50.0)
	draw_circle(Vector2(-6.0, 0.0), 2.5 * flicker, flame_color)
	draw_rect(Rect2(-5.0, -2.0, 8.0, 4.0), hull_color)
	draw_rect(Rect2(3.0, -1.5, 3.0, 3.0), nose_color)
	draw_line(Vector2(-5.0, -3.0), Vector2(-3.0, -2.0), hull_color, 1.0) # fins
	draw_line(Vector2(-5.0, 3.0), Vector2(-3.0, 2.0), hull_color, 1.0)
