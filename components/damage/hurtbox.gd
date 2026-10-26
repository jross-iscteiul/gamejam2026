class_name Hurtbox
extends Area2D
## Receives damage from hostile layers only. Supports either side monitoring overlaps.

@export var health: Health
## Armour: incoming damage is scaled by this before it reaches the health. 1 = full damage.
@export_range(0.0, 1.0) var damage_multiplier: float = 1.0
var _last_hits: Dictionary = {}


func _ready() -> void:
	area_entered.connect(_on_area_entered)


func _on_area_entered(area: Area2D) -> void:
	if area is Hitbox:
		receive_hit(area)


func receive_hit(hitbox: Hitbox) -> void:
	if not health or (collision_mask & hitbox.collision_layer) == 0:
		return
	# Both areas can observe the same contact in one frame; damage must only apply once.
	var frame := Engine.get_physics_frames()
	if _last_hits.get(hitbox.get_instance_id(), -1) == frame:
		return
	_last_hits[hitbox.get_instance_id()] = frame
	if _last_hits.size() > 64:
		_last_hits = {hitbox.get_instance_id(): frame}
	var source: Node = hitbox.source if is_instance_valid(hitbox.source) else null
	if hitbox.instant_kill:
		health.kill(source)
	else:
		take_damage(hitbox.damage, source)


func take_damage(amount: float, source: Node = null) -> void:
	if health:
		health.take_damage(amount * damage_multiplier, source)
