extends Node2D
## Player test scene. Keys 1-4 switch characters; K applies damage for testing death.

@onready var _player: Player = $Player
@onready var _label: Label = $SkinLabel


func _ready() -> void:
	_update_label()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not key or not key.pressed or key.echo:
		return
	if key.keycode >= KEY_1 and key.keycode <= KEY_4:
		_player.skin_index = key.keycode - KEY_1
		_update_label()
	elif key.keycode == KEY_K:
		_player.take_damage(1.0)


func _update_label() -> void:
	_label.text = "1-4 switch  |  K damage  |  %s" % (Player.SKINS[_player.skin_index] as PlayerSkin).display_name
