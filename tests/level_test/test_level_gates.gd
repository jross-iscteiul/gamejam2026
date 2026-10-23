extends Node
# Headless check that every movement gate needs its move: the attempt without the move must fail,
# the attempt with it must succeed. Timings are the best ones found by sweeping (frames after takeoff).
# Run:  godot --headless --path . res://tests/level_test/test_level_gates.tscn

const T := 32
# level, start (cell x, cell y, x offset px), second-jump frame (-1 none), dash frame (-1 none),
# goal: player ends on the floor at cell x >= gx and cell y <= gy; expect success?
const CASES := [
	["L1 wall5 / single", 1, Vector2i(23, 17), 0, -1, -1, Vector2i(25, 12), false],
	["L1 wall5 / double", 1, Vector2i(23, 17), 0, 30, -1, Vector2i(25, 12), true],
	["L1 pit7 / single", 1, Vector2i(40, 12), 20, -1, -1, Vector2i(48, 12), false],
	["L1 pit7 / double", 1, Vector2i(40, 12), 20, 35, -1, Vector2i(48, 12), true],
	["L1 pit7 / jump+dash", 1, Vector2i(40, 12), 20, -1, 50, Vector2i(48, 12), true],
	["L1 tunnel pit4 / double", 1, Vector2i(74, 15), 20, 20, -1, Vector2i(79, 15), false],
	["L1 tunnel pit4 / jump+dash", 1, Vector2i(74, 15), 20, -1, 20, Vector2i(79, 15), true],
	["L2 climb / single", 2, Vector2i(14, 50), 0, -1, -1, Vector2i(16, 45), false],
	["L2 climb / double", 2, Vector2i(14, 50), 0, 30, -1, Vector2i(16, 45), true],
	["L2 walkway pit7 / single", 2, Vector2i(36, 8), 20, -1, -1, Vector2i(44, 8), false],
	["L2 walkway pit7 / double", 2, Vector2i(36, 8), 20, 35, -1, Vector2i(44, 8), true],
	["L3 stairs / single", 3, Vector2i(20, 20), 0, -1, -1, Vector2i(22, 15), false],
	["L3 stairs / double", 3, Vector2i(20, 20), 0, 30, -1, Vector2i(22, 15), true],
	["L3 pit10 / double", 3, Vector2i(83, 20), 20, 35, -1, Vector2i(94, 20), false],
	["L3 pit10 / jump+dash", 3, Vector2i(83, 20), 20, -1, 50, Vector2i(94, 20), false],
	["L3 pit10 / double+dash", 3, Vector2i(83, 20), 20, 35, 70, Vector2i(94, 20), true],
]

var c := 0
var t := 0
var failures := 0


func _start() -> void:
	_load()


func _load() -> void:
	t = 0
	for a in ["move_right", "jump", "dash"]:
		Input.action_release(a)
	get_tree().change_scene_to_file("res://levels/level_%02d/level_%02d.tscn" % [CASES[c][1], CASES[c][1]])


func _press(action: String, frame: int) -> void:
	if t == 10 + frame: Input.action_press(action)
	if t == 12 + frame: Input.action_release(action)


func _step(_d: float) -> bool:
	var s := get_tree().current_scene
	if s == null:
		return false
	t += 1
	var k: Array = CASES[c]
	var p: CharacterBody2D = s.get_node("Player")
	if t == 3:
		p.global_position = Vector2(k[2] * T) + Vector2(k[3], 16)
		p.velocity = Vector2.ZERO
	if t == 10:
		Input.action_press("move_right")
	if t > 20 and p.is_on_floor(): # landed: stop so we don't walk off the target
		Input.action_release("move_right")
	_press("jump", 0)
	if k[4] >= 0: _press("jump", k[4])
	if k[5] >= 0: _press("dash", k[5])
	if t == 200:
		var cell := Vector2i(p.global_position / T)
		var goal: Vector2i = k[6]
		var reached: bool = p.is_on_floor() and cell.x >= goal.x and cell.y <= goal.y
		var ok: bool = reached == k[7]
		failures += int(not ok)
		print("PASS " if ok else "FAIL ", k[0], " -> ", "made it" if reached else "fell short", " (cell ", cell, ")")
		c += 1
		if c == CASES.size():
			print("%d/%d gate checks passed" % [CASES.size() - failures, CASES.size()])
			return true
		_load()
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


func _physics_process(delta: float) -> void:
	if _running and _step(delta):
		get_tree().quit()
