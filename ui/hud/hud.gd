extends CanvasLayer
## Scene-local HUD and pause menu. No transition manager or cutscene ownership here.

var _root: Control
var _tokens: Label
var _health: ProgressBar
var _health_text: Label
var _timer: Label
var _sector: Label
var _leaderboard_page: VBoxContainer
var _status: Label
var _energy: ProgressBar
var _feed: Button
var _boss_box: VBoxContainer
var _boss_label: Label
## Labels that get the full-width bar at the bottom; any other boss (the Foreman warm-up) gets a
## small bar tucked into the top-right corner, out of the way of the fight.
const MAIN_BOSS_LABELS: PackedStringArray = ["JARVIS"]
var _boss_compact: bool = false
var _boss: ProgressBar
var _speech: Label
var _notice: Label
var _overlay: ColorRect
var _pause_actions: VBoxContainer
var _settings: VBoxContainer
var _pause_title: Label
var _speech_time: float = 0.0
var _notice_time: float = 0.0
var _click: AudioStream
var _touch_controls: MobileTouchControls


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	AudioSettings.load_volumes()
	_click = GameUI.chime()
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = GameUI.theme()
	add_child(_root)
	_build_hud()
	_touch_controls = MobileTouchControls.new()
	_root.add_child(_touch_controls)
	_touch_controls.visibility_changed.connect(_layout_bottom_bars)
	_layout_bottom_bars()
	_build_pause()
	GameState.tokens_changed.connect(_update_tokens)
	GameState.energy_changed.connect(_update_energy)
	GameState.jarvis_enabled_changed.connect(func(_enabled: bool) -> void: _update_energy(GameState.energy))
	GameState.god_mode_changed.connect(_on_god_mode_changed)
	GameState.boss_health_changed.connect(_update_boss)
	GameState.boss_label_changed.connect(_update_boss_label)
	GameState.boss_defeated.connect(_boss_defeated)
	GameState.jarvis_say.connect(_say)
	GameState.token_collected.connect(func(value: int) -> void: notify("+%d TOKEN%s" % [value, "S" if value != 1 else ""]))
	GameState.player_respawned.connect(func() -> void: notify("CHECKPOINT RESTORED"))
	var player := get_tree().get_first_node_in_group("player")
	if player:
		var health := player.get_node_or_null("Health") as Health
		if health:
			health.changed.connect(_update_health)
			_update_health(health.current, health.max_health)
	_update_tokens(GameState.tokens)
	_update_energy(GameState.energy)


