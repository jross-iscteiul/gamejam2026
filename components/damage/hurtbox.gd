class_name Hurtbox
extends Area2D
## Stub owned by Package 3. Receives hits and forwards them to a Health node.

@export var health: Health


func _ready() -> void:
	area_entered.connect(_on_area_entered)


func _on_area_entered(area: Area2D) -> void:
	if area is Hitbox:
		take_damage(area.damage, area.source)


func take_damage(amount: float, source: Node = null) -> void:
	if health:
		health.take_damage(amount, source)
