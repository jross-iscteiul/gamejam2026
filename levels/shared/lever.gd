extends Area2D
## Lever: stand on it and press E (interact) to open the linked gate (one-shot).

@export var gate: Gate


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("interact") and has_overlapping_bodies():
		set_process(false)
		$Handle.color = Color.LIME_GREEN
		$Handle.rotation_degrees = 30.0
		gate.closed = false