func _build_hud() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	margin.offset_left = 32
	margin.offset_top = 24
	margin.offset_right = -32
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(margin)
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", GameUI.style(Color("131c2eea")))
	margin.add_child(panel)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(row)
	var info := VBoxContainer.new()
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.custom_minimum_size.x = 280
	_sector = GameUI.label("SECTOR %02d / 04" % GameState.current_level, 16, GameUI.MUTED)
	info.add_child(_sector)
	_timer = GameUI.label("00:00.000", 24, GameUI.GOLD)
	_timer.tooltip_text = "Run time: pause stops the clock; deaths keep counting."
	info.add_child(_timer)
	row.add_child(info)
	var energy_box := VBoxContainer.new()
	energy_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	energy_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status = GameUI.label("JARVIS / ENERGY", 16, GameUI.CYAN)
	energy_box.add_child(_status)
	_energy = ProgressBar.new()
	_energy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_energy.custom_minimum_size = Vector2(300, 28)
	_energy.show_percentage = false
	energy_box.add_child(_energy)
	row.add_child(energy_box)
	_tokens = GameUI.label("TOKENS 000", 24, GameUI.GOLD)
	_tokens.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_tokens.custom_minimum_size.x = 264
	row.add_child(_tokens)
	_feed = GameUI.button("FEED [F] / 3", _feed_jarvis)
	_feed.tooltip_text = "F: spend 3 tokens to compact JARVIS's context: +25% energy. JARVIS shuts down at zero energy."
	# Never keep keyboard focus: a focused button is activated by Space, which also jumps.
	_feed.focus_mode = Control.FOCUS_NONE
	row.add_child(_feed)
	var pause := GameUI.button("II", func() -> void: set_paused(true))
	pause.tooltip_text = "Pause (Esc / P)"
	row.add_child(pause)
	var health_panel := PanelContainer.new()
	health_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	health_panel.offset_left = -240
	health_panel.offset_right = 240
	health_panel.offset_top = -116
	health_panel.offset_bottom = -32
	health_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	health_panel.add_theme_stylebox_override("panel", GameUI.style(Color("131c2eea")))
	_root.add_child(health_panel)
	var health_column := VBoxContainer.new()
	health_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	health_column.add_theme_constant_override("separation", 8)
	health_panel.add_child(health_column)
	_health_text = GameUI.label("HEALTH 3 / 3", 16, GameUI.TEXT)
	_health_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	health_column.add_child(_health_text)
	_health = ProgressBar.new()
	_health.custom_minimum_size.y = 24
	_health.show_percentage = false
	_health.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_health.add_theme_stylebox_override("fill", GameUI.style(GameUI.RED, GameUI.RED))
	health_column.add_child(_health)
	_boss_box = VBoxContainer.new()
	_boss_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_boss_box.offset_left = -420
	_boss_box.offset_right = 420
	_boss_box.offset_top = -128
	_boss_box.offset_bottom = -40
	_boss_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_label = GameUI.label("BOSS", 24, GameUI.RED)
	_boss_box.add_child(_boss_label)
	_boss = ProgressBar.new()
	_boss.custom_minimum_size.y = 32
	_boss.show_percentage = false
	_boss.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss.add_theme_stylebox_override("fill", GameUI.style(GameUI.RED, GameUI.RED))
	_boss_box.add_child(_boss)
	_root.add_child(_boss_box)
	_boss_box.hide()
	_speech = GameUI.label("", 16, GameUI.CYAN)
	_speech.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_speech.offset_left = 64
	_speech.offset_top = 158
	_speech.offset_right = -64
	_speech.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_speech.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_speech.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_speech.add_theme_color_override("font_shadow_color", GameUI.INK)
	_speech.add_theme_constant_override("shadow_offset_x", 3)
	_speech.add_theme_constant_override("shadow_offset_y", 3)
	_root.add_child(_speech)
	_notice = GameUI.label("", 16, GameUI.GOLD)
	_notice.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_notice.offset_left = 48
	_notice.offset_top = -64
	_notice.offset_right = 1000
	_notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_notice)


func _build_pause() -> void:
	_overlay = ColorRect.new()
	_overlay.color = Color("080e1be8")
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_overlay)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 720
	panel.add_theme_stylebox_override("panel", GameUI.style(GameUI.PANEL, GameUI.CYAN))
	center.add_child(panel)
	var column := VBoxContainer.new()
	panel.add_child(column)
	_pause_title = GameUI.label("PAUSED", 32, GameUI.CYAN)
	column.add_child(_pause_title)
	_pause_actions = VBoxContainer.new()
	_pause_actions.add_child(GameUI.button("RESUME", func() -> void: set_paused(false)))
	_pause_actions.add_child(GameUI.button("SETTINGS", _show_settings))
	_pause_actions.add_child(GameUI.button("LEADERBOARD", _show_leaderboard))
	_pause_actions.add_child(GameUI.button("RESTART LEVEL", _restart))
	_pause_actions.add_child(GameUI.button("MAIN MENU", _main_menu))
	column.add_child(_pause_actions)
	_settings = VBoxContainer.new()
	_settings.add_child(AudioSettings.new())
	_settings.add_child(ControlSettings.new())
	_settings.add_child(GameUI.button("BACK", _hide_settings))
	column.add_child(_settings)
	_leaderboard_page = VBoxContainer.new()
	_leaderboard_page.add_child(LeaderboardPanel.new())
	_leaderboard_page.add_child(GameUI.button("BACK", _hide_settings))
	column.add_child(_leaderboard_page)
	_leaderboard_page.hide()
	_settings.hide()
	_overlay.hide()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("god_mode") and not get_tree().paused:
		if GameState.toggle_god_mode():
			notify("GOD MODE ON" if GameState.god_mode else "GOD MODE OFF")
		else:
			notify("GOD MODE: PRACTICE ONLY")
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("pause"):
		set_paused(not get_tree().paused)
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_timer.text = RunClock.format_time(GameState.run_clock.elapsed_msec)
	_sector.text = ("SECTOR %02d / 04" if GameState.run_clock.eligible else "PRACTICE / %02d") % GameState.current_level
	if get_tree().paused:
		return
	if Input.is_action_just_pressed("feed"): # F key or the mobile FEED pad
		_feed_jarvis()
	_speech_time -= delta
	_notice_time -= delta
	_speech.visible = _speech_time > 0.0
	_notice.visible = _notice_time > 0.0


