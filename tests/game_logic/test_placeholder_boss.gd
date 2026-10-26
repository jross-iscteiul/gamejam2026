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


## Fires a real player projectile into the boss from just outside its hurtbox. The boss paces,
## so the shot is aimed at the chest rather than dropped at a fixed offset.
func _shoot(boss: Node2D, player: Node2D) -> void:
	var chest := boss.global_position + Vector2(0, -40) # above the arena minions' heads
	var bullet := preload("res://characters/player/bullet.tscn").instantiate() as PlayerBullet
	bullet.source = player
	bullet.direction = Vector2.RIGHT
	get_tree().current_scene.add_child(bullet)
	bullet.global_position = chest + Vector2(-36, 0)
	await _frames(12)


## The arena hatches must keep feeding the fight: one cycle has to produce a new minion.
func _check_minion_doors(doors: Array) -> void:
	var before := get_tree().get_nodes_in_group("enemy").size()
	for door in doors:
		door.interval = 0.2
		door._left = 0.05
	await _frames(60)
	_check(get_tree().get_nodes_in_group("enemy").size() > before, "the minion doors release reinforcements on their interval")
	for door in doors:
		var alive: Array = door._spawned.filter(func(node: Variant) -> bool: return is_instance_valid(node))
		_check(alive.size() <= door.max_alive, "a door never keeps more than max_alive minions out")
	# A door must survive its minions dying: the freed entries have to be pruned on the next cycle.
	for door in doors:
		for minion in door._spawned:
			minion.free()
	await _frames(60)
	for door in doors:
		_check(door._spawned.all(func(node: Variant) -> bool: return is_instance_valid(node)),
			"a door prunes freed minions instead of choking on them")


## Dying in the sealed arena must put the player back inside it, not behind the gate where the
## locked camera cannot follow, and a downed minion must be safe to walk over.
func _check_arena_death(scene: Node, player: Player) -> void:
	var arena: Rect2 = scene.get_node("BossTrigger").arena
	_check(arena.has_point(player.respawn_point), "the arena moves the respawn point inside the locked camera")
	player.get_node("Health").kill(null)
	await _frames(90) # the death fall chains straight into respawn()
	_check(not player._is_dead and player.get_node("Health").current > 0.0, "the player revives after dying in the arena")
	_check(arena.has_point(player.global_position), "the revived player is back inside the arena")
	var minions := get_tree().get_nodes_in_group("enemy").filter(func(node: Variant) -> bool:
		return node.has_method("shut_down") and not node.is_in_group("boss") and not node.is_in_group("jarvis"))
	if not minions.is_empty():
		var corpse: Node = minions[0]
		corpse.shut_down()
		await _frames(2)
		var contact: Hitbox = corpse.get_node("Contact")
		_check(not contact.monitoring and not contact.monitorable, "a downed unit cannot damage the player any more")



