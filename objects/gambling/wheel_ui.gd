class_name WheelUI
extends CanvasLayer
## JARVIS gambling machine overlay opened by a GamblingStation. Owned by Package 6.
##
## Two games, chosen with the tabs at the top:
## - WHEEL: the result is decided by the station first, then the wheel animates
##   to it (including the troll animations).
## - HIGHER/LOWER ("montinho"): bet, guess if the next card is higher or lower,
##   keep the streak going to grow the pot, cash out any time. A wrong guess or
##   a tie loses everything.
##
## Keys: [A]/[D] stake, [W] all-in, [S] minimum, [E]/[Space] spin / deal / cash
## out, [D]/[W] higher and [A]/[S] lower during a card round, [Tab] switch game, [Esc] close.
##
## Pauses the game. Drawn under the HUD (layer 15 < HUD 20) and sized to fit
## between the HUD's bars, so tokens, energy and health stay visible.

signal closed

enum Mode { WHEEL, CARDS }

const SPIN_TURNS := 5
const SPIN_TIME := 3.0
const LAYOUT_SIZE := Vector2(640, 360)
## Screen space kept free for the HUD (fractions of the screen height).
const HUD_TOP := 0.125
const HUD_BOTTOM := 0.12
const NEUTRAL := MachineDrawing.TEAL
const ALERT := MachineDrawing.RED
const WIN := MachineDrawing.YELLOW

var station: GamblingStation
var mode: Mode = Mode.WHEEL

var _spinning := false
## Level music (Package 5's "LevelMusic" under the root) and its original
## process mode, so it keeps playing while the machine pauses the game.
var _music: Node
var _music_mode: Node.ProcessMode
var _action_button: Button
var _close_button: Button
var _minus_button: Button
var _plus_button: Button
var _min_button: Button
var _all_in_button: Button
var _wheel_tab: Button
var _cards_tab: Button
var _higher_button: Button
var _lower_button: Button
var _stake_label: Label
var _spins_label: Label
var _pot_label: Label
## Chosen stake for the next paid spin / deal.
var _stake := 0
var _tick_player: AudioStreamPlayer
var _last_tick_slice := 0
## Order matters: OVERCLOCK sits next to NULL (fake jackpot nudge).
var _slices: Array = [
	{"outcome": GamblingOdds.Outcome.JACKPOT, "label": "OVERCLOCK", "color": Color("e8b01c")},
	{"outcome": GamblingOdds.Outcome.NOTHING, "label": "NULL", "color": Color("4a5a78")},
	{"outcome": GamblingOdds.Outcome.DOUBLE, "label": "x2 BOOST", "color": Color("23a888")},
	{"outcome": GamblingOdds.Outcome.TAX, "label": "CPU TAX", "color": Color("d0381f")},
	{"outcome": GamblingOdds.Outcome.HEAL, "label": "REPAIR", "color": Color("d84a6a")},
	{"outcome": GamblingOdds.Outcome.ENERGY_DRAIN, "label": "MALWARE", "color": Color("7a44c0")},
	{"outcome": GamblingOdds.Outcome.ENERGY_BOOST, "label": "RECHARGE", "color": Color("3f7fd0")},
	{"outcome": GamblingOdds.Outcome.JARVIS_RAISE, "label": "JARVIS FEE", "color": Color("e8701a")},
	{"outcome": GamblingOdds.Outcome.TOKEN_MULTIPLIER, "label": "TOKENS x2", "color": Color("8fb82a")},
	{"outcome": GamblingOdds.Outcome.REFUND, "label": "ROLLBACK", "color": Color("7f98b8")},
	{"outcome": GamblingOdds.Outcome.GOD_MODE, "label": "GOD MODE", "color": Color("2b2b3a")},
]

