extends Node
# Headless check for the JARVIS skeleton: spawns in levels, follows the player, reacts to trust.
# Run:  godot --headless --path . res://tests/jarvis/test_jarvis.tscn
var _t := 0
var _failed := false
var _bob_min := INF
var _bob_max := -INF


func _ready() -> void:
	_begin.call_deferred()


func _begin() -> void:
	GameState.reset_run()
	get_tree().current_scene = null
	get_tree().change_scene_to_file("res://levels/level_01/level_01.tscn")


func _physics_process(_delta: float) -> void:
	var s := get_tree().current_scene
	if s == null:
		return
	_t += 1
	var jarvis := get_tree().get_first_node_in_group("jarvis") as Node2D
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if _t == 2:
		_check(jarvis != null, "JARVIS spawns in level 1")
		if jarvis == null:
			return _finish()
		_check(jarvis.global_position.distance_to(player.global_position) < 60.0, "JARVIS starts next to the player")
		jarvis.global_position += Vector2(150, 0)
	if _t == 30:
		_bob_min = INF
		_bob_max = -INF
	if _t > 30 and _t < 90:
		var y: float = jarvis.get_node("Body").position.y
		_bob_min = minf(_bob_min, y)
		_bob_max = maxf(_bob_max, y)
	if _t == 20:
		_check(absf(jarvis.get_node("Body").rotation) > 0.01, "JARVIS tilts while catching up")
	if _t == 90:
		_check(_bob_max - _bob_min > 2.0, "JARVIS bobs up and down")
		_check(jarvis.get_node("Body").scale.x == player.get("facing"), "JARVIS faces the same way as the player")
		player.set("facing", -player.get("facing"))
	if _t == 91:
		_check(jarvis.get_node("Body").scale.x == player.get("facing"), "JARVIS flips with the player")
		player.set("facing", -player.get("facing"))
		_check(jarvis.global_position.distance_to(player.global_position) < 60.0, "JARVIS catches up with the player")
		player.global_position += Vector2(1000, 0)
	if _t == 92:
		_check(jarvis.global_position.distance_to(player.global_position) < 60.0, "JARVIS snaps to a far-away player")
		GameState.trust = 0.0
		_check(jarvis.get_node("Body").modulate != Color.WHITE, "JARVIS greys out at zero trust")
		GameState.trust = 50.0
		_check(jarvis.get_node("Body").modulate == Color.WHITE, "JARVIS recovers when trust returns")
		_finish()


func _check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ", label)
	_failed = _failed or not ok


func _finish() -> void:
	set_physics_process(false)
	get_tree().quit(1 if _failed else 0)
