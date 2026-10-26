extends Control
## End credits after JARVIS goes down: the same crawl as the opening (ui/intro) over the same
## background, with the final time and a JARVIS roast for every team member. The HUD shows it
## over the arena and decides what comes after (leaderboard for a full run, menu otherwise).

signal finished

const SPEED := 110.0 # pixels per second, quicker than the intro
const TEAM: PackedStringArray = ["andre", "emanuel", "joao", "miguel", "diogo", "yuri"]

@onready var crawl: Label = $Crawl

var _done: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	crawl.text = _build_text()
	crawl.position.y = get_viewport_rect().size.y # start just below the screen
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 1.0)


func _build_text() -> String:
	var lines: PackedStringArray = [
		"EPILOGUE",
		"THE CONTRACT ENDS",
		"",
		"JARVIS is offline. The Foreman is scrap. Every unit on the factory floor has gone dark.",
		"",
		"Above the violet stone, the giant ringed planet watches, silent and pale, and for the first time in a thousand years it looks almost... impressed.",
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
	crawl.position.y -= SPEED * delta
	if crawl.position.y + crawl.size.y < 0:
		skip()


## Ends the crawl. Players can't skip it; this is for the end of the scroll (and tests).
func skip() -> void:
	if _done:
		return
	_done = true
	set_process(false)
	finished.emit()