@onready var _wheel: Node2D = $Wheel
@onready var _frame: Node2D = $Frame
@onready var _cabinet: Node2D = $Cabinet
@onready var _cards: Node2D = $Cards
@onready var _result_label: Label = $ResultLabel


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_fit_to_screen()
	get_viewport().size_changed.connect(_fit_to_screen)
	_result_label.add_theme_font_override("font", PixelFont.get_font())
	_wheel.slices = _slices
	_wheel.rotation = _rotation_for(0)
	if station != null:
		_cabinet.level = station.get_level()
	GameState.tokens_changed.connect(_on_tokens_changed)
	_build_buttons()
	_set_mode(Mode.WHEEL)
	_set_touch_paused(true)
	_keep_music_playing(true)
	get_tree().paused = true
	_tick_player = AudioStreamPlayer.new()
	_tick_player.bus = &"SFX"
	_tick_player.stream = _make_tick()
	_tick_player.max_polyphony = 4
	add_child(_tick_player)
	# A machine with a free spin spins on its own as soon as it opens.
	if station != null and station.is_next_spin_free() and station.spins_left > 0:
		_spin.call_deferred()


## Tappable/clickable controls, so it works with keyboard, mouse and touch.
func _build_buttons() -> void:
	_close_button = _make_button("X", Rect2(492, 12, 20, 20), MachineDrawing.RED, close)
	_wheel_tab = _make_button("WHEEL", Rect2(206, 36, 104, 16), MachineDrawing.YELLOW, _set_mode.bind(Mode.WHEEL))
	_cards_tab = _make_button("HIGHER/LOWER", Rect2(316, 36, 120, 16), MachineDrawing.YELLOW, _set_mode.bind(Mode.CARDS))

	var title := _make_label("STAKE", Rect2(536, 66, 96, 12), MachineDrawing.YELLOW)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stake_label = _make_label("", Rect2(536, 82, 96, 30), Color.WHITE)
	_stake_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_minus_button = _make_button("-", Rect2(536, 118, 44, 22), MachineDrawing.STEEL_LIGHT, _change_stake.bind(-1))
	_plus_button = _make_button("+", Rect2(588, 118, 44, 22), MachineDrawing.STEEL_LIGHT, _change_stake.bind(1))
	_min_button = _make_button("MIN", Rect2(536, 146, 96, 20), MachineDrawing.STEEL_LIGHT, _set_stake_min)
	_all_in_button = _make_button("ALL IN", Rect2(536, 170, 96, 20), MachineDrawing.ORANGE, _set_stake_all_in)
	_spins_label = _make_label("", Rect2(536, 200, 96, 24), MachineDrawing.HIGHLIGHT)
	_spins_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_action_button = _make_button("SPIN", Rect2(536, 236, 96, 40), MachineDrawing.YELLOW, _on_action_pressed)

	_lower_button = _make_button("LOWER", Rect2(206, 214, 104, 24), MachineDrawing.TEAL, _guess.bind(false))
	_higher_button = _make_button("HIGHER", Rect2(330, 214, 104, 24), MachineDrawing.TEAL, _guess.bind(true))
	_pot_label = _make_label("", Rect2(140, 244, 360, 16), MachineDrawing.YELLOW)
	_pot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stake = station.get_min_stake() if station != null else 0


func _set_mode(new_mode: Mode) -> void:
	if _busy():
		return
	mode = new_mode
	var wheel := mode == Mode.WHEEL
	_wheel.visible = wheel
	_frame.visible = wheel
	_cabinet.show_recess = wheel
	_cards.visible = not wheel
	_higher_button.visible = not wheel
	_lower_button.visible = not wheel
	_pot_label.visible = not wheel
	if not wheel and station != null and not station.cards_active:
		_cards.cards = [] as Array[int]
		_cards.show_next = false
	_set_result("SPIN THE WHEEL" if wheel else "BET, THEN GUESS. CASH OUT ANYTIME.", MachineDrawing.HIGHLIGHT)
	_update_info()


## A spin is animating or a card round is running: no tab switching / closing.
func _busy() -> bool:
	return _spinning or (station != null and station.cards_active)


