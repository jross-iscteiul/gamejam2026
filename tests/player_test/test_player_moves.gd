extends Node
# Headless check of player moves in level 1's open start area.
# Run:  godot --headless --path . res://tests/player_test/test_player_moves.tscn

var t := 0
var step := 0
var start: Vector2
var peak := 0.0
var results := {}
var p: CharacterBody2D

# Each step: [name, frames to run, inputs: {frame: [action, press?]}]
const STEPS := [
	["single jump", 70, {1: ["jump", true], 3: ["jump", false]}],
	["double jump", 90, {1: ["jump", true], 3: ["jump", false], 20: ["jump", true], 22: ["jump", false]}],
	["triple press", 90, {1: ["jump", true], 3: ["jump", false], 20: ["jump", true], 22: ["jump", false], 35: ["jump", true], 37: ["jump", false]}],
	["ground dash", 30, {1: ["dash", true], 3: ["dash", false]}],
	["two air dashes", 80, {1: ["jump", true], 3: ["jump", false], 15: ["dash", true], 17: ["dash", false], 40: ["dash", true], 42: ["dash", false]}],
]


func _start() -> void:
	get_tree().change_scene_to_file("res://levels/level_01/level_01.tscn")


func _step(_d: float) -> bool:
	if get_tree().current_scene == null:
		return false
	if p == null:
		p = get_tree().current_scene.get_node("Player")
		start = p.global_position
	t += 1
	if t == 1: # reset onto the floor, facing right
		# Dash is bought from JARVIS: pay for the dash steps, keep 0 tokens elsewhere so a
		# third jump press can't buy a boost jump.
		GameState.tokens = 10 if "dash" in STEPS[step][0] else 0
		p.global_position = start
		p.velocity = Vector2.ZERO
		p.facing = 1
		peak = start.y
	var step_def: Array = STEPS[step]
	var inputs: Dictionary = step_def[2]
	if inputs.has(t - 10):
		var a: Array = inputs[t - 10]
		if a[1]: Input.action_press(a[0])
		else: Input.action_release(a[0])
	peak = minf(peak, p.global_position.y)
	if t == 10 + step_def[1]:
		results[step_def[0]] = {"rise": start.y - peak, "dx": p.global_position.x - start.x}
		print(step_def[0], ": rise=", int(start.y - peak), "px dx=", int(p.global_position.x - start.x), "px")
		step += 1
		t = 0
		if step == STEPS.size():
			_report()
			return true
	return false


func _report() -> void:
	var single: float = results["single jump"].rise
	var double: float = results["double jump"].rise
	_check(double > single * 1.5, "double jump goes higher than single")
	_check(absf(results["triple press"].rise - double) < 2.0, "third jump press ignored (only one air jump)")
	_check(results["ground dash"].dx > 50.0, "ground dash moves ~2 tiles")
	var one_air_dash: float = 420.0 * 0.15
	_check(results["two air dashes"].dx < one_air_dash * 1.5, "only one dash per airtime")


func _check(ok: bool, msg: String) -> void:
	print(("PASS " if ok else "FAIL ") + msg)


# Runner plumbing: this test is a scene (so autoloads like GameState exist). It detaches from
# current_scene so get_tree().change_scene_to_file() swaps levels without freeing the runner.
var _running := false


func _ready() -> void:
	process_physics_priority = -10 # press inputs before JARVIS (priority -1) reads them
	_begin.call_deferred()


func _begin() -> void:
	get_tree().current_scene = null
	_running = true
	_start()


func _physics_process(delta: float) -> void:
	if _running and _step(delta):
		get_tree().quit()
