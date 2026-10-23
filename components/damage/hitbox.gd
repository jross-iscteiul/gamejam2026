class_name Hitbox
extends Area2D
## Stub owned by Package 3. Deals damage to overlapping Hurtboxes (filter teams via collision mask).

@export var damage: float = 1.0
## Who gets kill credit. Defaults to the parent node.
@export var source: Node


func _ready() -> void:
	if source == null:
		source = get_parent()
