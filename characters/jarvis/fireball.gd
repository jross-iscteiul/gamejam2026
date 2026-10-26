extends Hitbox
## One fireball of the barrage that rains down when a shield pod pops. It blinks at the top of
## the screen for a moment (harmless, so the player can read where it lands), then drops
## straight down and bursts on the first island or player it hits.

@export var speed: float = 170.0
@export var warning: float = 0.4
@export var radius: float = 4.0
@export var core_color: Color = Color("fff0b0")
@export var fire_color: Color = Color("ff8a2a")
@export var ember_color: Color = Color("e0442a")

var _age: float = 0.0
var _life: float = 4.0


func _ready() -> void:
	collision_layer = 16
	collision_mask = 3 # world and the player
	monitoring = false
	monitorable = false # the player's hurtbox is the side that detects us
	var collider := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = radius
	collider.shape = shape
	add_child(collider)
	add_to_group("enemy_projectile")
	super()
	body_entered.connect(func(_body: Node2D) -> void: queue_free())
	area_entered.connect(func(area: Area2D) -> void:
		if area is Hurtbox:
			queue_free())


func _physics_process(delta: float) -> void:
	super(delta)
	_age += delta
	queue_redraw()
	if _age < warning:
		return
	if not monitoring:
		monitoring = true
		monitorable = true
	position.y += speed * delta
	_life -= delta
	if _life <= 0.0:
		queue_free()


func _draw() -> void:
	if _age < warning:
		if int(_age * 16.0) % 2 == 0:
			draw_circle(Vector2.ZERO, radius * 0.6, Color(fire_color, 0.9))
			draw_line(Vector2(0.0, radius), Vector2(0.0, radius + 6.0), Color(fire_color, 0.6), 1.0)
		return
	for i in 3: # a short trail of embers above the ball
		var flicker := 0.7 + 0.3 * sin(_age * 40.0 + i)
		draw_circle(Vector2(0.0, -radius * (1.2 + i * 0.9)), radius * (0.7 - i * 0.18) * flicker,
			Color(ember_color, 0.7 - i * 0.2))
	draw_circle(Vector2.ZERO, radius, fire_color)
	draw_circle(Vector2(0.0, radius * 0.2), radius * 0.5, core_color)
