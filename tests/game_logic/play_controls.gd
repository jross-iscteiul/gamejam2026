extends CanvasLayer
## Manual Package 3 playground. These ability inputs are test adapters for the absent JARVIS.
## Production input handling belongs to Package 2; this script is never loaded by normal levels.

var _shield_active: bool = false
var _shield_bill_left: float = 0.0
var _boss_demo: bool = false
@onready var _player: Player = get_tree().get_first_node_in_group("player")


func _ready() -> void:
	GameState.reset_run()
	var instructions := GameUI.label("PACKAGE 3 TEST\nT +10 TOKENS / F FEED (HUD) / Y ZERO ENERGY / K DAMAGE\nRIGHT CLICK SHIELD (2/s) / B JUMP BOOST (3) / G BOSS BAR", 16)
	instructions.theme = GameUI.theme()
	instructions.position = Vector2(48, 930)
	instructions.mouse_filter = Control.MOUSE_FILTER_IGNORE
	instructions.add_theme_color_override("font_shadow_color", GameUI.INK)
	instructions.add_theme_constant_override("shadow_offset_x", 3)
	instructions.add_theme_constant_override("shadow_offset_y", 3)
	add_child(instructions)


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_T: GameState.add_tokens(10)
		KEY_Y: GameState.energy = 0
		KEY_K: _player.take_damage(1, self)
		KEY_B:
			if GameState.use_ability(&"boost_jump"):
				_player.boost_jump()
		KEY_G:
			_boss_demo = not _boss_demo
			GameState.boss_health_changed.emit(75 if _boss_demo else 0, 100)


func _physics_process(delta: float) -> void:
	_shield_bill_left -= delta
	var wants_shield := Input.is_action_pressed("shield") and GameState.jarvis_enabled
	if wants_shield and _shield_bill_left <= 0.0:
		wants_shield = GameState.use_ability(&"shield")
		_shield_bill_left = 1.0 if wants_shield else 0.0
	if not wants_shield:
		_shield_bill_left = 0.0
	if wants_shield != _player.shielded:
		_shield_active = wants_shield
		_player.set_shield(_shield_active)
