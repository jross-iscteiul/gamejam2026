class_name WheelUI
extends CanvasLayer
## JARVIS "probability engine" overlay opened by a GamblingStation. Owned by Package 6.
##
## Pauses the game while open. The result is decided by the station first,
## then the wheel animates to it (including the troll animations).
## [E]/[Space] spin, [Esc]/[P] leave.

signal closed

const SPIN_TURNS := 5
const SPIN_TIME := 3.0
const LAYOUT_SIZE := Vector2(640, 360)
## Colors match MachineDrawing (industrial tileset palette).
const NEUTRAL := MachineDrawing.TEAL
const ALERT := MachineDrawing.RED
const WIN := MachineDrawing.YELLOW
const CRT_TEXT := MachineDrawing.CRT_GREEN

## Show JARVIS lines inside the wheel. Turn off once JARVIS's own speech
## bubble is visible above the overlay.
@export var show_jarvis_lines: bool = true

var station: GamblingStation

var _spinning := false
## Level music (Package 5's "LevelMusic" under the root) and its original
## process mode, so it keeps playing while the machine pauses the game.
var _music: Node
var _music_mode: Node.ProcessMode
var _spin_button: Button
var _exit_button: Button
var _slices: Array = [
	{"outcome": GamblingOdds.Outcome.JACKPOT, "label": "OVERCLOCK", "color": Color("e8b01c")},
	{"outcome": GamblingOdds.Outcome.NOTHING, "label": "NULL", "color": Color("4a5a78")},
	{"outcome": GamblingOdds.Outcome.DOUBLE, "label": "x2 BOOST", "color": Color("23a888")},
	{"outcome": GamblingOdds.Outcome.TAX, "label": "CPU TAX", "color": Color("d0381f")},
	{"outcome": GamblingOdds.Outcome.ENERGY_BOOST, "label": "RECHARGE", "color": Color("3f7fd0")},
	{"outcome": GamblingOdds.Outcome.ENERGY_DRAIN, "label": "MALWARE", "color": Color("7a44c0")},
	{"outcome": GamblingOdds.Outcome.REFUND, "label": "ROLLBACK", "color": Color("7f98b8")},
	{"outcome": GamblingOdds.Outcome.JARVIS_RAISE, "label": "JARVIS FEE", "color": Color("e8701a")},
]

@onready var _wheel: Node2D = $Wheel
@onready var _frame: Node2D = $Frame
@onready var _cabinet: Node2D = $Cabinet
@onready var _jarvis_label: Label = $JarvisLabel
@onready var _result_label: Label = $ResultLabel
@onready var _info_label: Label = $InfoLabel


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_fit_to_screen()
	get_viewport().size_changed.connect(_fit_to_screen)
	for label: Label in [_jarvis_label, _result_label, _info_label]:
		label.add_theme_font_override("font", PixelFont.get_font())
	_wheel.slices = _slices
	_wheel.rotation = _rotation_for(0)
	_set_result("> AWAITING INPUT_", CRT_TEXT)
	if station != null:
		_cabinet.level = station.get_level()
	_jarvis_label.text = ""
	_jarvis_label.visible = show_jarvis_lines
	GameState.jarvis_say.connect(_on_jarvis_say)
	GameState.tokens_changed.connect(_on_tokens_changed)
	_build_buttons()
	_set_touch_paused(true)
	_keep_music_playing(true)
	get_tree().paused = true
	_update_info()


## Tappable/clickable buttons beside the machine, so it works on phones
## (Package 3's touch pad has no Esc) and with the mouse.
func _build_buttons() -> void:
	_spin_button = _make_button("SPIN", Rect2(536, 236, 96, 40), MachineDrawing.YELLOW, _on_spin_pressed)
	_exit_button = _make_button("EXIT", Rect2(8, 236, 96, 40), MachineDrawing.STEEL_LIGHT, close)


