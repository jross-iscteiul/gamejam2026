extends Node
# Headless check for JARVIS: spawn, follow, bob, trust tint and spray shooting.
# Run:  godot --headless --path . res://tests/jarvis/test_jarvis.tscn
var _t := 0
var _failed := false
var _bob_min := INF
var _bob_max := -INF
var _home := Vector2.ZERO


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
		_home = player.global_position
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
		player.global_position = _home
	if _t == 100:
		GameState.trust = GameState.MAX_TRUST
		_check(is_equal_approx(jarvis.fire_rate(), jarvis.max_fire_rate), "full trust fires at max rate")
		GameState.trust = GameState.MAX_TRUST * 0.5
		_check(is_equal_approx(jarvis.fire_rate(), (jarvis.min_fire_rate + jarvis.max_fire_rate) * 0.5), "half trust fires at half way rate")
		GameState.tokens = 1000
		_check(is_equal_approx(jarvis.fire_rate(), (jarvis.min_fire_rate + jarvis.max_fire_rate) * 0.5), "tokens do not change fire rate")
		_check_spray(jarvis)
		GameState.trust = 0.0
		_clear_bullets()
	if _t == 160:
		_check(get_tree().get_nodes_in_group("player_projectile").is_empty(), "disabled JARVIS fires no bullets")
		GameState.trust = 100.0
	if _t == 190:
		var bullets := get_tree().get_nodes_in_group("player_projectile")
		_check(not bullets.is_empty(), "JARVIS keeps shooting with no enemies around")
		_check(bullets.all(func(b: Node) -> bool: return b.source == jarvis), "JARVIS bullets credit JARVIS for kills")
		_finish()


func _clear_bullets() -> void:
	for bullet in get_tree().get_nodes_in_group("player_projectile"):
		bullet.free()


func _check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ", label)
	_failed = _failed or not ok


## Samples the spray: each slice gets its weight share, nothing lands outside the slices,
## and facing left mirrors it. Reads spray_sectors so tuning the values never breaks the test.
func _check_spray(jarvis: Node2D) -> void:
	var samples := 6000
	var sectors: Array[Vector4] = jarvis.spray_sectors
	var total := 0.0
	for sector in sectors:
		total += sector.z
	for side in [1, -1]:
		jarvis.facing = side
		var counts: Array[int] = []
		counts.resize(sectors.size())
		counts.fill(0)
		var outside := 0
		for i in samples:
			var d: Vector2 = jarvis.spray_direction()
			var deg := rad_to_deg(Vector2(d.x * side, d.y).angle())
			var hit := false
			for k in sectors.size():
				if deg >= sectors[k].x - 0.5 and deg <= sectors[k].y + 0.5:
					counts[k] += 1
					hit = true
					break
			if not hit:
				outside += 1
		var ok := outside == 0
		var shares: Array[String] = []
		for k in sectors.size():
			var share := counts[k] / float(samples)
			ok = ok and absf(share - sectors[k].z / total) < 0.03
			shares.append("%.0f%%" % (share * 100.0))
		_check(ok, "spray facing %d matches slice weights: %s, outside %d / %d" % [side, ", ".join(shares), outside, samples])
	jarvis.facing = 1


func _finish() -> void:
	set_physics_process(false)
	get_tree().quit(1 if _failed else 0)
