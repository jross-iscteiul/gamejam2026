extends Node2D
## Integration checks for arena platforms, reinforcements, HUD ownership and boss explosions.
## godot --headless --path . res://tests/jarvis/test_boss_arena.tscn
## Omit --headless and add -- --visual to save review images under .godot/.

var _failed := false
var _defeated := 0


func _ready() -> void:
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	print(("PASS " if ok else "FAIL ") + message)
	_failed = _failed or not ok


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _capture(label: String) -> void:
	if not "--visual" in OS.get_cmdline_user_args():
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://.godot/" + label + ".png")


func _run() -> void:
	GameState.reset_run()
	GameState.god_mode = true
	var level: Node2D = load("res://levels/level_04/level_04.tscn").instantiate()
	add_child(level)
	await _frames(2)
	level.get_node("BossTrigger").monitoring = false
	var player: Player = level.get_node("Player")
	player.set_physics_process(false)
	var jarvis: Jarvis = get_tree().get_first_node_in_group("jarvis")
	jarvis.set_process(false)
	for enemy in get_tree().get_nodes_in_group("enemy"):
		enemy.set_physics_process(false)
	var hud: CanvasLayer = get_tree().get_first_node_in_group("game_hud")
	var tiles: TileMapLayer = level.get_node("Tiles")
	var solid_islands := false
	for x in [29, 30, 31, 32, 41, 42, 43, 44]:
		solid_islands = solid_islands or tiles.get_cell_source_id(Vector2i(x, 5)) != -1
	_check(not solid_islands, "upper islands no longer have solid tiles under their one-way platforms")
	for platform_name in ["PlatformLeft", "PlatformRight", "PlatformTop", "PlatformUpperLeft", "PlatformUpperRight"]:
		var platform: Node2D = level.get_node(platform_name)
		var top := platform.global_position.y - 16.0
		player.global_position = platform.global_position + Vector2(0, 64)
		player.velocity = Vector2(0, -500)
		var passed := false
		var landed := false
		for frame in 120:
			await get_tree().physics_frame
			player.velocity.y += 980.0 / 60.0
			player.move_and_slide()
			passed = passed or player.global_position.y + Player.FEET_Y < top - 8.0
			if passed and player.is_on_floor():
				landed = absf(player.global_position.y + Player.FEET_Y - top) < 3.0
				break
		_check(passed and landed, "%s lets the player jump through and land on top" % platform_name)
	player.global_position = Vector2(1184, 336)
	player.velocity = Vector2.ZERO
	player.get_node("Health").invulnerable = true
	GameState.set_god_mode(false)
	GameState.boss_label_changed.emit("FOREMAN UNIT")
	GameState.boss_health_changed.emit(18, 30)
	_check(hud._boss_box.visible and not hud._jarvis_health, "Foreman retains a separate compact health bar")
	GameState.jarvis_hostile = true
	GameState.boss_label_changed.emit("JARVIS")
	GameState.boss_health_changed.emit(9, 12)
	_check(hud._energy.value == 9 and hud._energy.max_value == 12 and hud._status.text.contains("HEALTH"), "JARVIS health replaces the top energy bar")
	_check(not hud._boss_box.visible and not hud._feed.visible, "JARVIS has no duplicate boss bar or feeding button")
	GameState.energy = 7
	_check(hud._energy.value == 9 and hud._energy.max_value == 12, "energy changes cannot overwrite boss health")
	GameState.boss_label_changed.emit("")
	GameState.jarvis_hostile = false
	_check(hud._energy.max_value == GameState.MAX_ENERGY and not hud._status.text.contains("HEALTH"), "normal HUD restores the energy meter")
	GameState.energy = GameState.MAX_ENERGY
	var spawner: Node2D = level.get_node("Entities/CeilingMinions")
	_check(not level.has_node("Entities/MinionDoor") and not level.has_node("Entities/MinionDoorLeft"), "both floor spawn doors are removed")
	level.get_node("Entities/BossRobot")._activate(player)
	_check(spawner.active, "boss activation starts the ceiling reinforcement controller")
	# Keep the controller active for manual drops without automatic waves during this check.
	spawner.first_delay = 1000
	spawner.set_active(true)
	spawner.drop_minion()
	var minion: CharacterBody2D = get_child(get_child_count() - 1)
	_check(minion.is_in_group("enemy") and minion.global_position.y == spawner.drop_y, "reinforcement starts below the ceiling")
	minion.fire_interval = 1000
	minion._shot_left = 1000
	await _frames(90)
	_check(minion.is_on_floor() and absf(minion.global_position.y - 336.0) < 2.0, "minion falls through raised platforms to the arena floor")
	minion.speed = 900
	var left := minion.global_position.x
	var right := left
	for frame in 110:
		await get_tree().physics_frame
		left = minf(left, minion.global_position.x)
		right = maxf(right, minion.global_position.x)
	_check(left < spawner.patrol_bounds.x + 20 and right > spawner.patrol_bounds.y - 20, "minion patrol reaches both ends of the entire arena floor")
	minion.set_physics_process(false)
	var rocket: Hitbox = load("res://characters/jarvis/missile.gd").new()
	rocket.position = Vector2(1184, 80)
	add_child(rocket)
	rocket.set_physics_process(false)
	var shape: CollisionShape2D = rocket.get_children().filter(func(child: Node) -> bool: return child is CollisionShape2D)[0]
	_check(rocket.size == 1.5 and shape.shape.radius == 4.5, "rocket art and contact hitbox are half their original size")
	var before := get_tree().get_nodes_in_group("enemy").size()
	rocket._on_ground(level)
	await _frames(2)
	var dropped: Node2D = get_child(get_child_count() - 1)
	_check(get_tree().get_nodes_in_group("enemy").size() == before + 1 and dropped.global_position.y < 100, "rocket impact sends its reinforcement from the ceiling")
	dropped.set_physics_process(false)
	spawner.max_alive = get_tree().get_nodes_in_group("enemy").filter(func(node: Node) -> bool: return not node.is_in_group("boss") and not node.is_in_group("jarvis")).size()
	spawner.drop_minion()
	_check(get_tree().get_nodes_in_group("enemy").size() == before + 1, "ceiling drops respect the shared minion cap")
	spawner.shut_down()
	spawner.set_active(true)
	spawner.drop_minion()
	_check(not spawner.active and get_tree().get_nodes_in_group("enemy").size() == before + 1, "network shutdown permanently stops reinforcements")
	var foreman: BossRobot = level.get_node("Entities/BossRobot")
	var foreman_at := foreman.global_position
	foreman._power_down()
	await get_tree().create_timer(0.2).timeout
	_check(foreman.global_position == foreman_at and not foreman.get_node("Sprite").visible and not get_tree().get_nodes_in_group("boss_explosion").is_empty(), "Foreman explodes in place without leaving a falling body")
	jarvis.hostile = true
	GameState.jarvis_hostile = true
	jarvis.position = Vector2(1260, 310)
	jarvis.mech = load("res://characters/jarvis/mech_frame.gd").new()
	jarvis.mech.scale = Vector2.ONE * jarvis.betrayal_giant_scale
	jarvis.add_child(jarvis.mech)
	jarvis.move_child(jarvis.mech, 0)
	for i in 3:
		await jarvis._mount_unit(jarvis._spare_unit(i), i)
	jarvis.seat_offset = jarvis.mech.SEAT_POINT * jarvis.betrayal_giant_scale
	jarvis.body.position = jarvis.seat_offset
	jarvis.body.scale = Vector2.ONE * jarvis.betrayal_pilot_scale
	jarvis.body.set_face("furious")
	var fight := JarvisBoss.new()
	jarvis.add_child(fight)
	fight.set_physics_process(false)
	fight._walker.set_physics_process(false)
	fight.defeated.connect(func() -> void: _defeated += 1)
	player.get_node("Camera2D").position_smoothing_enabled = false
	await _frames(2)
	await _capture("boss_arena_updated")
	var mech_at := jarvis.global_position
	var mech_angle := jarvis.mech.rotation
	fight._health.invulnerable = false
	fight._health.take_damage(100, player)
	await get_tree().create_timer(0.2).timeout
	_check(jarvis.global_position == mech_at and jarvis.mech.rotation == mech_angle and not get_tree().get_nodes_in_group("boss_explosion").is_empty(), "JARVIS mech detonates without falling or spinning")
	await _capture("boss_arena_explosion")
	await get_tree().create_timer(1.1).timeout
	_check(_defeated == 1 and not is_instance_valid(jarvis), "stationary defeat sequence finishes exactly once")
	get_tree().quit(1 if _failed else 0)
