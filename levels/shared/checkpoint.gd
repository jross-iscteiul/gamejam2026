extends Area2D
## Touch to make this the player's respawn point (for pits).


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	body.respawn_point = global_position
	$Flag.color = Color.LIME_GREEN
