extends Node
## Tests actual multi-finger viewport events against the current level and player.

var _failures: int = 0
var _original_mode: int
var _hud: CanvasLayer
var _touch: MobileTouchControls
var _player: Player


func _ready() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		_failures += 1


func _frames(count: int = 3) -> void:
	for i in count:
		await get_tree().physics_frame
	await get_tree().process_frame
	await get_tree().process_frame


func _finger(index: int, point: Vector2, pressed: bool, canceled: bool = false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = point
	event.pressed = pressed
	event.canceled = canceled
	get_viewport().push_input(event, true)


func _capture(name: String) -> void:
	if "--visual" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://.godot/" + name + ".png")


func _run() -> void:
	get_tree().current_scene = null
	_original_mode = ControlSettings.get_touch_mode()
	ControlSettings.set_touch_mode(ControlSettings.TouchMode.OFF)
	GameState.reset_run()
	get_tree().change_scene_to_file("res://levels/level_01/level_01.tscn")
	await _frames(6)
	_hud = get_tree().get_first_node_in_group("game_hud")
	_touch = get_tree().get_first_node_in_group("touch_controls")
	_player = get_tree().get_first_node_in_group("player")
	_check(not _touch.visible, "Off hides controls in an existing level")
	ControlSettings.set_touch_mode(ControlSettings.TouchMode.ON)
	await _frames()
	_check(_touch.visible, "On shows touch controls without reloading")
	_check(not _player._touch_active, "showing touch controls preserves physical mouse input")
	await _capture("touch_controls_layout")
	ControlSettings._touch_mode = -1
	_check(ControlSettings.get_touch_mode() == ControlSettings.TouchMode.ON, "touch preference persists to disk")
	var start := _player.global_position
	_finger(0, _touch.button_center(&"move_right"), true)
	_finger(1, _touch.button_center(&"jump"), true)
	await _frames(6)
	_check(_player.global_position.x > start.x and _player.velocity.y < 0, "two fingers move and jump the real player together")
	_check(not _player._touch_shooting, "movement-pad touches do not shoot")
	_finger(2, _touch.button_center(&"aim") + Vector2(40, -40), true)
	await _frames(3)
	_check(_player._touch_shooting and _player._aim_direction.y < -0.5, "third finger aims upward and fires while moving")
	_check(not get_tree().get_nodes_in_group("player_projectile").is_empty(), "touch aim creates real player projectiles")
	var drag := InputEventScreenDrag.new()
	drag.index = 2
	drag.position = _touch.button_center(&"aim") + Vector2(-250, 0)
	get_viewport().push_input(drag, true)
	await _frames()
	_check(_player._aim_direction.x < -0.9, "dragging outside the stick still updates aim")
	_finger(1, Vector2.ZERO, false)
	await _frames(1)
	_check(Input.is_action_pressed("move_right") and not Input.is_action_pressed("jump"), "releasing jump leaves movement held")
	_finger(2, Vector2.ZERO, false)
	_check(not _player._touch_shooting, "releasing aim outside its pad stops shooting")
	_finger(0, Vector2.ZERO, false)
	await _frames(1)
	_check(not Input.is_action_pressed("move_right"), "releasing movement outside its button stops movement")
	GameState.energy = GameState.MAX_ENERGY # dash is paid with JARVIS's energy
	_finger(3, _touch.button_center(&"dash"), true)
	await _frames(2)
	_check(_player._dash_time_left > 0, "touch dash reaches the existing player dash")
	_finger(3, Vector2.ZERO, false)
	_finger(4, _touch.button_center(&"interact"), true)
	await _frames(1)
	_check(Input.is_action_pressed("interact"), "Use supplies the existing door and lever action")
	_finger(4, Vector2.ZERO, false, true)
	await _frames(1)
	_check(not Input.is_action_pressed("interact"), "canceled touches release their action")
	GameState.tokens = 3
	GameState.energy = 0
	_finger(4, _touch.button_center(&"feed"), true)
	await _frames(2)
	_check(GameState.energy > 24 and GameState.tokens == 0, "FEED pad feeds JARVIS")
	_finger(4, Vector2.ZERO, false)
	await _frames(1)
	_finger(5, _touch.button_center(&"move_left"), true)
	_finger(6, _touch.button_center(&"move_left"), true)
	_finger(5, Vector2.ZERO, false)
	await _frames(1)
	_check(Input.is_action_pressed("move_left"), "a second finger can keep the same button held")
	_finger(6, Vector2.ZERO, false)
	await _frames(1)
	_check(not Input.is_action_pressed("move_left"), "the final finger releases the shared button")
	_finger(7, _touch.button_center(&"move_right"), true)
	_finger(8, _touch.button_center(&"aim"), true)
	_hud.set_paused(true)
	await _frames(1)
	_check(not _touch.visible and not Input.is_action_pressed("move_right") and not _player._touch_shooting, "pause hides pads and clears all held inputs")
	_hud._show_settings()
	await _capture("touch_pause_settings")
	var options := _hud._settings.get_child(1).get_child(1).get_child(1) as OptionButton
	options.item_selected.emit(ControlSettings.TouchMode.OFF)
	_hud.set_paused(false)
	_check(not _touch.visible, "the paused settings menu can disable touch controls")
	ControlSettings.set_touch_mode(ControlSettings.TouchMode.ON)
	_finger(9, _touch.button_center(&"jump"), true)
	Input.action_press("shoot") # Emulated mouse hold from a touchscreen's first finger.
	ControlSettings.set_touch_mode(ControlSettings.TouchMode.OFF)
	await _frames(1)
	_check(not Input.is_action_pressed("jump"), "disabling controls releases a held jump")
	_check(not Input.is_action_pressed("shoot"), "disabling controls clears residual emulated mouse firing")
	ControlSettings.set_touch_mode(ControlSettings.TouchMode.ON)
	_finger(10, _touch.button_center(&"move_right"), true)
	_touch.get_window().focus_exited.emit()
	await _frames(1)
	_check(not Input.is_action_pressed("move_right"), "losing window focus releases touch movement")
	_finger(11, _touch.button_center(&"aim"), true)
	GameState.player_died.emit()
	_check(not _player._touch_shooting, "death stops touch firing")
	var mouse := InputEventMouseMotion.new()
	mouse.device = InputEvent.DEVICE_ID_MOUSE
	get_viewport().push_input(mouse, true)
	_check(not _player._touch_active, "moving a physical mouse restores mouse aiming")
	_finger(12, _touch.button_center(&"move_left"), true)
	get_tree().change_scene_to_file("res://levels/level_02/level_02.tscn")
	await _frames(5)
	_check(not Input.is_action_pressed("move_left"), "level transitions clear held touch actions")
	_check(get_tree().get_nodes_in_group("touch_controls").size() == 1, "the next level creates one touch overlay")
	ControlSettings.set_touch_mode(ControlSettings.TouchMode.AUTO)
	_check(ControlSettings.touch_enabled() == (DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")), "Auto follows touch-device detection")
	ControlSettings.set_touch_mode(_original_mode)
	GameState.gameplay_active = false
	if "--visual" in OS.get_cmdline_user_args():
		get_tree().change_scene_to_file("res://ui/menus/main_menu.tscn")
		await _frames()
		var menu := get_tree().current_scene
		menu._show_page(menu._settings, false)
		await _frames()
		await _capture("touch_main_settings")
	get_tree().current_scene.queue_free()
	await _frames(6)
	print("TOUCH CONTROLS: %d failure(s)" % _failures)
	get_tree().quit(1 if _failures else 0)