## Buttons are built 3x bigger and scaled down so the pixel font stays crisp
## inside this 3x-scaled layer.
func _make_button(text: String, rect: Rect2, color: Color, action: Callable) -> Button:
	var k := 3.0
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.position = rect.position
	button.size = rect.size * k
	button.scale = Vector2.ONE / k
	button.add_theme_font_override("font", PixelFont.SOURCE)
	button.add_theme_font_size_override("font_size", 24)
	for state: String in ["font_color", "font_hover_color", "font_pressed_color"]:
		button.add_theme_color_override(state, MachineDrawing.OUTLINE)
	button.add_theme_color_override("font_disabled_color", Color(MachineDrawing.OUTLINE, 0.4))
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		var box := StyleBoxFlat.new()
		box.bg_color = color.lightened(0.2) if state == "hover" else (color.darkened(0.25) if state == "pressed" else color)
		if state == "disabled":
			box.bg_color = color.darkened(0.5)
		box.border_color = MachineDrawing.OUTLINE
		box.set_border_width_all(6)
		button.add_theme_stylebox_override(state, box)
	button.pressed.connect(action)
	add_child(button)
	return button


func _on_spin_pressed() -> void:
	if not _spinning:
		_spin()


func _keep_music_playing(active: bool) -> void:
	if active:
		_music = get_tree().root.get_node_or_null("LevelMusic")
		if _music != null:
			_music_mode = _music.process_mode
			_music.process_mode = Node.PROCESS_MODE_ALWAYS
	elif is_instance_valid(_music):
		_music.process_mode = _music_mode
		_music = null


## Safety net: restore the music's mode even if the machine is freed some other way.
func _exit_tree() -> void:
	_keep_music_playing(false)


func _set_touch_paused(active: bool) -> void:
	var touch := get_tree().get_first_node_in_group("touch_controls")
	if touch != null and touch.has_method("set_gameplay_paused"):
		touch.set_gameplay_paused(active)


## The machine is laid out on a 640x360 canvas (one 32px-tile screen) and
## scaled up to the real viewport (1920x1080 = 3x), centered.
func _fit_to_screen() -> void:
	var screen := get_viewport().get_visible_rect().size
	var s := minf(screen.x / LAYOUT_SIZE.x, screen.y / LAYOUT_SIZE.y)
	scale = Vector2(s, s)
	offset = (screen - LAYOUT_SIZE * s) / 2.0
	$Dim.size = LAYOUT_SIZE + offset * 2.0 / s
	$Dim.position = -offset / s


func close() -> void:
	if _spinning:
		return
	_set_touch_paused(false)
	_keep_music_playing(false)
	get_tree().paused = false
	closed.emit()
	queue_free()


## _input (not _unhandled_input) so Esc closes the machine before the HUD's
## pause menu sees it.
func _input(event: InputEvent) -> void:
	var spin := event.is_action_pressed("interact") or event.is_action_pressed("jump")
	var leave := event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel")
	if not (spin or leave):
		return
	get_viewport().set_input_as_handled()
	if _spinning:
		return
	if spin:
		_spin()
	else:
		close()


func _spin() -> void:
	if station == null:
		return
	_spinning = true
	_wheel.highlight_index = -1
	_frame.eye_color = NEUTRAL
	var outcome := station.try_spin()
	_update_info()
	if outcome < 0:
		_set_result("> ACCESS DENIED", ALERT)
		_spinning = false
		_update_info()
		return

	_set_result("> COMPUTING...", CRT_TEXT)
	_frame.spinning = true
	var final_index := _index_of(outcome)
	match outcome:
		GamblingOdds.Outcome.FAKE_JACKPOT:
			var jackpot := _index_of(GamblingOdds.Outcome.JACKPOT)
			await _spin_to(jackpot, SPIN_TIME, SPIN_TURNS, 0.1)
			_frame.spinning = false
			_frame.eye_color = WIN
			_set_result("> OVERCLOCK!!! +%d TKN" % (station.get_cost() * station.jackpot_multiplier), WIN)
			await _blink(jackpot, 3)
			await _glitch(0.6)
			_frame.eye_color = ALERT
			final_index = _index_of(GamblingOdds.Outcome.NOTHING)
			await _nudge_to(final_index)
		GamblingOdds.Outcome.RESPIN_TROLL:
			await _spin_to(_index_of(GamblingOdds.Outcome.DOUBLE), SPIN_TIME * 0.8, SPIN_TURNS - 1)
			_frame.spinning = false
			await _shudder()
			_set_result("> CRITICAL ERROR. REBOOTING...", ALERT)
			await _glitch(0.4)
			_frame.spinning = true
			final_index = _index_of(GamblingOdds.Outcome.NOTHING)
			await _spin_to(final_index, SPIN_TIME * 0.6, 2)
		_:
			await _spin_to(final_index, SPIN_TIME, SPIN_TURNS)

	_frame.spinning = false
	station.apply_outcome(outcome)
	_frame.eye_color = _eye_color_for(outcome)
	_set_result("> " + station.describe_outcome(outcome), (_slices[final_index].color as Color).lightened(0.35))
	_spinning = false
	_update_info()
	_blink(final_index, 4)


