extends Node2D
## Placeholder JARVIS art: a glowing orb with eyes. Replace with a sprite later.

@export var radius: float = 7.0
@export var color: Color = Color(0.35, 0.85, 1.0)
@export var eye_color: Color = Color(0.05, 0.1, 0.2)


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius + 2.0, Color(color, 0.25))
	draw_circle(Vector2.ZERO, radius, color)
	draw_rect(Rect2(-3.0, -2.0, 2.0, 3.0), eye_color)
	draw_rect(Rect2(1.0, -2.0, 2.0, 3.0), eye_color)
