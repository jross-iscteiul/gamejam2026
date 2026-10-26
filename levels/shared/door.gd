extends Area2D
## Sci-fi bulkhead exit: panels slide apart when the player is in range and slide shut again
## when they leave (~0.25 s). Press E (interact) in range to load the next level.
## Trap doors (`trap = true`) never open: E (interact) springs a ~2 s trap sequence instead
## (see `_spring_trap`). Tests can read the sign via `$Sign.text` ("EXIT" -> "AHAH").

const SLIDE_SECONDS := 0.25
const PANEL_TRAVEL := 11.0
const RATTLE_SECONDS := 0.7
const FALL_SECONDS := 1.0
const FADE_SECONDS := 0.4
const FRAME := Color("141b29")
const TRIM := Color("2a3952")
const PANEL := Color("23314a")
const PANEL_EDGE := Color("3c5278")
const VOID := Color("05060a")
const MOCK_RED := Color("ff3b3b")
const RUBBLE := Color("30261f")

@export_file("*.tscn") var next_level: String
## A trap door (used for the level 3 "gotcha") never opens; interacting springs the trap instead.
@export var trap := false

var _open := 0.0 # 0 closed .. 1 open
var _t := 0.0
var _phase := "idle" # idle -> rattle -> collapse -> fading -> done
var _phase_t := 0.0
var _base_position: Vector2


func _ready() -> void:
	_base_position = position


func _process(delta: float) -> void:
	_t += delta
	var near := has_overlapping_bodies()
	if _phase == "idle":
		$Hint.visible = near
		$Sign.visible = fmod(_t, 0.9) < 0.6
		_open = move_toward(_open, 1.0 if (near and not trap) else 0.0, delta / SLIDE_SECONDS)
		if Input.is_action_just_pressed("interact") and near:
			if trap:
				_spring_trap()
			else:
				set_process(false)
				GameState.level_completed.emit(GameState.current_level)
				get_tree().change_scene_to_file.call_deferred(next_level)
	elif _phase == "rattle":
		_phase_t += delta
		$Sign.visible = fmod(_t, 0.1) < 0.05 # fast flash while JARVIS mocks the player
		position = _base_position + Vector2(randf_range(-2.0, 2.0), randf_range(-1.0, 1.0))
	else: # collapse / fading / done: settled back in place, animation driven by _phase_t
		_phase_t += delta
		position = _base_position
	queue_redraw()


func _spring_trap() -> void:
	_phase = "rattle"
	_phase_t = 0.0
	$Hint.visible = false
	$Sign.text = "AHAH"
	$Sign.modulate = MOCK_RED
	await get_tree().create_timer(RATTLE_SECONDS).timeout
	_collapse()


func _collapse() -> void:
	_phase = "collapse"
	_phase_t = 0.0
	position = _base_position
	$Sign.visible = false
	GameState.jarvis_say.emit("Did you really think it'd be that easy?", "smug")
	_shake_camera()
	_dig_hole()
	var player := _overlapping_player()
	if is_instance_valid(player):
		player.stunned = true
	await get_tree().create_timer(FALL_SECONDS).timeout
	_phase = "fading"
	await _fade_out()
	_phase = "done"
	set_process(false)
	GameState.level_completed.emit(GameState.current_level)
	GameState.arrived_by_trap = true
	get_tree().change_scene_to_file.call_deferred(next_level)


func _overlapping_player() -> Node:
	for body in get_overlapping_bodies():
		if body.is_in_group("player"):
			return body
	return null


## Same shake as boss_trigger.gd's `_shake`, inlined (one caller each, not worth sharing).
func _shake_camera() -> void:
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return
	var tween := create_tween()
	for i in 6:
		tween.tween_property(camera, "offset", Vector2(randf_range(-4, 4), randf_range(-3, 3)), 0.04)
	tween.tween_property(camera, "offset", Vector2.ZERO, 0.06)


