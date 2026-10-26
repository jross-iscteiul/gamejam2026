extends Node
## Run with --headless --path . res://tests/game_logic/test_package3.tscn
## Optional -- --visual captures the menu, real level HUD and pause menu under .godot/.

var _failures: int = 0
var _deaths: int = 0
var _kills: int = 0
var _last_killer: Node
var _visual: bool = false


func _ready() -> void:
	_visual = "--visual" in OS.get_cmdline_user_args()
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		_failures += 1


func _frames(count: int = 4) -> void:
	for i in count:
		await get_tree().physics_frame
	await get_tree().process_frame


func _load_level(level: int) -> Node:
	get_tree().change_scene_to_file("res://levels/level_%02d/level_%02d.tscn" % [level, level])
	await _frames()
	return get_tree().current_scene


func _capture(filename: String) -> void:
	if _visual and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://.godot/" + filename + ".png")


func _run() -> void:
	# Keep the runner alive while changing the actual current scene, as the level tests do.
	get_tree().current_scene = null
	GameState.reset_run()
	GameState.player_died.connect(func() -> void: _deaths += 1)
	GameState.enemy_killed.connect(func(_enemy: Node, killer: Node) -> void:
		_kills += 1
		_last_killer = killer
	)
	_test_economy()
	await _test_damage()
	await _test_menu()
	for level in range(1, 5):
		var scene := await _load_level(level)
		_check(GameState.current_level == level and GameState.gameplay_active, "level %d starts its economy" % level)
		_check(get_tree().get_nodes_in_group("game_hud").size() == 1, "level %d has exactly one HUD" % level)
		_check(get_tree().get_nodes_in_group("token").size() >= 20, "level %d has token placements" % level)
		_check(get_tree().get_nodes_in_group("enemy").size() >= 5, "level %d has robot placements" % level)
		_test_placements(scene)
	await _test_live_gameplay()
	GameState.gameplay_active = false
	get_tree().current_scene.queue_free()
	await _frames(6)
	print("PACKAGE 3: %d failure(s)" % _failures)
	get_tree().quit(1 if _failures else 0)


func _test_economy() -> void:
	GameState.add_tokens(5)
	_check(not GameState.spend_tokens(-2) and GameState.tokens == 5, "negative spending cannot mint tokens")
	_check(not GameState.spend_tokens(6) and GameState.tokens == 5, "failed spending is atomic")
	_check(GameState.spend_tokens(2) and GameState.tokens == 3, "spending subtracts exactly the cost")
	GameState.energy = 0
	_check(not GameState.jarvis_enabled and not GameState.use_ability(&"dash"), "zero energy disables paid abilities")
	_check(GameState.feed_jarvis() and GameState.jarvis_enabled and GameState.energy == 25, "feeding revives JARVIS at zero energy")
	_check(not GameState.feed_jarvis() and GameState.energy == 25, "feeding without tokens cannot restore energy")
	GameState.add_tokens(10)
	_check(GameState.use_ability(&"boost_jump") and GameState.tokens == 7, "ability cost table is enforced")
	_check(not GameState.use_ability(&"unknown") and GameState.tokens == 7, "unknown abilities cannot spend tokens")
	GameState.jarvis_hostile = true
	_check(not GameState.jarvis_enabled and not GameState.feed_jarvis(), "hostile JARVIS cannot be bribed back")
	GameState.jarvis_hostile = false
	GameState.energy = 100
	var balance := GameState.tokens
	_check(not GameState.feed_jarvis() and GameState.tokens == balance, "feeding at full energy never wastes tokens")
	_check(GameState.kill_doubt_chance(4) > GameState.kill_doubt_chance(1), "kill doubt grows across levels")
	GameState.energy = 0
	GameState.player_died.emit()
	_check(GameState.jarvis_enabled and GameState.energy == GameState.DEATH_ENERGY, "death brings JARVIS back at 75% energy")
	GameState.energy = 90
	GameState.player_died.emit()
	_check(GameState.energy == 90, "death never lowers JARVIS's energy")
	_deaths -= 2 # these two synthetic deaths must not count in the real death checks below
	GameState.begin_level(1)
	GameState.energy = 100
	GameState._process(10)
	_check(is_equal_approx(GameState.energy, 92.0), "level 1 energy decay uses active seconds")
	GameState.begin_level(4)
	GameState.energy = 100
	GameState._process(10)
	_check(is_equal_approx(GameState.energy, 80.0), "level 4 has stronger energy decay")
	GameState.reset_run()


