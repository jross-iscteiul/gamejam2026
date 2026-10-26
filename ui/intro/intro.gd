extends Control

const SPEED := 60.0  # pixels per second

@onready var crawl: Label = $Crawl


func _ready() -> void:
	crawl.text = """EPISODE I
THE BLUE PLANET

Long ago, on a world of violet stone and golden pools, the last explorers of the Outer Rings set down their battered ship.

Above them hung a giant ringed planet, silent and pale, watching as it had for a thousand years.

Their fuel was low. Their map was wrong. And somewhere beneath the glowing craters, something was waking up...

A / D move   ·   Space jump (twice in the air)\nShift dash   ·   E use doors and levers

Press any key to begin."""
	if ControlSettings.touch_enabled():
		crawl.text = crawl.text.replace("Press any key to begin.", "Tap the screen to begin.")
	crawl.position.y = get_viewport_rect().size.y  # start just below the screen


func _process(delta: float) -> void:
	crawl.position.y -= SPEED * delta
	if crawl.position.y + crawl.size.y < 0:
		_finish()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_pressed() and not event.is_echo():
		_finish()


# The root Control stops emulated touch-mouse clicks, so they never reach _unhandled_input.
func _gui_input(event: InputEvent) -> void:
	if is_processing() and ControlSettings.touch_enabled() and event.is_pressed() and (event is InputEventMouseButton or event is InputEventScreenTouch):
		_finish()


func _finish() -> void:
	set_process(false)
	set_process_unhandled_input(false)
	get_tree().change_scene_to_file.call_deferred("res://levels/level_01/level_01.tscn")
