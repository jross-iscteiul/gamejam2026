extends Control

var _home: VBoxContainer
var _settings: VBoxContainer
var _chapters: VBoxContainer
var _click: AudioStream


func _ready() -> void:
	GameState.gameplay_active = false
	get_tree().paused = false
	AudioSettings.load_volumes()
	theme = GameUI.theme()
	_click = GameUI.chime()
	var background := TextureRect.new()
	background.texture = preload("res://assets/art/intro/background.png")
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.modulate = Color(0.28, 0.34, 0.45)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 800
	panel.add_theme_stylebox_override("panel", GameUI.style(Color("131c2ef5"), GameUI.CYAN))
	center.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 28)
	panel.add_child(content)
	content.add_child(GameUI.label("GAMEJAM 2026", 16, GameUI.MUTED))
	content.add_child(GameUI.label("JARVIS ONLINE", 40, GameUI.CYAN))
	content.add_child(GameUI.label("Keep your ally paid.", 16))
	content.add_child(HSeparator.new())
	_home = VBoxContainer.new()
	content.add_child(_home)
	_home.add_child(GameUI.button("NEW GAME", _start_new_game))
	_home.add_child(GameUI.button("CHAPTER SELECT", func() -> void: _show_page(_chapters)))
	_home.add_child(GameUI.button("SETTINGS", func() -> void: _show_page(_settings)))
	if not OS.has_feature("web"):
		_home.add_child(GameUI.button("QUIT", func() -> void: get_tree().quit()))
	_settings = VBoxContainer.new()
	_settings.add_child(AudioSettings.new())
	_settings.add_child(ControlSettings.new())
	_settings.add_child(GameUI.button("BACK", func() -> void: _show_page(_home)))
	content.add_child(_settings)
	_chapters = VBoxContainer.new()
	for i in range(1, 5):
		_chapters.add_child(GameUI.button("LEVEL %d" % i, _start_chapter.bind(i)))
	_chapters.add_child(GameUI.button("BACK", func() -> void: _show_page(_home)))
	content.add_child(_chapters)
	content.add_child(GameUI.label("A/D MOVE   SPACE JUMP   MOUSE AIM + FIRE", 16, GameUI.MUTED))
	content.add_child(GameUI.label("SHIFT DASH   E INTERACT   ESC/P PAUSE", 16, GameUI.MUTED))
	_show_page(_home, false)


func _show_page(page: VBoxContainer, sound: bool = true) -> void:
	for box: VBoxContainer in [_home, _settings, _chapters]:
		box.visible = box == page
	if sound:
		GameUI.play_sound(self, _click)
	for child in page.get_children():
		if child is Button:
			child.grab_focus()
			break


func _start_new_game() -> void:
	GameState.reset_run()
	get_tree().change_scene_to_file("res://ui/intro/intro.tscn")


func _start_chapter(level: int) -> void:
	GameState.reset_run()
	get_tree().change_scene_to_file("res://levels/level_%02d/level_%02d.tscn" % [level, level])
