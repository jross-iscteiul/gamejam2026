class_name Health
extends Node
## Stub owned by Package 3. Add as child of anything that can be hurt.

signal damaged(amount: float, source: Node)
signal died(source: Node)

@export var max_health: float = 3.0

var current: float
var invulnerable: bool = false


func _ready() -> void:
	current = max_health


func take_damage(amount: float, source: Node = null) -> void:
	if invulnerable or current <= 0.0:
		return
	current = maxf(current - amount, 0.0)
	damaged.emit(amount, source)
	if current <= 0.0:
		died.emit(source)