func _on_god_mode_changed(_active: bool) -> void:
	_update_tokens(GameState.tokens)
	_update_energy(GameState.energy)


func _update_tokens(value: int) -> void:
	_tokens.text = "TOKENS INF" if GameState.god_mode else "TOKENS %03d" % value
	_update_feed()


func _update_energy(value: float) -> void:
	_energy.value = value
	var state := "ENERGY" if GameState.jarvis_enabled else "OFFLINE"
	_status.text = "JARVIS / %s / %d%%" % [state, ceili(value)]
	if GameState.god_mode:
		_status.text = "JARVIS / GOD MODE / INF"
	_status.add_theme_color_override("font_color", GameUI.RED if value <= 20 else GameUI.CYAN)
	_update_feed()


func _update_feed() -> void:
	_feed.disabled = GameState.tokens < GameState.FEED_COST or GameState.energy >= GameState.MAX_ENERGY or GameState.jarvis_hostile


func _feed_jarvis() -> void:
	if GameState.feed_jarvis():
		GameUI.play_sound(self, _click)
		# Feeding tokens compacts JARVIS's context, freeing energy.
		notify("+%d%% COMPACTION" % roundi(GameState.FEED_ENERGY))


func _update_health(value: float, maximum: float) -> void:
	_health.max_value = maxf(maximum, 1.0)
	_health.value = value
	_health_text.text = "HEALTH %d / %d" % [ceili(value), ceili(maximum)]


func _layout_bottom_bars() -> void:
	if _boss_compact:
		_boss_box.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		_boss_box.offset_left = -432
		_boss_box.offset_right = -32
		_boss_box.offset_top = 132
		_boss_box.offset_bottom = 184
		_boss_label.add_theme_font_size_override("font_size", 16)
		_boss.custom_minimum_size.y = 14
		return
	_boss_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_boss_box.offset_left = -420
	_boss_box.offset_right = 420
	_boss_box.offset_top = -480 if _touch_controls.visible else -240
	_boss_box.offset_bottom = -392 if _touch_controls.visible else -152
	_boss_label.add_theme_font_size_override("font_size", 24)
	_boss.custom_minimum_size.y = 32


func _update_boss(value: float, maximum: float) -> void:
	_boss_box.visible = maximum > 0.0 and value > 0.0
	_boss.max_value = maxf(1.0, maximum)
	_boss.value = value


## An empty label means no boss holds the bar (e.g. the handover): hide it until the next
## boss reports its health.
func _update_boss_label(label: String) -> void:
	_boss_label.text = label
	if label.is_empty():
		_boss_box.hide()
		return
	_boss_compact = not MAIN_BOSS_LABELS.has(label)
	_layout_bottom_bars()


func _boss_defeated() -> void:
	_boss_box.hide()
	notify("BOSS DEFEATED")
	if GameState.run_clock.eligible:
		set_paused(true)
		_show_leaderboard()


func _say(text: String, _mood: String) -> void:
	# JARVIS shows his own lines in a speech bubble; the HUD only covers scenes without him.
	if get_tree().get_first_node_in_group("jarvis") != null:
		return
	_speech.text = "JARVIS: " + text
	_speech_time = 4.0
	_speech.show()


func notify(text: String) -> void:
	_notice.text = text
	_notice_time = 2.0
	_notice.show()


func set_paused(active: bool) -> void:
	_touch_controls.set_gameplay_paused(active)
	get_tree().paused = active
	_overlay.visible = active
	_hide_settings()
	if active:
		_pause_actions.get_child(0).grab_focus()
	GameUI.play_sound(self, _click)


func _show_settings() -> void:
	_pause_actions.hide()
	_settings.show()
	_pause_title.text = "SETTINGS"


func _hide_settings() -> void:
	_pause_actions.show()
	_settings.hide()
	_pause_title.text = "PAUSED"
	_leaderboard_page.hide()


func _show_leaderboard() -> void:
	_pause_actions.hide()
	_settings.hide()
	_leaderboard_page.show()
	_pause_title.text = "RUN TIMES"


func _restart() -> void:
	get_tree().paused = false
	# Restart the current chapter with a clean economy, so reloading cannot farm pickups.
	var level := GameState.current_level
	GameState.reset_run()
	get_tree().change_scene_to_file("res://levels/level_%02d/level_%02d.tscn" % [level, level])


func _main_menu() -> void:
	get_tree().paused = false
	GameState.gameplay_active = false
	get_tree().change_scene_to_file("res://ui/menus/main_menu.tscn")
