extends Area2D
## Bottom of a pit: anything that falls in respawns at its last checkpoint.


func _ready() -> void:
	collision_layer = 64 # hazards (layer 7)
	collision_mask = 2 # player
	body_entered.connect(func(body: Node2D) -> void: body.respawn.call_deferred())