func _test_damage() -> void:
	var health := Health.new()
	add_child(health)
	var hurt := Hurtbox.new()
	hurt.collision_layer = 2
	hurt.collision_mask = 80
	hurt.health = health
	add_child(hurt)
	var hit := Hitbox.new()
	hit.collision_layer = 8
	add_child(hit)
	hurt.receive_hit(hit)
	_check(health.current == 3, "player projectile layer cannot hurt player")
	hit.collision_layer = 16
	hurt.receive_hit(hit)
	_check(health.current == 2, "enemy hitbox damages player once")
	hurt.receive_hit(hit)
	_check(health.current == 2, "same contact is not applied by both monitors")
	health.take_damage(1)
	_check(health.current == 2, "damage invincibility blocks rapid repeat hits")
	health.restore()
	health.invulnerable = true
	health.take_damage(1)
	_check(health.current == 3, "shield blocks normal damage")
	health.kill(self)
	_check(health.current == 0, "instant kill bypasses shield immunity")
	health.restore()
	health.grant_invulnerability(0.04)
	health.take_damage(1)
	_check(health.current == 3, "dash immunity blocks damage")
	await _frames(6)
	health.take_damage(1)
	_check(health.current == 2, "timed immunity expires")
	health.restore()
	health.take_damage(-10)
	_check(health.current == 3, "negative damage cannot heal beyond max HP")
	hit.queue_free()
	hurt.queue_free()
	health.queue_free()


func _test_menu() -> void:
	get_tree().change_scene_to_file("res://ui/menus/main_menu.tscn")
	await _frames()
	_check(get_tree().current_scene.name == "MainMenu", "main menu loads")
	await _capture("package3_menu")
	get_tree().current_scene._start_chapter(1)
	await _frames()
	_check(GameState.current_level == 1, "chapter select starts an existing level")


func _test_placements(scene: Node) -> void:
	var tiles := scene.get_node("Tiles") as TileMapLayer
	var embedded := 0
	var unsupported := 0
	for pickup in get_tree().get_nodes_in_group("token"):
		var cell := tiles.local_to_map(tiles.to_local(pickup.global_position))
		if tiles.get_cell_source_id(cell) >= 0:
			embedded += 1
	for enemy in get_tree().get_nodes_in_group("enemy"):
		var cell := tiles.local_to_map(tiles.to_local(enemy.global_position))
		if tiles.get_cell_source_id(cell) >= 0:
			embedded += 1
		if tiles.get_cell_source_id(cell + Vector2i.DOWN) < 0:
			unsupported += 1
	_check(embedded == 0 and unsupported == 0, "level %d placements avoid walls and enemies stand on platforms" % GameState.current_level)


