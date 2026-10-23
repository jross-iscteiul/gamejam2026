extends Node2D
## Package 3 entities layer. Keeps HUD/economy setup outside the level owner's scripts.

const HUD := preload("res://ui/hud/hud.tscn")
@export_range(1, 4) var level_number: int = 1


func _ready() -> void:
	_start.call_deferred()


func _start() -> void:
	GameState.begin_level(level_number)
	if get_tree().get_first_node_in_group("game_hud") == null:
		add_child(HUD.instantiate())


func _exit_tree() -> void:
	GameState.gameplay_active = false
