extends Node2D
## Invisible arena reinforcement controller. Units drop below the ceiling, fall through the
## raised platforms and patrol the complete floor between the gate and the far wall.

const MINION := preload("res://ui/placeholder_enemy/robot.tscn")

@export var interval: float = 5.0
@export var first_delay: float = 2.5
@export var per_release: int = 2
@export var max_alive: int = 12
@export var patrol_bounds: Vector2 = Vector2(868.0, 1500.0)
@export var drop_y: float = 48.0
@export var minion_fire_interval: float = 2.2

var active: bool = false
var _offline: bool = false
var _left: float = 0.0
var _drop_index: int = 0


func _ready() -> void:
	add_to_group("minion_spawner")


func set_active(value: bool) -> void:
	if _offline:
		return
	active = value
	_left = first_delay


func _process(delta: float) -> void:
	if not active or _offline:
		return
	_left -= delta
	if _left <= 0.0:
		_left = interval
		for i in per_release:
			drop_minion()


## Missile impacts use the same drop route, patrol limits and population cap.
func drop_minion() -> void:
	if not active or _offline:
		return
	var alive := get_tree().get_nodes_in_group("enemy").filter(func(node: Node) -> bool:
		return not node.is_in_group("boss") and not node.is_in_group("jarvis") \
			and not ("_dead" in node and node._dead)).size()
	if alive >= max_alive:
		return
	var minion := MINION.instantiate()
	minion.patrol_bounds = patrol_bounds
	minion.fire_interval = minion_fire_interval
	# Cycle across the arena so a wave spreads out instead of stacking in one column.
	var fraction := (float(_drop_index % 5) + 0.5) / 5.0
	_drop_index += 2
	minion.position = Vector2(lerpf(patrol_bounds.x + 24, patrol_bounds.y - 24, fraction), drop_y)
	get_tree().current_scene.add_child(minion)


func shut_down() -> void:
	_offline = true
	active = false