## Pixel-font label built 3x bigger and scaled down (crisp in this 3x layer).
func _make_label(text: String, rect: Rect2, color: Color) -> Label:
	var k := 3.0
	var label := Label.new()
	label.text = text
	label.position = rect.position
	label.size = rect.size * k
	label.scale = Vector2.ONE / k
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", PixelFont.SOURCE)
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", MachineDrawing.OUTLINE)
	label.add_theme_constant_override("outline_size", 9)
	add_child(label)
	return label


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
	_style_button(button, color)
	button.pressed.connect(action)
	add_child(button)
	return button


func _style_button(button: Button, color: Color) -> void:
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		var box := StyleBoxFlat.new()
		box.bg_color = color.lightened(0.2) if state == "hover" else (color.darkened(0.25) if state == "pressed" else color)
		if state == "disabled":
			box.bg_color = color.darkened(0.5)
		box.border_color = MachineDrawing.OUTLINE
		box.set_border_width_all(6)
		button.add_theme_stylebox_override(state, box)


func _change_stake(delta: int) -> void:
	if station == null or _busy() or station.is_next_spin_free():
		return
	_stake = station.clamp_stake(_stake + delta)
	_update_info()


func _set_stake_min() -> void:
	if station != null and not _busy():
		_stake = station.get_min_stake()
		_update_info()


func _set_stake_all_in() -> void:
	if station != null and not _busy() and not station.is_next_spin_free():
		_stake = station.get_max_stake()
		_update_info()


## The HUD's pause menu can unpause the tree while the machine is open
## (RESUME). Keep the game paused until the machine itself closes.
func _process(_delta: float) -> void:
	_tick_on_slice_change()
	if not get_tree().paused and not is_queued_for_deletion():
		get_tree().paused = true
		_set_touch_paused(true)


func _on_action_pressed() -> void:
	if mode == Mode.WHEEL:
		if not _spinning:
			_spin()
	elif station != null and station.cards_active:
		_cash_out()
	else:
		_deal()


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
## scaled to fit between the HUD bars, centered.
func _fit_to_screen() -> void:
	var screen := get_viewport().get_visible_rect().size
	var top := screen.y * HUD_TOP
	var band := screen.y * (1.0 - HUD_TOP - HUD_BOTTOM)
	var s := minf(screen.x / LAYOUT_SIZE.x, band / LAYOUT_SIZE.y)
	scale = Vector2(s, s)
	offset = Vector2((screen.x - LAYOUT_SIZE.x * s) / 2.0, top + (band - LAYOUT_SIZE.y * s) / 2.0)
	# Dim the whole screen (the HUD draws above it, on a higher layer).
	$Dim.position = -offset / s
	$Dim.size = screen / s


func close() -> void:
	if _busy():
		return
	_set_touch_paused(false)
	_keep_music_playing(false)
	get_tree().paused = false
	closed.emit()
	queue_free()


## _input (not _unhandled_input) so Esc closes the machine before the HUD's
## pause menu sees it.
func _input(event: InputEvent) -> void:
	# The HUD's pause menu is open on top (it focuses its buttons): let it have the keys.
	var focus := get_viewport().gui_get_focus_owner()
	if focus != null and not is_ancestor_of(focus):
		return
	var handled := true
	var round_on := station != null and station.cards_active
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_TAB:
		_set_mode(Mode.CARDS if mode == Mode.WHEEL else Mode.WHEEL)
	elif round_on and (event.is_action_pressed("move_up") or event.is_action_pressed("move_right")):
		_guess(true)
	elif round_on and (event.is_action_pressed("move_down") or event.is_action_pressed("move_left")):
		_guess(false)
	elif event.is_action_pressed("move_left"):
		_change_stake(-1)
	elif event.is_action_pressed("move_right"):
		_change_stake(1)
	elif event.is_action_pressed("move_up"):
		_set_stake_all_in()
	elif event.is_action_pressed("move_down"):
		_set_stake_min()
	elif event.is_action_pressed("interact") or event.is_action_pressed("jump"):
		_on_action_pressed()
	elif event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		close()
	else:
		handled = false
	if handled:
		get_viewport().set_input_as_handled()


# --- Wheel ----------------------------------------------------------------------