## Rotation that puts slice [param index] under the pointer (top of the wheel).
func _rotation_for(index: int) -> float:
	return -PI / 2.0 - index * _wheel.get_step()


func _index_of(outcome: int) -> int:
	for i in _slices.size():
		if _slices[i].outcome == outcome:
			return i
	return 0


func _eye_color_for(outcome: int) -> Color:
	if GamblingOdds.is_win(outcome):
		return WIN
	if outcome == GamblingOdds.Outcome.REFUND:
		return NEUTRAL
	return ALERT


func _spin_to(index: int, duration: float, turns: int, jitter_amount: float = 0.35) -> void:
	var step: float = _wheel.get_step()
	var target := _rotation_for(index) + randf_range(-jitter_amount, jitter_amount) * step
	var min_target := _wheel.rotation + turns * TAU
	target += TAU * ceilf((min_target - target) / TAU)
	var tween := create_tween()
	tween.tween_property(_wheel, "rotation", target, duration) \
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	# Mechanical detent: click into the slice center (also keeps labels crisp).
	var detent := _rotation_for(index)
	detent += TAU * roundf((target - detent) / TAU)
	tween.tween_interval(0.08)
	tween.tween_property(_wheel, "rotation", detent, 0.15) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tween.finished


## Small "oops" move to a neighbouring slice (fake jackpot).
func _nudge_to(index: int) -> void:
	var target := _rotation_for(index)
	target += TAU * roundf((_wheel.rotation - target) / TAU)
	var tween := create_tween()
	tween.tween_property(_wheel, "rotation", target, 0.5) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tween.finished


func _shudder() -> void:
	var base: float = _wheel.rotation
	var tween := create_tween()
	for i in 4:
		tween.tween_property(_wheel, "rotation", base + 0.06, 0.05)
		tween.tween_property(_wheel, "rotation", base - 0.06, 0.05)
	tween.tween_property(_wheel, "rotation", base, 0.05)
	await tween.finished


## Digital glitch: the wheel jumps around and flickers colors.
func _glitch(duration: float) -> void:
	var base_pos: Vector2 = _wheel.position
	var label_x: float = _result_label.position.x
	var colors: Array[Color] = [ALERT, NEUTRAL, Color.WHITE, Color(1, 1, 1, 0.4)]
	var elapsed := 0.0
	while elapsed < duration:
		_wheel.position = base_pos + Vector2(randf_range(-6, 6), randf_range(-3, 3))
		_wheel.modulate = colors.pick_random()
		_result_label.position.x = label_x + randf_range(-4, 4)
		await get_tree().create_timer(0.04).timeout
		elapsed += 0.04
	_wheel.position = base_pos
	_wheel.modulate = Color.WHITE
	_result_label.position.x = label_x


func _blink(index: int, times: int) -> void:
	_wheel.highlight_index = index
	for i in times:
		_wheel.highlight_on = true
		await get_tree().create_timer(0.12).timeout
		_wheel.highlight_on = false
		await get_tree().create_timer(0.08).timeout
	_wheel.highlight_on = true


func _set_result(text: String, color: Color) -> void:
	_result_label.text = text
	_result_label.add_theme_color_override("font_color", color)


func _update_info() -> void:
	if station == null:
		return
	var controls := "[E] EXECUTE    [ESC] DISCONNECT" if station.spins_left > 0 else "NO CYCLES LEFT    [ESC] DISCONNECT"
	if _spin_button != null:
		_spin_button.disabled = _spinning or station.spins_left <= 0
		_exit_button.disabled = _spinning
	var cost := "FREE SPIN" if station.is_next_spin_free() else "COST %d TKN" % station.get_cost()
	_info_label.text = "%s  |  CYCLES %d  |  BALANCE %d TKN\n%s" % [
		cost, station.spins_left, GameState.tokens, controls,
	]


func _on_jarvis_say(text: String, _mood: String) -> void:
	_jarvis_label.text = "> JARVIS: " + text


func _on_tokens_changed(_tokens: int) -> void:
	_update_info()
