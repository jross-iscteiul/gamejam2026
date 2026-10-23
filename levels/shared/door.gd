extends Area2D
## Exit door: stand in front and press E (interact) to load the next level.

@export_file("*.tscn") var next_level: String


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("interact") and has_overlapping_bodies():
		set_process(false)
		GameState.level_completed.emit(GameState.current_level)
		get_tree().change_scene_to_file.call_deferred(next_level)
