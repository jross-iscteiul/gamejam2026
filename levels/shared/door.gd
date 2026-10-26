extends Area2D
## Sci-fi bulkhead exit: panels slide apart when the player is in range and slide shut again
## when they leave (~0.25 s). Press E (interact) in range to load the next level.

const SLIDE_SECONDS := 0.25
const PANEL_TRAVEL := 11.0
const FRAME := Color("141b29")
const TRIM := Color("2a3952")
const PANEL := Color("23314a")
const PANEL_EDGE := Color("3c5278")
const VOID := Color("05060a")

@export_file("*.tscn") var next_level: String

var _open := 0.0 # 0 closed .. 1 open
var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	var near := has_overlapping_bodies()
	$Hint.visible = near
	$Sign.visible = fmod(_t, 0.9) < 0.6
	_open = move_toward(_open, 1.0 if near else 0.0, delta / SLIDE_SECONDS)
	queue_redraw()
	if Input.is_action_just_pressed("interact") and near:
		set_process(false)
		GameState.level_completed.emit(GameState.current_level)
		get_tree().change_scene_to_file.call_deferred(next_level)


func _draw() -> void:
	var pts := PackedVector2Array([
		Vector2(-16, -39), Vector2(-11, -44), Vector2(11, -44), Vector2(16, -39),
		Vector2(16, 16), Vector2(-16, 16), Vector2(-16, -39),
	])
	draw_colored_polygon(pts, FRAME)
	draw_polyline(pts, TRIM, 2.0)
	draw_polyline(pts, Color(GameUI.CYAN, 0.6 + 0.4 * sin(_t * 3.0)), 1.0)
	draw_rect(Rect2(-13, -57, 26, 11), FRAME) # EXIT sign backing plate
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
