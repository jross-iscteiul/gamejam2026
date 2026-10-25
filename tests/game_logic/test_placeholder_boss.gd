extends Node
## Real levels/projectiles and victory UI, with an offline leaderboard transport.

var _failures: int = 0
var _victories: int = 0
var _calls: Array[Dictionary] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		_failures += 1


func _frames(count: int = 8) -> void:
	for i in count:
		await get_tree().physics_frame
	await get_tree().process_frame


func _fake(path: String, _method: HTTPClient.Method, body: Dictionary, authenticated: bool) -> Dictionary:
	_calls.append({"path": path, "body": body.duplicate(true), "authenticated": authenticated})
	if path == "/v1/runs":
		return {"ok": true, "data": {"run_token": "b".repeat(64)}}
	if path.begins_with("/v1/leaderboard"):
		return {"ok": true, "data": {"items": []}}
	return {"ok": true, "data": {"accepted": true}}


func _load_level(number: int) -> Node:
	get_tree().change_scene_to_file("res://levels/level_%02d/level_%02d.tscn" % [number, number])
	await _frames()
	return get_tree().current_scene


func _shoot(boss: Node2D, player: Node2D) -> void:
	var bullet := preload("res://characters/player/bullet.tscn").instantiate() as PlayerBullet
	bullet.source = player
	get_tree().current_scene.add_child(bullet)
	bullet.global_position = boss.global_position + Vector2(-48, -16)
	await _frames(12)


func _enter_arena(scene: Node) -> void:
	scene.get_node("Player").global_position = scene.get_node("BossTrigger").global_position
	await _frames(32) # Let the existing gate/banner animation finish.


func _capture(name: String) -> void:
	if "--visual" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://.godot/" + name + ".png")


func _run() -> void:
	get_tree().current_scene = null
	var client := GameState.leaderboard
	var previous_enabled := client.enabled
	client.enabled = true
	client.transport = _fake
	var record_path := GameState.run_clock._record_path
	var best := GameState.run_clock.best_msec
	GameState.run_clock._record_path = "user://test_square_boss_%d.cfg" % OS.get_process_id()
	GameState.run_clock.best_msec = 0
	GameState.boss_defeated.connect(func() -> void: _victories += 1)

	# Chapter Select must allow testing the target without qualifying a score.
	GameState.reset_run()
	var scene := await _load_level(4)
	var boss := scene.get_node("Entities/SquareBoss")
	var health := boss.get_node("Health") as Health
	var player := scene.get_node("Player") as Player
	_check(boss.global_position == scene.get_node("BossSpawn").global_position, "square uses the existing level 4 boss spawn")
	await _shoot(boss, player)
	_check(health.current == 5 and _victories == 0, "shots before arena entry cannot defeat the boss")
	await _enter_arena(scene)
	var hud := get_tree().get_first_node_in_group("game_hud")
	_check(boss._active and hud._boss_box.visible and hud._boss.value == 5, "arena entry activates the square and shows its health")
	await _capture("square_boss_arena")
	await _shoot(boss, player)
	_check(health.current == 4 and hud._boss.value == 4, "real player projectiles update boss health and HUD")
	for i in 4:
		await _shoot(boss, player)
	_check(_victories == 1 and not is_instance_valid(boss), "five shots defeat and remove the square exactly once")
	_check(not GameState.run_clock.eligible and client.pending_result.is_empty() and not get_tree().paused, "chapter victory stays practice and offers no leaderboard submission")
	_check(not hud._boss_box.visible and not scene.get_node("BossTrigger/Banner").visible, "victory clears the boss bar and arena banner")

	# Visit the real doors in order, retaining the clock and authenticated checkpoints.
	GameState.reset_run()
	GameState.prepare_full_run()
	scene = await _load_level(1)
	for number in range(1, 4):
		player = scene.get_node("Player")
		player.set_shield(true)
		player.global_position = scene.get_node("Door").global_position
		await _frames()
		Input.action_press("interact")
		await _frames(2)
		Input.action_release("interact")
		await _frames()
		scene = get_tree().current_scene
		_check(GameState.current_level == number + 1, "real level %d door preserves the full run" % number)
	player = scene.get_node("Player")
	await _enter_arena(scene)
	boss = scene.get_node("Entities/SquareBoss")
	for i in 5:
		await _shoot(boss, player)
	_check(_victories == 2 and GameState.run_clock.state == RunClock.State.FINISHED, "full-run boss victory stops the clock once")
	_check(LeaderboardClient.valid_result(client.pending_result) and client.pending_result.splits_ms.size() == 4, "square victory offers a qualifying result with four splits")
	hud = get_tree().get_first_node_in_group("game_hud")
	_check(get_tree().paused and hud._leaderboard_page.visible, "full-run victory opens the leaderboard submission screen")
	await _capture("square_boss_result")
	var checkpoint_calls := _calls.filter(func(call: Dictionary) -> bool: return call.path == "/v1/checkpoints")
	_check(checkpoint_calls.size() == 3 and checkpoint_calls[0].body.level == 1 and checkpoint_calls[2].body.level == 3, "full run sends ordered server checkpoints")
	await client.submit("SquareTester")
	var submissions := _calls.filter(func(call: Dictionary) -> bool: return call.path == "/v1/scores")
	_check(submissions.size() == 1 and submissions[0].authenticated and client.pending_result.is_empty(), "finished square-boss run submits through the leaderboard client (offline transport)")

	get_tree().paused = false
	GameState.reset_run()
	DirAccess.remove_absolute(GameState.run_clock._record_path)
	GameState.run_clock._record_path = record_path
	GameState.run_clock.best_msec = best
	client.transport = Callable()
	client.enabled = previous_enabled
	get_tree().current_scene.queue_free()
	await _frames()
	print("PLACEHOLDER BOSS: %d failure(s)" % _failures)
	get_tree().quit(1 if _failures else 0)
