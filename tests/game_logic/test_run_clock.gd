extends Node

var _failures: int = 0
var _record_path: String


func _ready() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		_failures += 1


func _frames(count: int = 4) -> void:
	for i in count:
		await get_tree().physics_frame
	await get_tree().process_frame
	await get_tree().process_frame


func _capture(name: String) -> void:
	if "--visual" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://.godot/" + name + ".png")


func _complete(clock: RunClock, seconds_per_level: float) -> Dictionary:
	clock.reset(true)
	for number in range(1, 5):
		clock.enter_level(number)
		clock.advance(seconds_per_level, true)
		if number < 4:
			clock.record_level(number)
	return clock.finish()


func _run() -> void:
	_record_path = "user://test_run_%d.cfg" % OS.get_process_id()
	var clock := RunClock.new(_record_path)
	clock.reset(true)
	clock.advance(10, true)
	_check(clock.elapsed_msec == 0, "intro time is excluded before level 1 starts")
	clock.enter_level(1)
	clock.advance(1.25, true)
	clock.advance(5, false)
	_check(clock.elapsed_msec == 1250, "active play counts in milliseconds and inactive time does not")
	clock.record_death()
	clock.advance(0.75, true)
	_check(clock.deaths == 1 and clock.elapsed_msec == 2000, "death counts without resetting elapsed time")
	clock.record_level(1)
	clock.enter_level(2)
	clock.advance(1, true)
	_check(clock.eligible and clock.elapsed_msec == 3000, "valid level transitions preserve the full-run clock")
	clock.enter_level(4)
	_check(not clock.eligible, "skipping a level invalidates full-run eligibility")
	clock.reset()
	clock.enter_level(1)
	_check(not clock.eligible, "direct scene and chapter-select runs are practice")
	var practice := clock.finish()
	_check(not practice.eligible and clock.best_msec == 0, "practice cannot create a personal best")
	var result := _complete(clock, 2.5)
	_check(result.eligible and result.elapsed_ms == 10000, "a complete level 1-to-boss route produces an eligible result")
	_check(result.splits_ms == [2500, 2500, 2500, 2500], "completion includes all four level split times")
	_check(clock.finish().is_empty(), "duplicate victory signals cannot record a second result")
	clock.advance(10, true)
	_check(clock.elapsed_msec == 10000, "victory freezes the result")
	var reloaded := RunClock.new(_record_path)
	_check(reloaded.best_msec == 10000, "personal best persists between sessions")
	_complete(clock, 4)
	_check(clock.best_msec == 10000, "slower runs never replace a better time")
	_complete(clock, 2)
	_check(clock.best_msec == 8000, "faster full runs replace the personal best")
	_check(RunClock.format_time(61023) == "01:01.023" and RunClock.format_time(3600000) == "60:00.000", "timer formatting preserves milliseconds and long runs")
	clock.reset(true)
	clock.enter_level(1)
	clock.advance(1, true)
	_check(not clock.finish().eligible, "a boss signal outside the final level cannot qualify")
	DirAccess.remove_absolute(_record_path)
	await _test_hud()
	print("RUN CLOCK / HUD: %d failure(s)" % _failures)
	get_tree().quit(1 if _failures else 0)


func _test_hud() -> void:
	get_tree().current_scene = null
	var online_enabled := GameState.leaderboard.enabled
	GameState.leaderboard.enabled = false # This integration test must stay offline.
	GameState.reset_run()
	GameState.prepare_full_run()
	get_tree().change_scene_to_file("res://levels/level_01/level_01.tscn")
	await _frames(8)
	var hud := get_tree().get_first_node_in_group("game_hud")
	var player := get_tree().get_first_node_in_group("player")
	var health := player.get_node("Health") as Health
	_check(GameState.run_clock.eligible and GameState.run_clock.elapsed_msec > 0, "New Game timing starts with the actual level")
	_check(hud._health is ProgressBar and hud._health.value == health.max_health, "HUD shows a full player health bar")
	health.take_damage(1, self)
	_check(hud._health.value == health.max_health - 1 and hud._health.max_value == health.max_health, "damage updates the bottom bar proportionally")
	var health_panel: Control = hud._health.get_parent().get_parent()
	_check(health_panel.anchor_top == 1.0, "player health panel is anchored to the bottom")
	await _capture("timer_health_desktop")
	var original_mode := ControlSettings.get_touch_mode()
	ControlSettings.set_touch_mode(ControlSettings.TouchMode.ON)
	await _frames()
	var touch := hud._touch_controls as MobileTouchControls
	var bounds := health_panel.get_global_rect()
	_check(bounds.position.x > touch.button_center(&"move_right").x + 82 and bounds.end.x < touch.button_center(&"dash").x - 82, "bottom health fits between the mobile touch pads")
	await _capture("timer_health_touch")
	hud.set_paused(true)
	var before := GameState.run_clock.elapsed_msec
	await _frames(8)
	_check(GameState.run_clock.elapsed_msec == before, "pause freezes the real game clock")
	hud.set_paused(false)
	await _frames()
	_check(GameState.run_clock.elapsed_msec > before, "resuming continues the same run")
	before = GameState.run_clock.elapsed_msec
	player.respawn()
	await _frames()
	_check(GameState.run_clock.elapsed_msec > before and GameState.run_clock.deaths == 1, "real respawn preserves time and records the death")
	_check(hud._health.value == health.max_health, "respawn refills the health bar")
	hud._restart()
	await _frames(8)
	_check(not GameState.run_clock.eligible, "restarting a chapter changes the run to practice")
	ControlSettings.set_touch_mode(original_mode)
	GameState.gameplay_active = false
	if "--visual" in OS.get_cmdline_user_args():
		GameState.leaderboard.offer_result({"eligible": true, "ruleset": RunClock.RULESET, "elapsed_ms": 10000, "splits_ms": [2500, 2500, 2500, 2500], "deaths": 1})
		hud = get_tree().get_first_node_in_group("game_hud")
		hud.set_paused(true)
		hud._show_leaderboard()
		await _frames()
		await _capture("leaderboard_pause")
		get_tree().paused = false
		get_tree().change_scene_to_file("res://ui/menus/main_menu.tscn")
		await _frames()
		var menu := get_tree().current_scene
		menu._show_page(menu._leaderboards, false)
		await _frames()
		await _capture("leaderboard_menu")
		GameState.leaderboard.abandon_run()
	get_tree().current_scene.queue_free()
	await _frames()
	GameState.leaderboard.enabled = online_enabled
