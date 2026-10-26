extends "res://levels/shared/level.gd"
## Playable intro: a pixel-font story crawl scrolls behind the level while the player walks a flat
## floor over the pixelized intro art, past a few tokens, up to JARVIS lying powered down.
## Reaching him plays a tap-through wake-up dialogue; afterwards the door leads to level 1.
## Esc / P skips straight to level 1.

signal advanced

const SpeechBubble := preload("res://characters/jarvis/speech_bubble.gd")
const TILE := 32
const FIRST_LEVEL := "res://levels/level_01/level_01.tscn"
const CRAWL_SPEED := 80.0 # screen pixels per second
const CRAWL_STEP := 4.0 # scroll in whole font pixels (Press Start 2P at 32 px)
const CRAWL_TEXT := """EPISODE I
THE BLUE PLANET

Long ago, on a world of violet stone and golden pools, the last explorers of the Outer Rings set down their battered ship.

Above them hung a giant ringed planet, silent and pale, watching as it had for a thousand years.

Their fuel was low. Their map was wrong. And somewhere beneath the glowing craters, something was waking up...

A / D move   Space jump
Mouse aim + fire   E use doors"""
const TOKENS_LINE := "Wow, some free tokens lying around!"
const PLAYER_LINES: PackedStringArray = [
	"Oh he's out of battery.",
	"Let me see if I can power him up.",
]
## [text, mood] pairs spoken by JARVIS once he is back up.
const JARVIS_LINES := [
	["Oh wow, what happened?", "neutral"],
	["I can't remember anything, no memory, this is weird.", "annoyed"],
	["Those tokens really got me going, thanks!", "happy"],
	["I'll give you a hand while I try to figure what happened.", "happy"],
	["I'll give you a bump mid air if you double jump.", "happy"],
	["If you want to dash (double strafe) I'll also give you a push!", "happy"],
]

## Flat floor painted at runtime: top-left cell and size in tiles.
@export var floor_origin := Vector2i(0, 9)
@export var floor_size := Vector2i(48, 3)
@export var wake_seconds: float = 1.2 # JARVIS powers up and flies over before he talks

var _crawl_y: float = 0.0
var _waiting: bool = false
var _talking: SpeechBubble
var _player_bubble := SpeechBubble.new()

@onready var player: Player = $Player
@onready var jarvis: Jarvis = $Jarvis
@onready var tiles: TileMapLayer = $Tiles
@onready var trigger: Area2D = $JarvisTrigger
@onready var tokens_trigger: Area2D = $TokensTrigger
@onready var crawl_layer: CanvasLayer = $CrawlLayer
@onready var crawl: Label = $CrawlLayer/Root/Crawl
@onready var hint: Label = $HintLayer/Hint
@onready var skip_hint: Label = $HintLayer/SkipHint


func _ready() -> void:
	_paint_floor()
	super()
	lock_camera(Rect2(0, 0, (floor_origin.x + floor_size.x) * TILE, (floor_origin.y + floor_size.y) * TILE))
	camera.reset_smoothing()
	_player_bubble.position = Vector2(0.0, -20.0)
	_player_bubble.z_index = 10
	_player_bubble.mood_colors["neutral"] = GameUI.GOLD
	player.add_child(_player_bubble)
	trigger.body_entered.connect(_on_trigger_body_entered)
	tokens_trigger.body_entered.connect(_on_tokens_trigger_body_entered)
	$TouchLayer.add_child(MobileTouchControls.new())

	var touch := ControlSettings.touch_enabled()
	crawl.text = CRAWL_TEXT
	hint.text = "TAP TO CONTINUE" if touch else "PRESS ANY KEY"
	hint.hide()
	skip_hint.visible = not touch
	var blink := hint.create_tween().set_loops()
	blink.tween_property(hint, "modulate:a", 0.25, 0.5)
	blink.tween_property(hint, "modulate:a", 1.0, 0.5)
	_crawl_y = get_viewport().get_visible_rect().size.y # start just below the screen
	crawl.position.y = _crawl_y


## Same 9-slice picks as build_levels.gd for a plain rectangle of tiles.
func _paint_floor() -> void:
	for y in floor_size.y:
		for x in floor_size.x:
			var cell := floor_origin + Vector2i(x, y)
			var col := 0 if x == 0 else 2 if x == floor_size.x - 1 else 1
			var row := 1 if y == 0 else 3 if y == floor_size.y - 1 else 2
			var atlas := Vector2i(col, row)
			if row == 2 and col == 1:
				atlas = Vector2i(4 + posmod(cell.x, 2), posmod(cell.y, 4))
			tiles.set_cell(cell, 0, atlas)


func _process(delta: float) -> void:
	if not is_instance_valid(crawl_layer):
		return
	_crawl_y -= CRAWL_SPEED * delta
	crawl.position.y = roundf(_crawl_y / CRAWL_STEP) * CRAWL_STEP
	if _crawl_y + crawl.size.y < 0.0:
		crawl_layer.queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		_go_to_first_level()
		return
	# Touch taps arrive as emulated mouse clicks; ignoring ScreenTouch avoids double advances.
	var press := event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton
	if not press or not event.is_pressed() or event.is_echo():
		return
	if _waiting:
		get_viewport().set_input_as_handled()
		if _talking.is_typing():
			_talking.skip_typing()
		else:
			advanced.emit()


## Passing remark; the player keeps control.
func _on_tokens_trigger_body_entered(body: Node2D) -> void:
	if body != player:
		return
	tokens_trigger.set_deferred("monitoring", false)
	_player_bubble.auto_hide = true
	_player_bubble.say(TOKENS_LINE)


func _on_trigger_body_entered(body: Node2D) -> void:
	if body != player:
		return
	trigger.set_deferred("monitoring", false)
	_wake_up_scene()


func _wake_up_scene() -> void:
	player.input_locked = true
	for line in PLAYER_LINES:
		await _say(_player_bubble, line)
	_player_bubble.clear()
	hint.hide()
	GameState.spend_tokens(GameState.tokens) # the collected tokens power JARVIS up
	GameUI.play_sound(self, GameUI.chime(true))
	jarvis.wake()
	await get_tree().create_timer(wake_seconds).timeout
	for line: Array in JARVIS_LINES:
		await _say(jarvis.bubble, line[0], line[1])
	jarvis.bubble.clear()
	jarvis.bubble.auto_hide = true
	hint.hide()
	player.input_locked = false


## Shows a line and waits for a key press or tap (the first press finishes the typing).
func _say(bubble: SpeechBubble, text: String, mood: String = "neutral") -> void:
	_talking = bubble
	bubble.auto_hide = false
	bubble.say(text, mood)
	hint.show()
	_waiting = true
	await advanced
	_waiting = false


func _go_to_first_level() -> void:
	set_process_unhandled_input(false)
	get_tree().change_scene_to_file.call_deferred(FIRST_LEVEL)
