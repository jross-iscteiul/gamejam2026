extends Node2D
## Player test scene. Keys 1-6 switch characters (handled by Player); K applies damage for testing death.

@onready var _player: Player = $Player
@onready var _label: Label = $SkinLabel


func _ready() -> void:
	# Fixed view of the whole room instead of the player's follow camera.
	$Camera2D.make_current()
	_player.skin_changed.connect(func(_skin: PlayerSkin) -> void: _update_label())
	_update_label()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.keycode == KEY_K:
		_player.take_damage(1.0)


func _update_label() -> void:
	_label.text = "1-6 switch  |  K damage  |  %s" % (Player.SKINS[_player.skin_index] as PlayerSkin).display_name
