class_name Hitbox
extends Area2D
## Damage area. Collision masks select targets; Hurtbox rejects friendly hits as well.

@export var damage: float = 1.0
## Who gets kill credit. Defaults to the parent node.
@export var source: Node
## Contact hazards retry after the target's invincibility expires. Projectiles leave this off.
@export var continuous: bool = false
@export var instant_kill: bool = false


func _ready() -> void:
	if source == null:
		source = get_parent()
	area_entered.connect(_on_area_entered)


func _physics_process(_delta: float) -> void:
	if continuous:
		for area in get_overlapping_areas():
			_on_area_entered(area)


func _on_area_entered(area: Area2D) -> void:
	if area is Hurtbox:
		area.receive_hit(self)
