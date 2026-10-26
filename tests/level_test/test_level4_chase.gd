extends Node
# Headless level 4 corridor runs: the rolling ball and the two lava geysers.
# A bot holds right, waits at each geyser pit until it is idle with time to spare, then jumps it.
# With several random seeds it must always reach the boss trigger alive (the gate shuts behind it)
# before the ball arrives, and the ball must stop at the gate. Standing still must get crushed.
# Run:  godot --headless --path . res://tests/level_test/test_level4_chase.tscn

const SEEDS := [1, 2, 3, 4, 5]
const LIMIT := 900 # frames per run (15 s)

var run := 0 # 0..SEEDS.size()-1 = bot runs, then one idle run
var t := 0
var died := false
var failures := 0
var _running := false


func _ready() -> void:
	process_physics_priority = -10 # press inputs before the player (and JARVIS) read them
	_begin.call_deferred()


func _begin() -> void:
	get_tree().current_scene = null
	_running = true
	_load()


func _load() -> void:
	t = 0
	died = false
	for a in ["move_right", "jump"]:
		Input.action_release(a)
	seed(SEEDS[run] if run < SEEDS.size() else 99)
	get_tree().change_scene_to_file("res://levels/level_04/level_04.tscn")


func _physics_process(_delta: float) -> void:
	var s := get_tree().current_scene
	if not _running or s == null:
		return
	t += 1
	var p: CharacterBody2D = s.get_node("Player")
	if t == 1:
		p.get_node("Health").died.connect(func(_s: Node) -> void: died = true)
	var idle := run == SEEDS.size()
	if not idle and t > 1:
		_drive(s, p)
	var gate: Gate = s.get_node("Gate")
	var boulder: Node2D = s.get_node("Boulder")
	if idle and (died or t == LIMIT):
		_check(died, "standing still: the ball crushes the player (frame %d)" % t)
		print("%d failures" % failures)
		get_tree().quit(failures)
	elif not idle and (died or t == LIMIT):
		var at_gate: bool = is_equal_approx(boulder.position.x + boulder.RADIUS, gate.position.x - 16.0)
		_check(not died and gate.closed and at_gate,
			"seed %d: reached the boss trigger alive, ball stopped at the gate (died=%s, gate closed=%s, ball x=%.0f)"
			% [SEEDS[run], died, gate.closed, boulder.position.x])
		run += 1
		_load()


## Hold right; before each geyser pit wait until it is idle with time to spare, then jump it.
func _drive(s: Node, p: CharacterBody2D) -> void:
	var x := p.global_position.x
	for g in s.get_children():
		if not g.has_method("_enter"): # geysers only
			continue
		var pit: float = g.position.x
		if x > pit - 60.0 and x < pit:
			var safe: bool = g.state == "idle" and g.time_left > 0.8
			if not safe:
				Input.action_release("move_right")
				return
			if p.is_on_floor():
				Input.action_press("jump")
	if Input.is_action_pressed("jump") and not p.is_on_floor():
		Input.action_release("jump")
	Input.action_press("move_right")


func _check(ok: bool, msg: String) -> void:
	failures += int(not ok)
	print(("PASS " if ok else "FAIL ") + msg)
