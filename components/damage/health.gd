class_name Health
extends Node
## Shared health. Keep manual shield invulnerability separate from timed hit/dash immunity.

signal damaged(amount: float, source: Node)
signal died(source: Node)
signal changed(current: float, maximum: float)

@export var max_health: float = 3.0
@export_range(0.0, 5.0) var invincibility_duration: float = 0.65

var current: float
var invulnerable: bool = false
var _invincibility_left: float = 0.0


func _ready() -> void:
	restore()


func _physics_process(delta: float) -> void:
	_invincibility_left = maxf(0.0, _invincibility_left - delta)


func can_take_damage() -> bool:
	return current > 0.0 and not invulnerable and _invincibility_left <= 0.0


func grant_invulnerability(seconds: float) -> void:
	_invincibility_left = maxf(_invincibility_left, seconds)


func restore() -> void:
	current = max_health
	invulnerable = false
	_invincibility_left = 0.0
	changed.emit(current, max_health)


func take_damage(amount: float, source: Node = null) -> void:
	if amount <= 0.0 or not can_take_damage():
		return
	var applied := minf(amount, current)
	current = maxf(current - amount, 0.0)
	grant_invulnerability(invincibility_duration)
	changed.emit(current, max_health)
	damaged.emit(applied, source)
	if current <= 0.0:
		died.emit(source)


## Pits/scripted lethal hazards bypass shields, dash immunity and hit invincibility.
func kill(source: Node = null) -> void:
	if current <= 0.0:
		return
	var remaining := current
	current = 0.0
	changed.emit(current, max_health)
	damaged.emit(remaining, source)
	died.emit(source)
