extends Hitbox

@export var speed: float = 130.0
var direction := Vector2.LEFT
var _life: float = 3.0


func _ready() -> void:
	super()
	body_entered.connect(func(_body: Node2D) -> void: queue_free())
	area_entered.connect(func(area: Area2D) -> void:
		if area is Hurtbox:
			queue_free()
	)


func _physics_process(delta: float) -> void:
	position += direction * speed * delta
	_life -= delta
	if _life <= 0.0:
		queue_free()


func _draw() -> void:
	draw_rect(Rect2(-3, -2, 6, 4), GameUI.RED)
	draw_rect(Rect2(-1, -1, 2, 2), Color("fff0d2"))
