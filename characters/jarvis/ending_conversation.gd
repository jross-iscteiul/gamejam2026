extends Node
## Post-victory exchange. The mech has already exploded and the run timer has stopped;
## JARVIS remains as a tiny, harmless drone on the floor until the credits take over.

const SpeechBubble := preload("res://characters/jarvis/speech_bubble.gd")

signal advanced
signal finished

@export var tiny_scale: float = 0.65
@export var settle_seconds: float = 0.55

var done: bool = false
var _jarvis: Jarvis
var _player: Player
var _player_bubble: SpeechBubble
var _talking: SpeechBubble
var _waiting: bool = false
var _hint_layer: CanvasLayer
var _hint: Label


func _ready() -> void:
	add_to_group("boss_ending")
	_jarvis = get_parent() as Jarvis
	_player = _jarvis.player
	_run.call_deferred()


func _run() -> void:
	_jarvis._clear_assists()
	_jarvis.remove_from_group("enemy")
	_jarvis.bubble.clear()
	_jarvis.bubble.scale = Vector2.ONE
	_jarvis.bubble.position = Vector2(0, -12)
	_jarvis.bubble.auto_hide = false
	_jarvis.body.power = 0.0 # the rotor and thruster stay off even when the screen speaks
	_jarvis.body.modulate = Color(0.8, 0.8, 0.8, 1)
	_jarvis.body.set_face("annoyed")
	if _jarvis.mech != null:
		_jarvis.mech.hide()
	var floor_at := _floor_position()
	_jarvis.facing = -1 if is_instance_valid(_player) and _player.global_position.x <= floor_at.x else 1
	_jarvis.body.rotation = deg_to_rad(12 * _jarvis.facing)
	var tiny_at := floor_at - Vector2(0, 8 * tiny_scale)
	var tween := create_tween().set_parallel()
	tween.tween_property(_jarvis, "global_position", tiny_at, settle_seconds) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_jarvis.body, "position", Vector2.ZERO, settle_seconds)
	tween.tween_property(_jarvis.body, "scale", Vector2(_jarvis.facing, 1) * tiny_scale, settle_seconds)
	if is_instance_valid(_player):
		_player.input_locked = true
		_player.held = true
		_player.velocity = Vector2.ZERO
		_player.get_node("GunPivot").hide()
		var side := -1.0 if _player.global_position.x <= floor_at.x else 1.0
		var player_at := floor_at + Vector2(side * 52, -Player.FEET_Y)
		tween.tween_property(_player, "global_position", player_at, settle_seconds) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_player.facing = int(-side)
		_player.get_node("Body").scale.x = -side
		var sprite: AnimatedSprite2D = _player.get_node("Body/AnimatedSprite2D")
		sprite.play(&"idle")
		_player_bubble = SpeechBubble.new()
		_player_bubble.position = Vector2(0, -24)
		_player_bubble.z_index = 10
		_player_bubble.auto_hide = false
		_player_bubble.mood_colors["neutral"] = GameUI.GOLD
		_player.add_child(_player_bubble)
	_build_hint()
	await tween.finished
	var lines := Dialogue.get_sequence("ending")
	for i in lines.size():
		var player_line := i % 2 == 1
		if player_line and not is_instance_valid(_player_bubble):
			continue
		_jarvis.bubble.clear()
		if is_instance_valid(_player_bubble):
			_player_bubble.clear()
		_talking = _player_bubble if player_line else _jarvis.bubble
		if not player_line:
			_jarvis.body.set_face("annoyed" if i < 4 else "neutral")
		_talking.say(lines[i], "neutral")
		_hint.show()
		_waiting = true
		await advanced
		_waiting = false
	_jarvis.bubble.clear()
	_jarvis.body.set_face("off")
	if is_instance_valid(_player_bubble):
		_player_bubble.queue_free()
	_hint_layer.queue_free()
	# Keep the player still through the credits; cleanup restores normal physics on exit.
	done = true
	finished.emit()


## Ignore one-way platforms so the tiny remnant and the player settle on the arena floor.
func _floor_position() -> Vector2:
	var origin := _jarvis.global_position
	var ray_y := origin.y
	var camera := get_viewport().get_camera_2d()
	if camera != null:
		origin.x = clampf(origin.x, camera.limit_left + 112.0, camera.limit_right - 112.0)
		# Start below the raised islands even if the boss was defeated near the ceiling.
		if camera.limit_bottom > origin.y and camera.limit_bottom < origin.y + 2048:
			ray_y = maxf(ray_y, camera.limit_bottom - 96.0)
	var query := PhysicsRayQueryParameters2D.create(Vector2(origin.x, ray_y), Vector2(origin.x, ray_y + 2048), 1)
	var hit := _jarvis.get_world_2d().direct_space_state.intersect_ray(query)
	return hit.position if not hit.is_empty() else origin + Vector2(0, 48)


func _build_hint() -> void:
	_hint_layer = CanvasLayer.new()
	_hint_layer.layer = 21
	add_child(_hint_layer)
	_hint = GameUI.label("TAP TO CONTINUE" if ControlSettings.touch_enabled() else "SPACE / CLICK TO CONTINUE", 16, GameUI.MUTED)
	_hint.theme = GameUI.theme()
	_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.offset_left = -420
	_hint.offset_right = 420
	_hint.offset_top = -160
	_hint.offset_bottom = -128
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.hide()
	_hint_layer.add_child(_hint)


func _unhandled_input(event: InputEvent) -> void:
	if not _waiting or not event.is_pressed() or event.is_echo():
		return
	var click: bool = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT
	if click or event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		advance()


## One press reveals the text; the next advances to the other speaker.
func advance() -> void:
	if not _waiting:
		return
	if _talking.is_typing():
		_talking.skip_typing()
	else:
		advanced.emit()


func _exit_tree() -> void:
	if is_instance_valid(_player_bubble):
		_player_bubble.queue_free()
	if is_instance_valid(_player):
		_player.held = false
