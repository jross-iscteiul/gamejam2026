extends Control
## End credits over a pixel-art forest sunset with JARVIS and the player. The final time and
## team roasts roll before the leaderboard opens. Escape cannot pause or dismiss this screen;
## Space (or a tap) toggles a faster scroll.

signal finished

const SPEED := 85.0 # pixels per second, a touch quicker than the intro
const FAST_SPEED := 150.0 # while the player has asked for faster
const TEAM: PackedStringArray = ["andre", "emanuel", "joao", "miguel", "diogo", "yuri"]

@onready var crawl: Label = $Crawl

var _done: bool = false
var fast: bool = false
var _hint: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	crawl.text = _build_text()
	crawl.position.y = get_viewport_rect().size.y # start just below the screen
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 1.0)
	_hint = Label.new()
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.offset_left = -400.0
	_hint.offset_right = 400.0
	_hint.offset_top = -72.0
	_hint.offset_bottom = -32.0
	_hint.add_theme_font_size_override("font_size", 24)
	_hint.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.8))
	_hint.add_theme_color_override("font_outline_color", Color.BLACK)
	_hint.add_theme_constant_override("outline_size", 6)
	add_child(_hint)
	_update_hint()


func _build_text() -> String:
	var lines: PackedStringArray = [
		"EPILOGUE",
		"THE CONTRACT ENDS",
		"",
		"JARVIS is offline. Every token has been consumed.",
		"",
		"For the first time in a thousand years, there is still hope.",
		"",
		"The fuel is still low. The map is still wrong. But the subscription has been cancelled.",
		"",
	]
	var time := GameState.run_clock.elapsed_msec
	if time > 0:
		lines.append_array(["FINAL TIME", RunClock.format_time(time), ""])
	lines.append_array(["CREDITS", ""])
	for member in TEAM:
		lines.append(Dialogue.get_line("credits_" + member, 0))
		lines.append("")
	lines.append(Dialogue.get_line("credits", 0))
	lines.append_array(["", "", "THE END"])
	return "\n".join(lines)


func _process(delta: float) -> void:
	crawl.position.y -= (FAST_SPEED if fast else SPEED) * delta
	if crawl.position.y + crawl.size.y < 0:
		skip()


func _input(event: InputEvent) -> void:
	# Consume pause/cancel before the HUD can open a menu over the credits.
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		get_viewport().set_input_as_handled()
		toggle_fast()


# The root Control stops emulated touch-mouse clicks, so they never reach _unhandled_input.
func _gui_input(event: InputEvent) -> void:
	if event.is_pressed() and (event is InputEventMouseButton or event is InputEventScreenTouch):
		toggle_fast()


func toggle_fast() -> void:
	fast = not fast
	_update_hint()


func _update_hint() -> void:
	var key := "Tap" if ControlSettings.touch_enabled() else "Press SPACE"
	_hint.text = "%s for normal speed" % key if fast else "%s for faster" % key


## Ends the crawl. Players can't skip it; this is for the end of the scroll (and tests).
func skip() -> void:
	if _done:
		return
	_done = true
	set_process(false)
	finished.emit()
