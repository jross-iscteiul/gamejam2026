extends Node
## JARVIS line database. Stub owned by Package 6 — keep get_line() signature stable.

var _lines := {
	"kill_player": ["Nice shot. Lucky, but nice."],
	"kill_jarvis": ["You're welcome."],
	"kill_doubt": ["Was that you? I think that was me."],
	"death": ["Gravity: 1, You: 0."],
	"gambling": ["The house always wins. I am the house."],
	"low_trust": ["Feed me tokens and maybe I'll care."],
}


func get_line(category: String, level: int = 0) -> String:
	var options: Array = _lines.get(category, ["[placeholder: %s / level %d]" % [category, level]])
	return options.pick_random()
