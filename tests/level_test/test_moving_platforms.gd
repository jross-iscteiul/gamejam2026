extends Node
# Headless check: player rides each moving platform and steps off onto the target ledge.
# Run:  godot --headless --path . res://tests/level_test/test_moving_platforms.tscn
# [level, wait frames at far end, walk dir after arrival, expect: cell the player ends on must be above row / right of col]
var c := 0
var m: Node2D
var t := 0
const CASES := [
	{"level": 2, "arrive": 305, "walk": "move_left", "check": "y", "row": 26},   # elevator up, step onto left ledge (row 26)
	{"level": 3, "arrive": 335, "walk": "move_right", "check": "x", "col": 67},  # shuttle across, step onto far deck (col 67+)
	{"level": 1, "arrive": 215, "walk": "", "check": "x", "col": 115},         # upper shuttle carries player
]
func _start() -> void: _load()
func _load() -> void:
	t = 0; get_tree().change_scene_to_file("res://levels/level_%02d/level_%02d.tscn" % [CASES[c].level, CASES[c].level])
func _step(_d: float) -> bool:
	var s := get_tree().current_scene
	if s == null: return false
	t += 1
	var p: CharacterBody2D = s.get_node("Player")
	if t == 1: # ride the platform closest to the player's spawn
		m = null
		for n in s.get_children():
			if n is AnimatableBody2D and (m == null or n.position.distance_to(p.position) < m.position.distance_to(p.position)):
				m = n
	var k: Dictionary = CASES[c]
	if t == 2: p.global_position = m.global_position + Vector2(0, -36)
	if t == k.arrive and k.walk: Input.action_press(k.walk)
	if t == k.arrive + 30 and k.walk: Input.action_release(k.walk)
	if t == k.arrive + 60:
		var cell := Vector2i(p.global_position / 32)
		var ok: bool = p.is_on_floor() and (cell.y < k.row if k.check == "y" else cell.x >= k.col)
		print("PASS " if ok else "FAIL ", "level ", k.level, " platform ride -> player cell ", cell)
		c += 1
		if c == CASES.size(): return true
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
