extends Node
# Headless smoke test: intro -> L1 door -> L2 door -> L3 lever+gate+trap door -> L4 boss trigger.
# Run:  godot --headless --path . res://tests/level_test/test_levels_flow.tscn
var step := 0
var wait := 0
var _poll := 0 # generic retry counter for steps that wait on a real-time animation

func _press(action: String) -> void:
	var ev := InputEventAction.new(); ev.action = action; ev.pressed = true
	Input.parse_input_event(ev)
	var up := InputEventAction.new(); up.action = action; up.pressed = false
	Input.call_deferred("parse_input_event", up)

func _key() -> void:
	var k := InputEventKey.new(); k.keycode = KEY_X; k.pressed = true
	get_viewport().push_input(k)

func _goto(node_name: String) -> void:
	var p: Node2D = get_tree().current_scene.get_node("Player")
	p.global_position = get_tree().current_scene.get_node(node_name).global_position

func _check(cond: bool, msg: String) -> void:
	print(("PASS " if cond else "FAIL ") + msg)
	if not cond: get_tree().quit(1)

func _start() -> void:
	get_tree().change_scene_to_file("res://levels/intro/intro.tscn")

func _step(_d: float) -> bool:
	wait += 1
	if wait < 10: return false
	wait = 0
	var s := get_tree().current_scene
	match step:
		0: _check(s.name == "Intro", "intro loads"); _check(GameState.infinite_energy and not GameState.god_mode, "intro has infinite energy, no god mode"); _press("pause")
		1: _check(s.scene_file_path.ends_with("level_01.tscn"), "Esc skips intro -> level 1"); _check(not GameState.infinite_energy, "infinite energy ends with the intro"); _goto("Door")
		2: _press("interact")
		3: _check(s.scene_file_path.ends_with("level_02.tscn"), "L1 door -> level 2"); _goto("Door")
		4: _press("interact")
		5: _check(s.scene_file_path.ends_with("level_03.tscn"), "L2 door -> level 3"); _check(s.get_node("Gate").closed, "L3 gate starts closed"); _check(not s.get_node("Checkpoint").active, "checkpoint starts inactive"); _goto("Checkpoint")
		6: _check(s.get_node("Checkpoint").active, "touching a checkpoint activates it"); _goto("Lever")
		7: _check(not s.get_node("Lever").on, "lever starts off"); _press("interact")
		8: _check(not s.get_node("Gate").closed and s.get_node("Lever").on, "lever switches on and opens gate"); _goto("Door")
		9: _press("interact") # L3's door is a trap: it won't open, it springs instead
		10: _check(s.get_node("Door").get_node("Sign").text == "AHAH", "trap door sign mocks the player")
		11: # poll: the door digs the floor out and stuns the player, who then falls through it
			var door_y: float = s.get_node("Door").global_position.y
			var p: Node2D = s.get_node("Player")
			if p.global_position.y > door_y + 32.0:
				_check(true, "player falls through the trap door's floor")
				_poll = 0 # reset the counter for the next poll (step 12)
			else:
				_poll += 1
				if _poll >= 100: _check(false, "player falls through the trap door's floor (timed out)")
				step -= 1 # stay on this step and keep polling
		12: # poll: fade out, then the scene swaps to level 4 like a normal exit would
			if s.scene_file_path.ends_with("level_04.tscn"):
				_check(true, "trap door -> level 4")
				_check(not s.get_node("Gate").closed, "L4 gate starts open")
				_goto("BossTrigger")
			else:
				_poll += 1
				if _poll >= 150: _check(false, "trap door -> level 4 (timed out)")
				step -= 1
		13:
			_check(s.get_node("Gate").closed, "boss trigger closes gate")
			_check(s.get_node("Player/Camera2D").limit_left == 832, "camera locked to arena")
			return true
	step += 1
	return false


# Runner plumbing: this test is a scene (so autoloads like GameState exist). It detaches from
# current_scene so get_tree().change_scene_to_file() swaps levels without freeing the runner.
var _running := false


func _ready() -> void:
	_begin.call_deferred()


func _begin() -> void:
	get_tree().current_scene = null
	_running = true
	_start()


func _process(delta: float) -> void:
	if _running and _step(delta):
		get_tree().quit()
