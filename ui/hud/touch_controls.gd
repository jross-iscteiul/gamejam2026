class_name MobileTouchControls
extends Control
## One finger per control; the right stick aims and fires while other fingers move/jump.
## Reuses the agreed InputMap actions and a small Player aim/fire adapter.

const BUTTONS := [&"move_left", &"move_right", &"jump", &"dash", &"interact"]
const LABELS := {&"move_left": "<", &"move_right": ">", &"jump": "JUMP", &"dash": "DASH", &"interact": "USE", &"shield": "USE",}
var _fingers: Dictionary = {}
var _held: Dictionary = {}
var _aim_finger: int = -1
var _aim_direction := Vector2.RIGHT
var _stick_offset := Vector2.ZERO
var _paused: bool = false
var _using_touch: bool = false
var _player: Player
var _font: Font


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_to_group("touch_controls")
	_player = get_tree().get_first_node_in_group("player") as Player
	_font = GameUI.theme().default_font
	get_window().focus_exited.connect(release_all)
	GameState.player_died.connect(release_all)
	resized.connect(queue_redraw)
	apply_preferences()


func apply_preferences() -> void:
	release_all()
	visible = ControlSettings.touch_enabled() and not _paused
	if not ControlSettings.touch_enabled():
		_using_touch = false
	_sync_player()
	queue_redraw()


func set_gameplay_paused(active: bool) -> void:
	_paused = active
	apply_preferences()


func button_center(action: StringName) -> Vector2:
	match action:
		&"move_left": return Vector2(130, size.y - 170)
		&"move_right": return Vector2(330, size.y - 170)
		&"jump": return Vector2(size.x - 420, size.y - 150)
		&"dash": return Vector2(size.x - 620, size.y - 150)
		&"interact": return Vector2(size.x - 420, size.y - 335)
	return Vector2(size.x - 170, size.y - 180)


func _radius(action: StringName) -> float:
	return 66.0 if action == &"interact" else 82.0


func _input(event: InputEvent) -> void:
	if not visible or _paused:
		return
	if event is InputEventMouseMotion and event.device != InputEvent.DEVICE_ID_EMULATION and _fingers.is_empty():
		_using_touch = false
		_sync_player()
	if event is InputEventScreenTouch:
		if event.canceled or not event.pressed:
			if _fingers.has(event.index):
				_release_finger(event.index)
				get_viewport().set_input_as_handled()
		elif not _fingers.has(event.index):
			var point: Vector2 = get_global_transform().affine_inverse() * event.position
			for action: StringName in BUTTONS:
				if point.distance_to(button_center(action)) <= _radius(action):
					_using_touch = true
					if _aim_finger < 0 and action in [&"move_left", &"move_right"]:
						_aim_direction = Vector2.LEFT if action == &"move_left" else Vector2.RIGHT
					_sync_player()
					_fingers[event.index] = action
					_held[action] = int(_held.get(action, 0)) + 1
					if _held[action] == 1:
						_send_action(action, true)
					get_viewport().set_input_as_handled()
					queue_redraw()
					return
			if _aim_finger < 0 and point.distance_to(button_center(&"aim")) <= 110:
				_using_touch = true
				_fingers[event.index] = &"aim"
				_aim_finger = event.index
				_update_aim(point)
				get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and _fingers.has(event.index):
		if event.index == _aim_finger:
			_update_aim(get_global_transform().affine_inverse() * event.position)
		get_viewport().set_input_as_handled()


func _send_action(action: StringName, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	Input.parse_input_event(event)


func _update_aim(point: Vector2) -> void:
	var offset := point - button_center(&"aim")
	_stick_offset = offset.limit_length(58)
	if offset.length() >= 12:
		_aim_direction = offset.normalized()
	elif is_instance_valid(_player):
		_aim_direction = Vector2(_player.facing, 0)
	_sync_player()
	queue_redraw()


func _release_finger(index: int) -> void:
	var action: StringName = _fingers[index]
	_fingers.erase(index)
	if action == &"aim":
		_aim_finger = -1
		_stick_offset = Vector2.ZERO
		_sync_player()
	else:
		_held[action] = int(_held[action]) - 1
		if _held[action] <= 0:
			_held.erase(action)
			_send_action(action, false)
	queue_redraw()


func release_all() -> void:
	for action: StringName in _held.keys():
		_send_action(action, false)
	if _using_touch and not _fingers.is_empty():
		# Mobile browsers may still consider the first touch an emulated left click.
		_send_action(&"shoot", false)
	_fingers.clear()
	_held.clear()
	_aim_finger = -1
	_stick_offset = Vector2.ZERO
	_sync_player()
	queue_redraw()


func _sync_player() -> void:
	if is_instance_valid(_player):
		_player.set_touch_input(visible and not _paused and _using_touch, _aim_direction, _aim_finger >= 0)


func _exit_tree() -> void:
	release_all()
	if is_instance_valid(_player):
		_player.set_touch_input(false, Vector2.ZERO, false)


func _draw() -> void:
	if not _font:
		return
	for action: StringName in BUTTONS:
		var center := button_center(action)
		var active := _held.has(action)
		_draw_pad(center, _radius(action), active)
		var label_size := 40 if action in [&"move_left", &"move_right"] else 32
		_text(LABELS[action], center + Vector2(0, label_size / 2.0), label_size)
	var aim := button_center(&"aim")
	_draw_pad(aim, 110, _aim_finger >= 0)
	if _aim_finger >= 0:
		draw_line(aim, aim + _stick_offset, GameUI.CYAN, 5)
		draw_circle(aim + _stick_offset, 24, GameUI.CYAN)
	else:
		_text("AIM", aim + Vector2(0, -10), 32)
		_text("FIRE", aim + Vector2(0, 30), 32)
	_text("DRAG TO AIM", aim + Vector2(0, 145), 16)


func _draw_pad(center: Vector2, radius: float, active: bool) -> void:
	draw_circle(center, radius, Color(GameUI.PANEL, 0.82))
	draw_arc(center, radius, 0, TAU, 48, GameUI.CYAN if active else GameUI.EDGE, 4)


func _text(text: String, baseline: Vector2, font_size: int) -> void:
	var width := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(_font, baseline - Vector2(width / 2, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, GameUI.TEXT)