func _test_live_gameplay() -> void:
	var scene := await _load_level(1)
	var player := scene.get_node("Player") as Player
	var health := player.get_node("Health") as Health
	var hud := get_tree().get_first_node_in_group("game_hud")
	await _capture("package3_entities")
	var small := scene.get_node("Entities/small1") as TokenPickup
	var big := scene.get_node("Entities/big1") as TokenPickup
	# A robot shot hits only the player layer, using the same shared damage path.
	var enemy_shot := preload("res://ui/placeholder_enemy/shot.tscn").instantiate()
	enemy_shot.source = self
	enemy_shot.speed = 0
	scene.add_child(enemy_shot)
	enemy_shot.global_position = player.global_position
	await _frames(5)
	_check(health.current == health.max_health - 1, "real robot projectile damages the current player")
	health.restore()
	var balance := GameState.tokens
	player.global_position = small.global_position
	await _frames(5)
	_check(GameState.tokens == balance + 1, "walking into a coin collects it through real physics")
	balance = GameState.tokens
	player.global_position = big.global_position
	await _frames(5)
	_check(GameState.tokens == balance + 5, "big coin awards five tokens")
	player.global_position = player.respawn_point
	var robot := scene.get_node("Entities/enemy1")
	# Fire the actual player projectile into an existing enemy hurtbox.
	var bullet := preload("res://characters/player/bullet.tscn").instantiate() as PlayerBullet
	bullet.damage = 10
	bullet.source = player
	bullet.speed = 0
	scene.add_child(bullet)
	bullet.global_position = robot.global_position
	await _frames(5)
	_check(_kills == 1 and _last_killer == player, "player projectile kills robot with player kill credit")
	_check(not is_instance_valid(robot), "dead robot leaves the level")
	player.set_shield(true)
	player.take_damage(1, self)
	_check(health.current == health.max_health, "current player shield API blocks damage")
	player.set_shield(false)
	await _frames(4)
	player.dash(Vector2.RIGHT)
	player.take_damage(1, self)
	_check(health.current == health.max_health, "current player dash grants invulnerability")
	await _frames(15)
	player.take_damage(99, self)
	await _frames(35)
	_check(_deaths == 1 and health.current == health.max_health, "lethal damage emits one death and restores health")
	_check(player.collision_layer == 2 and player.get_node("GunPivot").visible, "respawn restores player collisions and gun")
	# Existing pit implementation must bypass shields and respawn once as before.
	var deaths_before := _deaths
	player.set_shield(true)
	player.global_position = Vector2(1400, 680)
	await _frames(5)
	_check(_deaths == deaths_before + 1 and not player.shielded, "existing pits bypass shields and reset the player")
	GameState.add_tokens(3)
	GameState.energy = 0
	hud._feed_jarvis()
	_check(GameState.jarvis_enabled and GameState.energy > 24, "HUD feed button revives JARVIS")
	# F key feeds (once per press), and Space can never activate the FEED button.
	GameState.tokens = 6
	GameState.energy = 0
	Input.action_press("feed")
	await _frames(5)
	Input.action_release("feed")
	_check(GameState.energy > 24 and GameState.tokens == 3, "F feeds JARVIS once per press")
	_check(hud._feed.focus_mode == Control.FOCUS_NONE, "FEED button never takes keyboard focus")
	var space := InputEventKey.new()
	space.keycode = KEY_SPACE
	space.physical_keycode = KEY_SPACE
	space.pressed = true
	Input.parse_input_event(space)
	await _frames(2)
	space.pressed = false
	Input.parse_input_event(space)
	await _frames(1)
	_check(GameState.tokens == 3 and not hud._feed.has_focus(), "Space after feeding does not feed again")
	GameState.boss_health_changed.emit(60, 100)
	_check(hud._boss_box.visible and hud._boss.value == 60, "boss bar consumes existing health signal")
	GameState.boss_defeated.emit()
	_check(not hud._boss_box.visible, "boss bar hides after victory")
	await _capture("package3_level")
	hud.set_paused(true)
	var before := GameState.energy
	await _frames(10)
	_check(GameState.energy == before, "pause freezes gameplay and energy decay")
	await _capture("package3_pause")
	hud._show_settings()
	var settings := hud._settings.get_child(0) as AudioSettings
	var slider := settings.get_child(1).get_child(1) as HSlider
	var original := slider.value
	slider.value = 50
	_check(is_equal_approx(AudioServer.get_bus_volume_linear(0), 0.5), "settings slider controls Master volume while paused")
	slider.value = original
	hud.set_paused(false)
	GameState.gameplay_active = true
	GameState.add_tokens(20)
	hud._restart()
	await _frames()
	_check(GameState.tokens == 0 and GameState.energy > 99, "restart begins a clean chapter economy")
