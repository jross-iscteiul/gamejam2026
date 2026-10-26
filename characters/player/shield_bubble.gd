class_name ShieldBubble
extends Node2D
## Placeholder shield look: a pulsing translucent bubble around the player. Swap for art later.

@export var radius: float = 20.0
@export var color: Color = Color(0.35, 0.85, 1.0)
@export var pulse_speed: float = 6.0

var _time: float = 0.0


func _process(delta: float) -> void:
	if visible:
		_time += delta
		queue_redraw()


func _draw() -> void:
	var pulse := 0.5 + 0.5 * sin(_time * pulse_speed)
	draw_circle(Vector2.ZERO, radius, Color(color, 0.15 + 0.1 * pulse))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, Color(color, 0.6 + 0.3 * pulse), 1.0)