func _spin() -> void:
	if station == null:
		return
	_spinning = true
	_wheel.highlight_index = -1
	_frame.eye_color = NEUTRAL
	var outcome := station.try_spin(_stake)
	_update_info()
	if outcome < 0:
		_set_result("ACCESS DENIED", ALERT)
		_spinning = false
		_update_info()
		return

	_set_result("COMPUTING...", MachineDrawing.HIGHLIGHT)
	_frame.spinning = true
	var final_index := _index_of(outcome)
	match outcome:
		GamblingOdds.Outcome.FAKE_JACKPOT:
			var jackpot := _index_of(GamblingOdds.Outcome.JACKPOT)
			await _spin_to(jackpot, SPIN_TIME, SPIN_TURNS, 0.1)
			_frame.spinning = false
			_frame.eye_color = WIN
			_set_result("OVERCLOCK!!! +%d TKN" % (station.get_last_stake() * station.jackpot_multiplier), WIN)
			await _blink(jackpot, 3)
			await _glitch(0.6)
			_frame.eye_color = ALERT
			final_index = _index_of(GamblingOdds.Outcome.NOTHING)
			await _nudge_to(final_index)
		GamblingOdds.Outcome.RESPIN_TROLL:
			await _spin_to(_index_of(GamblingOdds.Outcome.DOUBLE), SPIN_TIME * 0.8, SPIN_TURNS - 1)
			_frame.spinning = false
			await _shudder()
			_set_result("CRITICAL ERROR. REBOOTING...", ALERT)
			await _glitch(0.4)
			_frame.spinning = true
			final_index = _index_of(GamblingOdds.Outcome.NOTHING)
			await _spin_to(final_index, SPIN_TIME * 0.6, 2)
		_:
			await _spin_to(final_index, SPIN_TIME, SPIN_TURNS)

	_frame.spinning = false
	station.apply_outcome(outcome)
	_frame.eye_color = _eye_color_for(outcome)
	var color := (_slices[final_index].color as Color).lightened(0.35)
	if outcome == GamblingOdds.Outcome.GOD_MODE:
		color = WIN
	_set_result(station.describe_outcome(outcome), color)
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
	var colors: Array[Color] = [ALERT, NEUTRAL, Color.WHITE, Color(1, 1, 1, 0.4)]
	var elapsed := 0.0
	while elapsed < duration:
		_wheel.position = base_pos + Vector2(randf_range(-6, 6), randf_range(-3, 3))
		_wheel.modulate = colors.pick_random()
		await get_tree().create_timer(0.04).timeout
		elapsed += 0.04
	_wheel.position = base_pos
	_wheel.modulate = Color.WHITE


func _blink(index: int, times: int) -> void:
	_wheel.highlight_index = index
	for i in times:
		_wheel.highlight_on = true
		await get_tree().create_timer(0.12).timeout
		_wheel.highlight_on = false
		await get_tree().create_timer(0.08).timeout
	_wheel.highlight_on = true


# --- Higher or lower ------------------------------------------------------------

func _deal() -> void:
	if station == null or _spinning:
		return
	if not station.cards_deal(_stake):
		_set_result("ACCESS DENIED", ALERT)
		_update_info()
		return
	_cards.accent = MachineDrawing.YELLOW
	_cards.cards = station.cards.duplicate()
	_cards.show_next = true
	await _flip_in()
	_set_result("HIGHER OR LOWER?", MachineDrawing.HIGHLIGHT)
	_update_info()


func _guess(higher: bool) -> void:
	if station == null or _spinning or not station.cards_active:
		return
	_spinning = true
	_update_info()
	var correct := station.cards_guess(higher)
	_cards.cards = station.cards.duplicate()
	_cards.show_next = station.cards_active
	_cards.accent = MachineDrawing.YELLOW if correct else MachineDrawing.RED
	await _flip_in()
	_spinning = false
	if not correct:
		var tie: bool = station.cards[-1] == station.cards[-2]
		_set_result("TIE. HOUSE WINS. POT LOST." if tie else "WRONG! POT LOST.", ALERT)
	elif not station.cards_active:
		_set_result("MAX STREAK! CASHED OUT +%d TKN" % station.get_cards_pot(), WIN)
	else:
		_set_result("CORRECT! CASH OUT OR KEEP GOING", WIN)
	_update_info()


