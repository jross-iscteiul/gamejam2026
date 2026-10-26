@tool
class_name Hazard
extends Node2D
## Base for level hazards: difficulty scaling and a damage Hitbox on the "hazards" layer (7)
## that only hits the player (layer 2). Visuals are placeholder shapes drawn in code.

const HAZARD_LAYER := 64 # layer 7 "hazards"
const PLAYER_LAYER := 2

## Speed/timing multiplier set per level by the generator (1.0 = level 1). Never scales damage.
@export_range(0.5, 3.0) var difficulty: float = 1.0
## Knockback speed on touch, through the player's apply_knockback() (0 = no push).
@export var knockback: float = 0.0
## Lock the player's steering until it lands after the knockback.
@export var stun: bool = false

var time := 0.0


func _process(delta: float) -> void:
	time += delta
	queue_redraw()


## Adds a continuous 1-damage Hitbox (or instant kill) with the given shape at a local offset.
func make_hitbox(shape: Shape2D, offset := Vector2.ZERO, parent: Node = self, kill := false) -> Hitbox:
	var hitbox := Hitbox.new()
	hitbox.name = "Hitbox"
	hitbox.collision_layer = HAZARD_LAYER
	hitbox.collision_mask = PLAYER_LAYER
	hitbox.monitorable = true
	hitbox.continuous = true
	hitbox.instant_kill = kill
	hitbox.damage = 1.0
	hitbox.source = self
	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.position = offset
	hitbox.add_child(collision)
	parent.add_child(hitbox)
	hitbox.area_entered.connect(_on_touch)
	return hitbox


func _on_touch(area: Area2D) -> void:
	var player := area.get_parent()
	if knockback > 0.0 and player.has_method("apply_knockback"):
		player.apply_knockback(knockback_impulse(player), stun)


## Knockback velocity: sideways away from the hitbox plus a hop.
## Dead centre pushes the player back the way it faces.
func knockback_impulse(target: Node2D) -> Vector2:
	var dx := target.global_position.x - (find_child("Hitbox", true, false) as Node2D).global_position.x
	var side := signf(dx) if absf(dx) >= 4.0 else -float(target.get("facing"))
	return Vector2(side * knockback, -knockback * 0.45)


static func rect(size: Vector2) -> RectangleShape2D:
	var shape := RectangleShape2D.new()
	shape.size = size
	return shape
