class_name Jarvis
extends Node2D
## Package 2 sidekick. Follows the player; later steps add shooting, abilities,
## speech bubble, moods and sounds. Visual is a code-drawn placeholder (see Body).

@export_group("Follow")
@export var follow_offset: Vector2 = Vector2(-20.0, -28.0) # x is mirrored by player facing
@export var follow_speed: float = 6.0 # lerp weight per second
@export var snap_distance: float = 400.0 # teleport when farther (respawn)

@export_group("Look")
@export var disabled_color: Color = Color(0.45, 0.45, 0.5)

var player: Node2D

@onready var body: Node2D = $Body


func _ready() -> void:
	add_to_group("jarvis")
	GameState.jarvis_enabled_changed.connect(_on_enabled_changed)
	_find_player()
	if player:
		global_position = _target_position()
	_on_enabled_changed(GameState.jarvis_enabled)


func _process(delta: float) -> void:
	if not is_instance_valid(player) and not _find_player():
		return
	var target := _target_position()
	if global_position.distance_to(target) > snap_distance:
		global_position = target
	else:
		global_position = global_position.lerp(target, 1.0 - exp(-follow_speed * delta))


func _find_player() -> bool:
	player = get_tree().get_first_node_in_group("player") as Node2D
	return player != null


func _target_position() -> Vector2:
	var facing: int = player.get("facing") if player.get("facing") != null else 1
	return player.global_position + Vector2(follow_offset.x * facing, follow_offset.y)


func _on_enabled_changed(enabled: bool) -> void:
	body.modulate = Color.WHITE if enabled else disabled_color
	body.queue_redraw()