func _cash_out() -> void:
	if station == null or _spinning:
		return
	var pot := station.cards_cash_out()
	if pot > 0:
		_cards.show_next = false
		_set_result("CASHED OUT +%d TKN" % pot, WIN)
	_update_info()


func _flip_in() -> void:
	_cards.flip = 0.0
	var tween := create_tween()
	tween.tween_property(_cards, "flip", 1.0, 0.25)
	await tween.finished


## Short metallic click each time a slice passes the pointer.
func _tick_on_slice_change() -> void:
	if _wheel == null or not _wheel.visible:
		return
	var slice := floori((-_wheel.rotation - PI / 2.0) / _wheel.get_step() + 0.5)
	if slice != _last_tick_slice:
		_last_tick_slice = slice
		if _spinning and _tick_player != null:
			_tick_player.pitch_scale = randf_range(0.95, 1.08)
			_tick_player.play()


static func _make_tick() -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var count := 660 # 30 ms
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in count:
		var t := float(i) / stream.mix_rate
		var env := pow(1.0 - float(i) / count, 4.0)
		var sample := (sin(TAU * 2200.0 * t) * 0.6 + randf_range(-1.0, 1.0) * 0.4) * env * 0.35
		data.encode_s16(i * 2, int(sample * 32767.0))
	stream.data = data
	return stream


# --- Shared ---------------------------------------------------------------------

func _set_result(text: String, color: Color) -> void:
	_result_label.text = text
	_result_label.add_theme_color_override("font_color", color)


func _update_info() -> void:
	if station == null or _action_button == null:
		return
	var free := station.is_next_spin_free()
	var out := station.spins_left <= 0
	var round_on := station.cards_active
	if not free and not round_on:
		_stake = station.clamp_stake(_stake)
	var broke := not free and GameState.tokens < station.get_min_stake()
	var locked := _busy() or out or free or broke

	# Active tab yellow, the other steel; both dimmed while busy.
	_style_button(_wheel_tab, MachineDrawing.YELLOW if mode == Mode.WHEEL else MachineDrawing.STEEL_LIGHT)
	_style_button(_cards_tab, MachineDrawing.YELLOW if mode == Mode.CARDS else MachineDrawing.STEEL_LIGHT)
	_wheel_tab.disabled = _busy()
	_cards_tab.disabled = _busy()
	_close_button.disabled = _busy()
	_minus_button.disabled = locked or _stake <= station.get_min_stake()
	_plus_button.disabled = locked or _stake >= station.get_max_stake()
	_min_button.disabled = locked or _stake <= station.get_min_stake()
	_all_in_button.disabled = locked or _stake >= station.get_max_stake()

	if mode == Mode.WHEEL:
		_action_button.text = "SPIN"
		_action_button.disabled = _spinning or out
	elif round_on:
		_action_button.text = "CASH OUT"
		_action_button.disabled = _spinning or station.cards_streak <= 0
	else:
		_action_button.text = "DEAL"
		_action_button.disabled = _spinning or out
	_higher_button.disabled = _spinning or not round_on
	_lower_button.disabled = _spinning or not round_on

	var shown_stake := station.get_last_stake() if round_on else _stake
	_stake_label.text = "FREE" if free and not round_on else "%d TKN" % shown_stake
	var all_in := not free and shown_stake >= GameState.tokens and shown_stake > station.get_min_stake()
	_stake_label.add_theme_color_override("font_color",
		MachineDrawing.TEAL if free and not round_on else (MachineDrawing.ORANGE if all_in else Color.WHITE))
	_spins_label.text = "%d SPIN%s LEFT" % [station.spins_left, "" if station.spins_left == 1 else "S"]

	if round_on:
		_pot_label.text = "POT %d TKN   NEXT x%.2f" % [station.get_cards_pot(), station.get_cards_step()]
	else:
		_pot_label.text = "EACH CORRECT GUESS x%.2f" % station.get_cards_step()


func _on_tokens_changed(_tokens: int) -> void:
	_update_info()