## Erases a 3-wide column (door cell x-1..x+1) from the floor row (door cell y+1) down to well
## past the bottom of any level; erase_cell on a cell with no tile is a harmless no-op.
func _dig_hole() -> void:
	var tiles := get_tree().current_scene.get_node_or_null("Tiles") as TileMapLayer
	if tiles == null:
		return
	var door_cell := tiles.local_to_map(tiles.to_local(global_position))
	for x in range(door_cell.x - 1, door_cell.x + 2):
		for y in range(door_cell.y + 1, door_cell.y + 100):
			tiles.erase_cell(Vector2i(x, y))


func _fade_out() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	var veil := ColorRect.new()
	veil.color = Color(0, 0, 0, 0)
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(veil)
	get_tree().root.add_child(layer)
	var tween := create_tween()
	tween.tween_property(veil, "color:a", 1.0, FADE_SECONDS)
	await tween.finished
	# Free the veil a little after the level swap (not awaited on self: this door and its whole
	# level are about to be freed by change_scene_to_file, this timer and callable are not).
	get_tree().create_timer(0.3).timeout.connect(layer.queue_free)


func _draw() -> void:
	if _phase == "idle" or _phase == "rattle":
		var pts := PackedVector2Array([
			Vector2(-16, -39), Vector2(-11, -44), Vector2(11, -44), Vector2(16, -39),
			Vector2(16, 16), Vector2(-16, 16), Vector2(-16, -39),
		])
		draw_colored_polygon(pts, FRAME)
		draw_polyline(pts, TRIM, 2.0)
		draw_polyline(pts, Color(GameUI.CYAN, 0.6 + 0.4 * sin(_t * 3.0)), 1.0)
		draw_rect(Rect2(-13, -57, 26, 11), FRAME) # EXIT/AHAH sign backing plate
		draw_rect(Rect2(-12, -40, 24, 56), VOID) # doorway void
		var travel := _open * PANEL_TRAVEL
		draw_rect(Rect2(-12 - travel, -40, 12, 56), PANEL)
		draw_rect(Rect2(-12 - travel, -40, 12, 3), PANEL_EDGE)
		draw_rect(Rect2(travel, -40, 12, 56), PANEL)
		draw_rect(Rect2(travel, -40, 12, 3), PANEL_EDGE)
		draw_line(Vector2(-travel, -40), Vector2(-travel, 16), Color(GameUI.CYAN, 0.5), 1.0)
		draw_line(Vector2(travel, -40), Vector2(travel, 16), Color(GameUI.CYAN, 0.5), 1.0)
		if $Hint.visible: # key-cap prompt
			draw_rect(Rect2(-8, -72, 16, 14), FRAME)
			draw_rect(Rect2(-8, -72, 16, 14), Color(GameUI.CYAN, 0.8), false, 1.0)
	else:
		_draw_collapsed()


## Frame halves tip outward and drop away, the hole yawns open behind them, a few rubble
## chunks tumble into the dark. Purely decorative: the real hole is the erased tile cells.
func _draw_collapsed() -> void:
	var fall := minf(_phase_t, 1.2)
	var alpha := clampf(1.0 - fall / 0.6, 0.0, 1.0)
	var drop := fall * 60.0
	draw_set_transform(Vector2(-10, 16 + drop), -fall * 0.6)
	draw_rect(Rect2(-6, -30, 12, 30), Color(FRAME, alpha))
	draw_set_transform(Vector2(10, 16 + drop), fall * 0.6)
	draw_rect(Rect2(-6, -30, 12, 30), Color(FRAME, alpha))
	draw_set_transform(Vector2.ZERO, 0.0)
	for i in 5:
		var seed := float(i) * 1.7
		var y := fposmod(_phase_t * (90.0 + i * 14.0) + seed * 40.0, 220.0) - 8.0
		var x := sin(seed + _phase_t * 2.0) * 10.0
		draw_rect(Rect2(x - 2.0, y, 4.0, 4.0), RUBBLE)
