extends Node
# Headless "is it fair?" runs through new hazard sections. Each scenario is tried with several start
# delays (or with/without the right move): at least one try must pass cleanly and at least one must
# get hurt, i.e. the hazard is passable with timing but punishes bad timing.
# Entities (robots that shoot) are removed so only hazards can hurt the player.
# Run:  godot --headless --path . res://tests/hazard_test/test_hazard_runs.tscn

const T := 32
# name, level, start cell, jump-at x (cell, -1 none), double jump frame (-1 none), stop at x cell,
# goal (cell x >= gx and cell y <= gy), start delays in frames, expect: "clean" (some try passes
# cleanly), "hurt" (some try gets hurt) or "both"
const SCENARIOS := [
	["L1 lava trench / jump", 1, Vector2i(105, 14), 106, -1, 114, Vector2i(111, 14), [0], "clean"],
	["L1 lava trench / walk in", 1, Vector2i(105, 14), -1, -1, 114, Vector2i(111, 14), [0], "hurt"],
	["L1 blade / jump over", 1, Vector2i(14, 14), 16, -1, 23, Vector2i(22, 17), [0, 30, 60, 90, 120, 150, 180, 210, 240, 270, 300, 330], "clean"],
	["L1 blade / walk through", 1, Vector2i(14, 14), -1, -1, 23, Vector2i(22, 17), [0, 60, 120, 180, 240, 300], "hurt"],
	["L2 climb laser (row 38)", 2, Vector2i(9, 40), 12, 24, 18, Vector2i(16, 35), [0, 12, 24, 36, 48, 60, 72, 84, 96, 108, 120, 132, 144], "both"],
	["L3 deck A hammer", 3, Vector2i(41, 8), -1, -1, 50, Vector2i(49, 8), [0, 9, 18, 27, 36, 45, 54, 63, 72, 81, 90], "both"],
	["L3 deck B hammer", 3, Vector2i(68, 8), -1, -1, 79, Vector2i(78, 8), [0, 9, 18, 27, 36, 45, 54, 63, 72, 81, 90], "both"],
]

var s_i := 0
var d_i := 0
var t := 0
var jumped := -1
var hurt := false
var outcomes := {} # scenario name -> [clean passes, hurt tries]
var failures := 0
var _running := false


func _ready() -> void:
	process_physics_priority = -10 # press inputs before JARVIS (priority -1) reads them
	_begin.call_deferred()


func _begin() -> void:
	get_tree().current_scene = null
	_running = true
	_load()


func _load() -> void:
	t = 0
	jumped = -1
	hurt = false
	for a in ["move_right", "jump"]:
		Input.action_release(a)
	var n: int = SCENARIOS[s_i][1]
	get_tree().change_scene_to_file("res://levels/level_%02d/level_%02d.tscn" % [n, n])


func _physics_process(_delta: float) -> void:
	var s := get_tree().current_scene
	if not _running or s == null:
		return
	t += 1
	var k: Array = SCENARIOS[s_i]
	var p: CharacterBody2D = s.get_node("Player")
	var delay: int = k[7][d_i]
	if t == 2:
		GameState.energy = GameState.MAX_ENERGY # the double jump is paid with JARVIS's energy
		s.get_node("Entities").queue_free()
		p.global_position = Vector2(k[2] * T) + Vector2(16, 16)
		p.velocity = Vector2.ZERO
		p.get_node("Health").damaged.connect(func(_a: float, _s: Node) -> void: hurt = true)
	if t == 10 + delay:
		Input.action_press("move_right")
	if k[3] >= 0 and jumped < 0 and t > 10 + delay and p.global_position.x >= k[3] * T + 16:
		jumped = t
		Input.action_press("jump")
	if jumped > 0 and t == jumped + 2:
		Input.action_release("jump")
	if jumped > 0 and k[4] >= 0 and t == jumped + k[4]:
		Input.action_press("jump")
	if jumped > 0 and k[4] >= 0 and t == jumped + k[4] + 2:
		Input.action_release("jump")
	if p.global_position.x >= k[5] * T:
		Input.action_release("move_right")
	if t == 10 + delay + 240:
		var cell := Vector2i(floori(p.global_position.x / T), floori(p.global_position.y / T))
		var goal: Vector2i = k[6]
		var clean: bool = not hurt and cell.x >= goal.x and cell.y <= goal.y
		var o: Array = outcomes.get(k[0], [0, 0])
		o[0] += int(clean)
		o[1] += int(hurt)
		outcomes[k[0]] = o
		d_i += 1
		if d_i == k[7].size():
			_report(k[0], k[8])
			d_i = 0
			s_i += 1
			if s_i == SCENARIOS.size():
				print("%d failures" % failures)
				get_tree().quit(failures)
				return
		_load()


func _report(name: String, expect: String) -> void:
	var o: Array = outcomes[name]
	var ok: bool = (o[0] >= 1 or expect == "hurt") and (o[1] >= 1 or expect == "clean")
	failures += int(not ok)
	print(("PASS " if ok else "FAIL ") + "%s: %d clean, %d hurt" % [name, o[0], o[1]])
