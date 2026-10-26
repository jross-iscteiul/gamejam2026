class_name MobileTouchControls
extends Control
## One finger per control; a slide bar moves, the right stick aims and fires while other fingers jump.
## Reuses the agreed InputMap actions and a small Player aim/fire adapter.

const BUTTONS := [&"jump", &"dash", &"interact", &"feed"]
const LABELS := {&"jump": "JUMP", &"dash": "DASH", &"interact": "USE", &"shield": "USE", &"feed": "FEED",}
const MOVE_PADDING := 48.0
const MOVE_DEAD_ZONE := 30.0
var _fingers: Dictionary = {}
var _held: Dictionary = {}
var _move_finger: int = -1
var _move_action: StringName = &""
var _move_thumb_x: float = 0.0
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
		&"jump": return Vector2(size.x - 420, size.y - 150)
		&"dash": return Vector2(size.x - 620, size.y - 150)
		&"interact": return Vector2(size.x - 420, size.y - 335)
		&"feed": return Vector2(size.x - 620, size.y - 335) # above DASH, like USE above JUMP
	return Vector2(size.x - 170, size.y - 180)


## Bottom-left bar covering roughly the left third of the screen.
func move_bar_rect() -> Rect2:
	return Rect2(MOVE_PADDING, size.y - 250, size.x / 3.0 - MOVE_PADDING, 160)


## Point at fraction t (0 = far left, 1 = far right) along the bar's centre line.
func move_bar_point(t: float) -> Vector2:
	var rect := move_bar_rect()
	return rect.position + Vector2(rect.size.x * t, rect.size.y / 2.0)


func _radius(action: StringName) -> float:
	return 66.0 if action in [&"interact", &"feed"] else 82.0


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
			if move_bar_rect().has_point(point):
				if _move_finger < 0:
					_using_touch = true
					_fingers[event.index] = &"move"
					_move_finger = event.index
					_update_move(point.x)
				get_viewport().set_input_as_handled()
				return
			for action: StringName in BUTTONS:
				if point.distance_to(button_center(action)) <= _radius(action):
					_using_touch = true
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
		elif event.index == _move_finger:
			_update_move((get_global_transform().affine_inverse() * event.position).x)
		get_viewport().set_input_as_handled()


func _send_action(action: StringName, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	Input.parse_input_event(event)


func _update_move(x: float) -> void:
	var rect := move_bar_rect()
	var offset := x - rect.get_center().x
	var action: StringName = &""
	if offset < -MOVE_DEAD_ZONE:
		action = &"move_left"
	elif offset > MOVE_DEAD_ZONE:
		action = &"move_right"
	_move_thumb_x = clampf(x, rect.position.x, rect.end.x)
	if action != _move_action:
		_set_move_action(action)
	if action != &"" and _aim_finger < 0:
		_aim_direction = Vector2.LEFT if action == &"move_left" else Vector2.RIGHT
	_sync_player()
	queue_redraw()


func _set_move_action(action: StringName) -> void:
	if _move_action != &"":
		_held.erase(_move_action)
		_send_action(_move_action, false)
	_move_action = action
	if action != &"":
		_held[action] = 1
		_send_action(action, true)


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
	elif action == &"move":
		_move_finger = -1
		_set_move_action(&"")
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
	_move_finger = -1
	_move_action = &""
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
	_draw_move_bar()
	for action: StringName in BUTTONS:
		var center := button_center(action)
		_draw_pad(center, _radius(action), _held.has(action))
		_text(LABELS[action], center + Vector2(0, 16), 32)
	var aim := button_center(&"aim")
	_draw_pad(aim, 110, _aim_finger >= 0)
	if _aim_finger >= 0:
		draw_line(aim, aim + _stick_offset, GameUI.CYAN, 5)
		draw_circle(aim + _stick_offset, 24, GameUI.CYAN)
	else:
		_text("AIM", aim + Vector2(0, -10), 32)
		_text("FIRE", aim + Vector2(0, 30), 32)
	_text("DRAG TO AIM", aim + Vector2(0, 145), 16)


func _draw_move_bar() -> void:
	var rect := move_bar_rect()
	var mid := rect.get_center()
	draw_rect(rect, Color(GameUI.PANEL, 0.82))
	if _move_action == &"move_left":
		draw_rect(Rect2(rect.position, Vector2(mid.x - MOVE_DEAD_ZONE - rect.position.x, rect.size.y)), Color(GameUI.CYAN, 0.25))
	elif _move_action == &"move_right":
		draw_rect(Rect2(Vector2(mid.x + MOVE_DEAD_ZONE, rect.position.y), Vector2(rect.end.x - mid.x - MOVE_DEAD_ZONE, rect.size.y)), Color(GameUI.CYAN, 0.25))
	draw_rect(rect, GameUI.CYAN if _move_finger >= 0 else GameUI.EDGE, false, 4)
	for side in [-1.0, 1.0]:
		draw_line(Vector2(mid.x + side * MOVE_DEAD_ZONE, rect.position.y + 20), Vector2(mid.x + side * MOVE_DEAD_ZONE, rect.end.y - 20), GameUI.EDGE, 3)
	_text("<", Vector2(rect.position.x + 50, mid.y + 20), 40)
	_text(">", Vector2(rect.end.x - 50, mid.y + 20), 40)
	if _move_finger >= 0:
		draw_circle(Vector2(_move_thumb_x, mid.y), 36, GameUI.CYAN)


func _draw_pad(center: Vector2, radius: float, active: bool) -> void:
	draw_circle(center, radius, Color(GameUI.PANEL, 0.82))
	draw_arc(center, radius, 0, TAU, 48, GameUI.CYAN if active else GameUI.EDGE, 4)


func _text(text: String, baseline: Vector2, font_size: int) -> void:
	var width := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(_font, baseline - Vector2(width / 2, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, GameUI.TEXT)
