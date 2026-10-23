class_name PlayerBullet
extends Hitbox
## Player projectile. Flies straight and disappears on hitting the world or an enemy.

@export var speed: float = 400.0
@export var lifetime: float = 1.5

var direction: Vector2 = Vector2.RIGHT
var texture: Texture2D
var texture_scale: float = 1.0

@onready var _sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	super()
	rotation = direction.angle()
	if texture:
		_sprite.texture = texture
	_sprite.scale = Vector2.ONE * texture_scale
	body_entered.connect(_on_hit)
	area_entered.connect(_on_hit)


func _physics_process(delta: float) -> void:
	position += direction * speed * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()


func _on_hit(_other: Node2D) -> void:
	queue_free()