## Last phase: the boss hands the fight to JARVIS, who switches sides. Skips the speech
## timings so the betrayal animation does not stall the suite, then shoots him down.
func _defeat_through_jarvis(player: Node2D) -> Jarvis:
	var jarvis := get_tree().get_first_node_in_group("jarvis") as Jarvis
	jarvis.bubble.chars_per_second = 2000.0
	jarvis.bubble.hold_seconds = 0.0
	jarvis.bubble.hold_per_char = 0.0
	await GameState.jarvis_betrayed
	await _frames()
	_check(jarvis.hostile and jarvis.is_in_group("enemy"), "JARVIS switches sides and becomes an enemy")
	var hurtbox := jarvis.get_node("BossHurtbox") as Hurtbox
	_check(hurtbox.collision_layer == 4 and hurtbox.collision_mask == 8, "the turncoat can be hit by player projectiles")
	_check(jarvis.mech != null and jarvis.assembled_units.size() == 3 and jarvis.assembled_units.all(
		func(unit: Variant) -> bool: return is_instance_valid(unit) and unit.get_parent() == jarvis.mech),
		"three units build the chassis and slot into it")
	_check(jarvis.seat_offset.y < 0.0 and absf(jarvis.body.position.y - jarvis.seat_offset.y) <= 6.0,
		"JARVIS rides in the chassis' cockpit cradle")
	_check(hurtbox.damage_multiplier < 1.0, "the giant is armoured against player shots")
	await _frames(70) # let him land
	var walker := get_tree().current_scene.get_node_or_null("JarvisMechWalker") as CharacterBody2D
	var landed := false
	for i in 120: # he hops at random, so wait for a landing rather than sampling one frame
		if walker != null and walker.is_on_floor():
			landed = true
			break
		await get_tree().physics_frame
	_check(landed, "the mech stands on the ground like the player")
	_check(absf(jarvis.mech.scale.y) <= 0.8, "the mech is small enough for the floating islands")
	var health := jarvis.get_node("BossHealth") as Health
	var others := get_tree().get_nodes_in_group("enemy").filter(
		func(node: Variant) -> bool: return node != jarvis and not jarvis.assembled_units.has(node))
	while health.current > 0.0:
		hurtbox.take_damage(health.max_health, player)
		await _frames()
	await GameState.boss_defeated
	await _frames()
	var still_fighting := others.filter(func(node: Variant) -> bool:
		return is_instance_valid(node) and "_dead" in node and not node._dead)
	_check(still_fighting.is_empty(), "every unit still standing goes offline with JARVIS")
	return jarvis


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
	GameState.run_clock._record_path = "user://test_boss_robot_%d.cfg" % OS.get_process_id()
	GameState.run_clock.best_msec = 0
	GameState.boss_defeated.connect(func() -> void: _victories += 1)

	# Chapter Select must allow testing the target without qualifying a score.
	GameState.reset_run()
	var scene := await _load_level(4)
	var boss := scene.get_node("Entities/BossRobot")
	var health := boss.get_node("Health") as Health
	var player := scene.get_node("Player") as Player
	_check(is_equal_approx(boss.global_position.x, scene.get_node("BossSpawn").global_position.x), "the boss robot uses the existing level 4 boss spawn")
	await _shoot(boss, player)
	_check(health.current == 10 and _victories == 0, "shots before arena entry cannot defeat the boss")
	await _enter_arena(scene)
	var hud := get_tree().get_first_node_in_group("game_hud")
	_check(boss._active and hud._boss_box.visible and hud._boss.value == 10, "arena entry activates the robot and shows its health")
	_check(hud._boss_compact and hud._boss_box.offset_top > 0.0, "the Foreman's bar is tucked into the top corner")
	var doors := get_tree().get_nodes_in_group("minion_door")
	_check(doors.size() == 1 and doors[0].active, "arena entry opens the minion door for business")
	await _capture("boss_robot_arena")
	await _shoot(boss, player)
	_check(health.current == 9 and hud._boss.value == 9, "real player projectiles update boss health and HUD")
	await _check_minion_doors(doors)
	await _check_arena_death(scene, player)
	for i in 5:
		await _shoot(boss, player)
	_check(boss._final_phase and _victories == 0, "the robot gives up at its last phase instead of dying")
	_check(not hud._boss_box.visible, "the Foreman's health bar is hidden during the handover")
	await _defeat_through_jarvis(player)
	_check(hud._boss_label.text == "JARVIS", "the turncoat takes over the boss health bar")
	_check(not hud._boss_compact, "JARVIS gets the full-size bar")
	_check(doors.all(func(door: Node) -> bool: return not door.active), "the minion door seals when the network goes dark")
	_check(_victories == 1 and not is_instance_valid(boss), "shooting the turncoat JARVIS down ends the fight exactly once")
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
	boss = scene.get_node("Entities/BossRobot")
	for i in 6:
		await _shoot(boss, player)
	await _defeat_through_jarvis(player)
	_check(_victories == 2 and GameState.run_clock.state == RunClock.State.FINISHED, "full-run boss victory stops the clock once")
	_check(LeaderboardClient.valid_result(client.pending_result) and client.pending_result.splits_ms.size() == 4, "boss victory offers a qualifying result with four splits")
	hud = get_tree().get_first_node_in_group("game_hud")
	_check(get_tree().paused and hud._leaderboard_page.visible, "full-run victory opens the leaderboard submission screen")
	await _capture("boss_robot_result")
	var checkpoint_calls := _calls.filter(func(call: Dictionary) -> bool: return call.path == "/v1/checkpoints")
	_check(checkpoint_calls.size() == 3 and checkpoint_calls[0].body.level == 1 and checkpoint_calls[2].body.level == 3, "full run sends ordered server checkpoints")
	await client.submit("SquareTester")
	var submissions := _calls.filter(func(call: Dictionary) -> bool: return call.path == "/v1/scores")
	_check(submissions.size() == 1 and submissions[0].authenticated and client.pending_result.is_empty(), "finished boss run submits through the leaderboard client (offline transport)")

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
